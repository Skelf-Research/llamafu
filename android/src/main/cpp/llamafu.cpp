#include "llamafu.h"
#include "llama.h"
#include "common.h"
#include <stdexcept>
#include <cstring>
#include <vector>
#include <string>
#include <iostream>

struct Llamafu_s {
    llama_model* model;
    llama_context* ctx;
};

LlamafuError llamafu_init(LlamafuModelParams* params, Llamafu* out_llamafu) {
    try {
        // Initialize llama.cpp
        llama_backend_init();

        // Load model
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = 0; // Keep everything on CPU for mobile
        
        llama_model* model = llama_model_load_from_file(params->model_path, model_params);
        if (!model) {
            std::cerr << "Failed to load model from " << params->model_path << std::endl;
            return LLAMAFU_ERROR_MODEL_LOAD_FAILED;
        }

        // Initialize context
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = params->n_ctx;
        ctx_params.n_threads = params->n_threads;
        ctx_params.n_threads_batch = params->n_threads;
        
        llama_context* ctx = llama_init_from_model(model, ctx_params);
        if (!ctx) {
            std::cerr << "Failed to initialize context" << std::endl;
            llama_model_free(model);
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        // Create Llamafu instance
        Llamafu llamafu = new Llamafu_s{model, ctx};
        *out_llamafu = llamafu;

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_init: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_complete(Llamafu llamafu, LlamafuInferParams* params, char** out_result) {
    try {
        // Tokenize input prompt
        std::string prompt(params->prompt);
        const llama_model* model = llama_get_model(llamafu->ctx);
        const llama_vocab* vocab = llama_model_get_vocab(model);
        std::vector<llama_token> tokens(prompt.size() + 1024); // Reserve extra space
        int n_tokens = llama_tokenize(vocab, prompt.c_str(), prompt.length(), tokens.data(), tokens.size(), true, false);
        
        if (n_tokens < 0) {
            std::cerr << "Failed to tokenize prompt" << std::endl;
            return LLAMAFU_ERROR_INVALID_PARAM;
        }
        
        tokens.resize(n_tokens);

        // Evaluate input prompt
        llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
        int ret = llama_decode(llamafu->ctx, batch);
        if (ret != 0) {
            std::cerr << "llama_decode failed with code " << ret << std::endl;
            return LLAMAFU_ERROR_UNKNOWN;
        }

        // Generate tokens
        std::string result = prompt;
        llama_token new_token_id;
        
        for (int i = 0; i < params->max_tokens; i++) {
            // Sample next token
            auto logits = llama_get_logits_ith(llamafu->ctx, -1);
            int n_vocab = llama_vocab_n_tokens(vocab);
            
            std::vector<llama_token_data> candidates;
            candidates.reserve(n_vocab);
            for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
                candidates.emplace_back(llama_token_data{token_id, logits[token_id], 0.0f});
            }
            
            llama_token_data_array candidates_p = { candidates.data(), candidates.size(), -1, false };
            
            // Temperature sampling
            if (params->temperature > 0.0f) {
                llama_sampler* temp_sampler = llama_sampler_init_temp(params->temperature);
                llama_sampler_apply(temp_sampler, &candidates_p);
                llama_sampler_free(temp_sampler);
            }
            
            // Distribution sampling
            llama_sampler* dist_sampler = llama_sampler_init_dist(1234);
            llama_sampler_apply(dist_sampler, &candidates_p);
            new_token_id = llama_sampler_sample(dist_sampler, llamafu->ctx, -1);
            llama_sampler_free(dist_sampler);
            
            // Check for end of generation
            if (llama_vocab_is_eog(vocab, new_token_id)) {
                break;
            }
            
            // Append to result
            std::vector<char> piece(8, 0);
            int n_chars = llama_token_to_piece(vocab, new_token_id, piece.data(), piece.size(), 0, false);
            if (n_chars < 0) {
                std::cerr << "Failed to convert token to piece" << std::endl;
                return LLAMAFU_ERROR_UNKNOWN;
            }
            
            if (n_chars >= (int)piece.size()) {
                piece.resize(n_chars + 1);
                n_chars = llama_token_to_piece(vocab, new_token_id, piece.data(), piece.size(), 0, false);
            }
            
            result += std::string(piece.data(), n_chars);
            
            // Append new token to context
            llama_batch new_batch = llama_batch_get_one(&new_token_id, 1);
            ret = llama_decode(llamafu->ctx, new_batch);
            if (ret != 0) {
                std::cerr << "llama_decode failed with code " << ret << std::endl;
                return LLAMAFU_ERROR_UNKNOWN;
            }
        }

        // Allocate and copy result
        *out_result = new char[result.length() + 1];
        std::strcpy(*out_result, result.c_str());

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_complete: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

// Simple callback wrapper for C++
struct StreamCallbackData {
    LlamafuStreamCallback callback;
    void* user_data;
};

static void stream_callback_wrapper(const char* token, void* user_data) {
    StreamCallbackData* data = static_cast<StreamCallbackData*>(user_data);
    data->callback(token, data->user_data);
}

LlamafuError llamafu_complete_stream(Llamafu llamafu, LlamafuInferParams* params, LlamafuStreamCallback callback, void* user_data) {
    try {
        // Tokenize input prompt
        std::string prompt(params->prompt);
        const llama_model* model = llama_get_model(llamafu->ctx);
        const llama_vocab* vocab = llama_model_get_vocab(model);
        std::vector<llama_token> tokens(prompt.size() + 1024); // Reserve extra space
        int n_tokens = llama_tokenize(vocab, prompt.c_str(), prompt.length(), tokens.data(), tokens.size(), true, false);
        
        if (n_tokens < 0) {
            std::cerr << "Failed to tokenize prompt" << std::endl;
            return LLAMAFU_ERROR_INVALID_PARAM;
        }
        
        tokens.resize(n_tokens);

        // Evaluate input prompt
        llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
        int ret = llama_decode(llamafu->ctx, batch);
        if (ret != 0) {
            std::cerr << "llama_decode failed with code " << ret << std::endl;
            return LLAMAFU_ERROR_UNKNOWN;
        }

        // Generate tokens
        llama_token new_token_id;
        StreamCallbackData cb_data{callback, user_data};
        
        for (int i = 0; i < params->max_tokens; i++) {
            // Sample next token
            auto logits = llama_get_logits_ith(llamafu->ctx, -1);
            int n_vocab = llama_vocab_n_tokens(vocab);
            
            std::vector<llama_token_data> candidates;
            candidates.reserve(n_vocab);
            for (llama_token token_id = 0; token_id < n_vocab; token_id++) {
                candidates.emplace_back(llama_token_data{token_id, logits[token_id], 0.0f});
            }
            
            llama_token_data_array candidates_p = { candidates.data(), candidates.size(), -1, false };
            
            // Temperature sampling
            if (params->temperature > 0.0f) {
                llama_sampler* temp_sampler = llama_sampler_init_temp(params->temperature);
                llama_sampler_apply(temp_sampler, &candidates_p);
                llama_sampler_free(temp_sampler);
            }
            
            // Distribution sampling
            llama_sampler* dist_sampler = llama_sampler_init_dist(1234);
            llama_sampler_apply(dist_sampler, &candidates_p);
            new_token_id = llama_sampler_sample(dist_sampler, llamafu->ctx, -1);
            llama_sampler_free(dist_sampler);
            
            // Check for end of generation
            if (llama_vocab_is_eog(vocab, new_token_id)) {
                break;
            }
            
            // Convert token to string and call callback
            std::vector<char> piece(8, 0);
            int n_chars = llama_token_to_piece(vocab, new_token_id, piece.data(), piece.size(), 0, false);
            if (n_chars < 0) {
                std::cerr << "Failed to convert token to piece" << std::endl;
                return LLAMAFU_ERROR_UNKNOWN;
            }
            
            if (n_chars >= (int)piece.size()) {
                piece.resize(n_chars + 1);
                n_chars = llama_token_to_piece(vocab, new_token_id, piece.data(), piece.size(), 0, false);
            }
            
            std::string token_str(piece.data(), n_chars);
            callback(token_str.c_str(), user_data);
            
            // Append new token to context
            llama_batch new_batch = llama_batch_get_one(&new_token_id, 1);
            ret = llama_decode(llamafu->ctx, new_batch);
            if (ret != 0) {
                std::cerr << "llama_decode failed with code " << ret << std::endl;
                return LLAMAFU_ERROR_UNKNOWN;
            }
        }

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_complete_stream: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

void llamafu_free(Llamafu llamafu) {
    if (llamafu) {
        if (llamafu->ctx) {
            llama_free(llamafu->ctx);
        }
        if (llamafu->model) {
            llama_model_free(llamafu->model);
        }
        delete llamafu;
    }
}