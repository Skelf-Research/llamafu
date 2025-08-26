#include "llamafu.h"
#include "llama.h"
#include "common.h"
#include "mtmd.h"
#include <stdexcept>
#include <cstring>
#include <vector>
#include <string>
#include <iostream>
#include <fstream>
#include <map>

// Opaque struct for LoRA adapter
struct LlamafuLoraAdapter_s {
    llama_adapter_lora* adapter;
};

// Opaque struct for grammar sampler
struct LlamafuGrammarSampler_s {
    llama_sampler* sampler;
};

struct Llamafu_s {
    llama_model* model;
    llama_context* ctx;
    mtmd_context* mtmd_ctx;  // Multi-modal context
    bool is_multimodal;
    std::map<LlamafuLoraAdapter, llama_adapter_lora*> lora_adapters; // Track LoRA adapters
};

LlamafuError llamafu_init(LlamafuModelParams* params, Llamafu* out_llamafu) {
    try {
        // Initialize llama.cpp
        llama_backend_init();

        // Load model
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = params->use_gpu ? 999 : 0; // Use GPU if requested
        
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

        // Initialize multi-modal context if mmproj_path is provided
        mtmd_context* mtmd_ctx = nullptr;
        bool is_multimodal = false;
        
        if (params->mmproj_path && strlen(params->mmproj_path) > 0) {
            mtmd_context_params mtmd_params = mtmd_context_params_default();
            mtmd_params.use_gpu = params->use_gpu;
            mtmd_params.n_threads = params->n_threads;
            
            mtmd_ctx = mtmd_init_from_file(params->mmproj_path, model, mtmd_params);
            if (!mtmd_ctx) {
                std::cerr << "Failed to initialize multi-modal context from " << params->mmproj_path << std::endl;
                llama_free(ctx);
                llama_model_free(model);
                return LLAMAFU_ERROR_MODEL_LOAD_FAILED;
            }
            is_multimodal = true;
        }

        // Create Llamafu instance
        Llamafu llamafu = new Llamafu_s{model, ctx, mtmd_ctx, is_multimodal, std::map<LlamafuLoraAdapter, llama_adapter_lora*>{}};
        *out_llamafu = llamafu;

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_init: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

// Helper function to load image/audio data from file
std::vector<unsigned char> load_media_file(const char* filepath) {
    std::ifstream file(filepath, std::ios::binary | std::ios::ate);
    if (!file) {
        throw std::runtime_error("Failed to open file");
    }
    
    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    std::vector<unsigned char> buffer(size);
    if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
        throw std::runtime_error("Failed to read file");
    }
    
    return buffer;
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

LlamafuError llamafu_complete_with_grammar(Llamafu llamafu, LlamafuInferParams* params, LlamafuGrammarParams* grammar_params, char** out_result) {
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

        // Initialize grammar sampler if provided
        llama_sampler* grammar_sampler = nullptr;
        if (grammar_params && grammar_params->grammar_str && strlen(grammar_params->grammar_str) > 0) {
            grammar_sampler = llama_sampler_init_grammar(vocab, grammar_params->grammar_str, grammar_params->grammar_root);
            if (!grammar_sampler) {
                std::cerr << "Failed to initialize grammar sampler" << std::endl;
                return LLAMAFU_ERROR_GRAMMAR_INIT_FAILED;
            }
        }

        // Evaluate input prompt
        llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
        int ret = llama_decode(llamafu->ctx, batch);
        if (ret != 0) {
            std::cerr << "llama_decode failed with code " << ret << std::endl;
            if (grammar_sampler) llama_sampler_free(grammar_sampler);
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
            
            // Apply grammar constraints if available
            if (grammar_sampler) {
                llama_sampler_apply(grammar_sampler, &candidates_p);
            }
            
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
            
            // Accept the token in the grammar sampler
            if (grammar_sampler) {
                llama_sampler_accept(grammar_sampler, new_token_id);
            }
            
            // Check for end of generation
            if (llama_vocab_is_eog(vocab, new_token_id)) {
                break;
            }
            
            // Append to result
            std::vector<char> piece(8, 0);
            int n_chars = llama_token_to_piece(vocab, new_token_id, piece.data(), piece.size(), 0, false);
            if (n_chars < 0) {
                std::cerr << "Failed to convert token to piece" << std::endl;
                if (grammar_sampler) llama_sampler_free(grammar_sampler);
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
                if (grammar_sampler) llama_sampler_free(grammar_sampler);
                return LLAMAFU_ERROR_UNKNOWN;
            }
        }

        // Clean up grammar sampler
        if (grammar_sampler) {
            llama_sampler_free(grammar_sampler);
        }

        // Allocate and copy result
        *out_result = new char[result.length() + 1];
        std::strcpy(*out_result, result.c_str());

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_complete_with_grammar: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_multimodal_complete(Llamafu llamafu, LlamafuMultimodalInferParams* params, char** out_result) {
    try {
        // Check if multi-modal is supported
        if (!llamafu->is_multimodal || !llamafu->mtmd_ctx) {
            std::cerr << "Multi-modal processing not initialized" << std::endl;
            return LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED;
        }

        // Check if the model supports the media types
        bool has_image = false;
        bool has_audio = false;
        
        for (size_t i = 0; i < params->n_media_inputs; i++) {
            if (params->media_inputs[i].type == LLAMAFU_MEDIA_TYPE_IMAGE) {
                has_image = true;
            } else if (params->media_inputs[i].type == LLAMAFU_MEDIA_TYPE_AUDIO) {
                has_audio = true;
            }
        }
        
        if (has_image && !mtmd_support_vision(llamafu->mtmd_ctx)) {
            std::cerr << "Model does not support vision input" << std::endl;
            return LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED;
        }
        
        if (has_audio && !mtmd_support_audio(llamafu->mtmd_ctx)) {
            std::cerr << "Model does not support audio input" << std::endl;
            return LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED;
        }

        // Create bitmaps for media inputs
        std::vector<mtmd_bitmap*> bitmaps;
        std::vector<std::vector<unsigned char>> media_data;
        
        for (size_t i = 0; i < params->n_media_inputs; i++) {
            try {
                // Load media data from file
                auto data = load_media_file(params->media_inputs[i].data);
                media_data.push_back(std::move(data));
                
                mtmd_bitmap* bitmap = nullptr;
                if (params->media_inputs[i].type == LLAMAFU_MEDIA_TYPE_IMAGE) {
                    // For simplicity, we're assuming RGB data
                    // In a real implementation, you'd need to decode the image format
                    // and convert to RGB
                    bitmap = mtmd_bitmap_init(224, 224, media_data.back().data()); // Placeholder size
                } else if (params->media_inputs[i].type == LLAMAFU_MEDIA_TYPE_AUDIO) {
                    // For audio, we assume float PCM data
                    bitmap = mtmd_bitmap_init_from_audio(media_data.back().size() / sizeof(float), 
                                                        reinterpret_cast<const float*>(media_data.back().data()));
                }
                
                if (bitmap) {
                    bitmaps.push_back(bitmap);
                }
            } catch (const std::exception& e) {
                std::cerr << "Failed to process media input " << i << ": " << e.what() << std::endl;
                // Clean up any previously created bitmaps
                for (auto* bmp : bitmaps) {
                    mtmd_bitmap_free(bmp);
                }
                return LLAMAFU_ERROR_INVALID_PARAM;
            }
        }

        // Tokenize the prompt with media inputs
        mtmd_input_chunks* chunks = mtmd_input_chunks_init();
        mtmd_input_text text_input = {params->prompt, true, false};
        
        std::vector<const mtmd_bitmap*> bitmaps_c_ptr;
        for (auto* bitmap : bitmaps) {
            bitmaps_c_ptr.push_back(bitmap);
        }
        
        int32_t tokenize_result = mtmd_tokenize(llamafu->mtmd_ctx, chunks, &text_input, 
                                               bitmaps_c_ptr.data(), bitmaps_c_ptr.size());
        
        if (tokenize_result != 0) {
            std::cerr << "Failed to tokenize multi-modal input: " << tokenize_result << std::endl;
            mtmd_input_chunks_free(chunks);
            for (auto* bmp : bitmaps) {
                mtmd_bitmap_free(bmp);
            }
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Process each chunk
        size_t n_chunks = mtmd_input_chunks_size(chunks);
        std::vector<llama_token> all_tokens;
        
        for (size_t i = 0; i < n_chunks; i++) {
            const mtmd_input_chunk* chunk = mtmd_input_chunks_get(chunks, i);
            
            if (mtmd_input_chunk_get_type(chunk) == MTMD_INPUT_CHUNK_TYPE_TEXT) {
                // Text chunk
                size_t n_tokens;
                const llama_token* tokens = mtmd_input_chunk_get_tokens_text(chunk, &n_tokens);
                all_tokens.insert(all_tokens.end(), tokens, tokens + n_tokens);
            } else {
                // Media chunk - encode it
                int32_t encode_result = mtmd_encode_chunk(llamafu->mtmd_ctx, chunk);
                if (encode_result != 0) {
                    std::cerr << "Failed to encode media chunk " << i << std::endl;
                    mtmd_input_chunks_free(chunks);
                    for (auto* bmp : bitmaps) {
                        mtmd_bitmap_free(bmp);
                    }
                    return LLAMAFU_ERROR_UNKNOWN;
                }
                
                // For media chunks, we need to handle them differently
                // This is a simplified approach - in reality, you'd need to integrate
                // the media embeddings with the text tokens
                size_t n_tokens = mtmd_input_chunk_get_n_tokens(chunk);
                // Add placeholder tokens for the media input
                for (size_t j = 0; j < n_tokens; j++) {
                    all_tokens.push_back(0); // Placeholder
                }
            }
        }

        // Clean up
        mtmd_input_chunks_free(chunks);
        for (auto* bmp : bitmaps) {
            mtmd_bitmap_free(bmp);
        }

        // Evaluate input tokens (simplified - in reality, you'd need to handle
        // the integration of media embeddings with the text model)
        if (!all_tokens.empty()) {
            llama_batch batch = llama_batch_get_one(all_tokens.data(), all_tokens.size());
            int ret = llama_decode(llamafu->ctx, batch);
            if (ret != 0) {
                std::cerr << "llama_decode failed with code " << ret << std::endl;
                return LLAMAFU_ERROR_UNKNOWN;
            }
        }

        // Generate tokens (simplified response - in reality, you'd continue
        // with the full generation process)
        std::string result = params->prompt;
        result += " [Multi-modal processing completed]";

        // Allocate and copy result
        *out_result = new char[result.length() + 1];
        std::strcpy(*out_result, result.c_str());

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_multimodal_complete: " << e.what() << std::endl;
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

LlamafuError llamafu_complete_with_grammar_stream(Llamafu llamafu, LlamafuInferParams* params, LlamafuGrammarParams* grammar_params, LlamafuStreamCallback callback, void* user_data) {
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

        // Initialize grammar sampler if provided
        llama_sampler* grammar_sampler = nullptr;
        if (grammar_params && grammar_params->grammar_str && strlen(grammar_params->grammar_str) > 0) {
            grammar_sampler = llama_sampler_init_grammar(vocab, grammar_params->grammar_str, grammar_params->grammar_root);
            if (!grammar_sampler) {
                std::cerr << "Failed to initialize grammar sampler" << std::endl;
                return LLAMAFU_ERROR_GRAMMAR_INIT_FAILED;
            }
        }

        // Evaluate input prompt
        llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
        int ret = llama_decode(llamafu->ctx, batch);
        if (ret != 0) {
            std::cerr << "llama_decode failed with code " << ret << std::endl;
            if (grammar_sampler) llama_sampler_free(grammar_sampler);
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
            
            // Apply grammar constraints if available
            if (grammar_sampler) {
                llama_sampler_apply(grammar_sampler, &candidates_p);
            }
            
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
            
            // Accept the token in the grammar sampler
            if (grammar_sampler) {
                llama_sampler_accept(grammar_sampler, new_token_id);
            }
            
            // Check for end of generation
            if (llama_vocab_is_eog(vocab, new_token_id)) {
                break;
            }
            
            // Convert token to string and call callback
            std::vector<char> piece(8, 0);
            int n_chars = llama_token_to_piece(vocab, new_token_id, piece.data(), piece.size(), 0, false);
            if (n_chars < 0) {
                std::cerr << "Failed to convert token to piece" << std::endl;
                if (grammar_sampler) llama_sampler_free(grammar_sampler);
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
                if (grammar_sampler) llama_sampler_free(grammar_sampler);
                return LLAMAFU_ERROR_UNKNOWN;
            }
        }

        // Clean up grammar sampler
        if (grammar_sampler) {
            llama_sampler_free(grammar_sampler);
        }

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_complete_with_grammar_stream: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_multimodal_complete_stream(Llamafu llamafu, LlamafuMultimodalInferParams* params, LlamafuStreamCallback callback, void* user_data) {
    // For now, we'll implement a simplified version that just calls the non-streaming version
    // and then streams a completion message
    
    char* result = nullptr;
    LlamafuError err = llamafu_multimodal_complete(llamafu, params, &result);
    
    if (err == LLAMAFU_SUCCESS && result) {
        // Stream the result
        callback(result, user_data);
        delete[] result;
    }
    
    return err;
}

// LoRA adapter functions
LlamafuError llamafu_lora_adapter_init(Llamafu llamafu, const char* lora_path, LlamafuLoraAdapter* out_adapter) {
    try {
        if (!llamafu || !lora_path || !out_adapter) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Initialize LoRA adapter
        llama_adapter_lora* adapter = llama_adapter_lora_init(llamafu->model, lora_path);
        if (!adapter) {
            std::cerr << "Failed to initialize LoRA adapter from " << lora_path << std::endl;
            return LLAMAFU_ERROR_LORA_LOAD_FAILED;
        }

        // Create LlamafuLoraAdapter wrapper
        LlamafuLoraAdapter_s* llamafu_adapter = new LlamafuLoraAdapter_s{adapter};
        
        // Store in our map for tracking
        llamafu->lora_adapters[llamafu_adapter] = adapter;
        
        *out_adapter = llamafu_adapter;
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_lora_adapter_init: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_lora_adapter_apply(Llamafu llamafu, LlamafuLoraAdapter adapter, float scale) {
    try {
        if (!llamafu || !adapter) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Check if adapter is in our map
        auto it = llamafu->lora_adapters.find(adapter);
        if (it == llamafu->lora_adapters.end()) {
            return LLAMAFU_ERROR_LORA_NOT_FOUND;
        }

        // Apply LoRA adapter
        int32_t result = llama_set_adapter_lora(llamafu->ctx, it->second, scale);
        if (result != 0) {
            std::cerr << "Failed to apply LoRA adapter, error code: " << result << std::endl;
            return LLAMAFU_ERROR_UNKNOWN;
        }

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_lora_adapter_apply: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_lora_adapter_remove(Llamafu llamafu, LlamafuLoraAdapter adapter) {
    try {
        if (!llamafu || !adapter) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Check if adapter is in our map
        auto it = llamafu->lora_adapters.find(adapter);
        if (it == llamafu->lora_adapters.end()) {
            return LLAMAFU_ERROR_LORA_NOT_FOUND;
        }

        // Remove LoRA adapter
        int32_t result = llama_rm_adapter_lora(llamafu->ctx, it->second);
        if (result != 0) {
            std::cerr << "Failed to remove LoRA adapter, error code: " << result << std::endl;
            return LLAMAFU_ERROR_UNKNOWN;
        }

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_lora_adapter_remove: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_lora_adapter_clear_all(Llamafu llamafu) {
    try {
        if (!llamafu) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Clear all LoRA adapters
        llama_clear_adapter_lora(llamafu->ctx);
        
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_lora_adapter_clear_all: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

void llamafu_lora_adapter_free(LlamafuLoraAdapter adapter) {
    if (adapter) {
        // Free the underlying llama adapter
        llama_adapter_lora_free(adapter->adapter);
        
        // Delete our wrapper
        delete adapter;
    }
}

// Grammar sampler functions
LlamafuError llamafu_grammar_sampler_init(Llamafu llamafu, const char* grammar_str, const char* grammar_root, LlamafuGrammarSampler* out_sampler) {
    try {
        if (!llamafu || !grammar_str || !grammar_root || !out_sampler) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        const llama_model* model = llama_get_model(llamafu->ctx);
        const llama_vocab* vocab = llama_model_get_vocab(model);

        // Initialize grammar sampler
        llama_sampler* sampler = llama_sampler_init_grammar(vocab, grammar_str, grammar_root);
        if (!sampler) {
            std::cerr << "Failed to initialize grammar sampler" << std::endl;
            return LLAMAFU_ERROR_GRAMMAR_INIT_FAILED;
        }

        // Create LlamafuGrammarSampler wrapper
        LlamafuGrammarSampler_s* grammar_sampler = new LlamafuGrammarSampler_s{sampler};
        
        *out_sampler = grammar_sampler;
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        std::cerr << "Exception in llamafu_grammar_sampler_init: " << e.what() << std::endl;
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

void llamafu_grammar_sampler_free(LlamafuGrammarSampler sampler) {
    if (sampler) {
        // Free the underlying llama sampler
        llama_sampler_free(sampler->sampler);
        
        // Delete our wrapper
        delete sampler;
    }
}

void llamafu_free(Llamafu llamafu) {
    if (llamafu) {
        // Free all LoRA adapters
        for (auto& pair : llamafu->lora_adapters) {
            llama_adapter_lora_free(pair.second);
        }
        llamafu->lora_adapters.clear();
        
        if (llamafu->ctx) {
            llama_free(llamafu->ctx);
        }
        if (llamafu->model) {
            llama_model_free(llamafu->model);
        }
        if (llamafu->mtmd_ctx) {
            mtmd_free(llamafu->mtmd_ctx);
        }
        delete llamafu;
    }
}