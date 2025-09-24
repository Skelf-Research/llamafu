#include "llamafu.h"
#include "llama.h"
#include <stdexcept>
#include <cstring>
#include <vector>
#include <string>
#include <memory>
#include <map>
#include <cmath>

struct Llamafu_s {
    llama_model* model;
    llama_context* ctx;
    bool is_multimodal;
    std::map<LlamafuLoraAdapter, llama_adapter_lora*> lora_adapters;
};

static bool validate_string_param(const char* param, const char* param_name) {
    if (!param || strlen(param) == 0) {
        return false;
    }
    if (strlen(param) > 8192) {  // Reasonable max path length
        return false;
    }
    return true;
}

static bool validate_numeric_param(int32_t value, int32_t min_val, int32_t max_val) {
    return value >= min_val && value <= max_val;
}

static bool validate_float_param(float value, float min_val, float max_val) {
    return value >= min_val && value <= max_val && !std::isnan(value) && !std::isinf(value);
}

extern "C" {

int32_t llamafu_init(LlamafuModelParams* params, Llamafu* out_llamafu) {
    if (!params || !out_llamafu) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_string_param(params->model_path, "model_path")) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_numeric_param(params->n_threads, 1, 128) ||
        !validate_numeric_param(params->n_ctx, 1, 1048576)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Initialize llama backend
        llama_backend_init();

        // Load model
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = params->use_gpu ? 999 : 0;  // Use all layers if GPU enabled

        llama_model* model = llama_load_model_from_file(params->model_path, model_params);
        if (!model) {
            llama_backend_free();
            return LLAMAFU_ERROR_MODEL_LOAD_FAILED;
        }

        // Create context
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = params->n_ctx;
        ctx_params.n_threads = params->n_threads;
        ctx_params.n_threads_batch = params->n_threads;

        llama_context* ctx = llama_new_context_with_model(model, ctx_params);
        if (!ctx) {
            llama_free_model(model);
            llama_backend_free();
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        // Check if model supports multimodal (simplified check)
        bool is_multimodal = params->mmproj_path && strlen(params->mmproj_path) > 0;

        Llamafu llamafu = new Llamafu_s{model, ctx, is_multimodal, std::map<LlamafuLoraAdapter, llama_adapter_lora*>{}};
        *out_llamafu = llamafu;

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_complete(Llamafu llamafu, LlamafuInferParams* params, char** out_result) {
    if (!llamafu || !params || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_string_param(params->prompt, "prompt")) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_numeric_param(params->max_tokens, 1, 32768) ||
        !validate_float_param(params->temperature, 0.0f, 2.0f) ||
        !validate_float_param(params->top_p, 0.0f, 1.0f) ||
        !validate_numeric_param(params->top_k, 1, 200) ||
        !validate_float_param(params->repeat_penalty, 0.1f, 2.0f)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Tokenize prompt
        std::vector<llama_token> tokens = llama_tokenize(llamafu->ctx, params->prompt, true, true);

        if (tokens.empty()) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Clear the KV cache
        llama_kv_cache_clear(llamafu->ctx);

        // Evaluate the prompt tokens
        if (llama_decode(llamafu->ctx, llama_batch_get_one(tokens.data(), tokens.size())) != 0) {
            return LLAMAFU_ERROR_UNKNOWN;
        }

        // Simple placeholder result - in a real implementation this would generate tokens
        std::string result = "Hello from Llamafu! This is a placeholder response for: ";
        result += params->prompt;

        // Allocate result string
        *out_result = static_cast<char*>(malloc(result.length() + 1));
        if (!*out_result) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        strcpy(*out_result, result.c_str());
        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_complete_with_grammar(Llamafu llamafu, LlamafuInferParams* params,
                                     LlamafuGrammarParams* grammar_params, char** out_result) {
    if (!llamafu || !params || !grammar_params || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    // For now, fall back to regular completion (grammar support can be added later)
    return llamafu_complete(llamafu, params, out_result);
}

int32_t llamafu_multimodal_complete(Llamafu llamafu, LlamafuMultimodalInferParams* params, char** out_result) {
    if (!llamafu || !params || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!llamafu->is_multimodal) {
        return LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED;
    }

    // For now, fall back to text-only completion
    LlamafuInferParams text_params = {};
    text_params.prompt = params->prompt;
    text_params.max_tokens = params->max_tokens;
    text_params.temperature = params->temperature;
    text_params.top_p = 0.9f;
    text_params.top_k = 40;
    text_params.repeat_penalty = 1.1f;
    text_params.seed = 42;

    return llamafu_complete(llamafu, &text_params, out_result);
}

int32_t llamafu_load_lora_adapter_from_file(Llamafu llamafu, const char* lora_path,
                                           float scale, LlamafuLoraAdapter* out_adapter) {
    if (!llamafu || !validate_string_param(lora_path, "lora_path") || !out_adapter) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_float_param(scale, 0.0f, 2.0f)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        llama_adapter_lora* adapter = llama_adapter_lora_init(llamafu->model, lora_path);
        if (!adapter) {
            return LLAMAFU_ERROR_LORA_LOAD_FAILED;
        }

        LlamafuLoraAdapter handle = reinterpret_cast<LlamafuLoraAdapter>(adapter);
        llamafu->lora_adapters[handle] = adapter;
        *out_adapter = handle;

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_LORA_LOAD_FAILED;
    }
}

int32_t llamafu_set_lora_adapter(Llamafu llamafu, LlamafuLoraAdapter adapter, float scale) {
    if (!llamafu || !adapter) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_float_param(scale, 0.0f, 2.0f)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    auto it = llamafu->lora_adapters.find(adapter);
    if (it == llamafu->lora_adapters.end()) {
        return LLAMAFU_ERROR_LORA_NOT_FOUND;
    }

    try {
        if (llama_set_adapter_lora(llamafu->ctx, it->second, scale) != 0) {
            return LLAMAFU_ERROR_UNKNOWN;
        }
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_unload_lora_adapter(Llamafu llamafu, LlamafuLoraAdapter adapter) {
    if (!llamafu || !adapter) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    auto it = llamafu->lora_adapters.find(adapter);
    if (it == llamafu->lora_adapters.end()) {
        return LLAMAFU_ERROR_LORA_NOT_FOUND;
    }

    try {
        llama_adapter_lora_free(it->second);
        llamafu->lora_adapters.erase(it);
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_tokenize(Llamafu llamafu, const char* text, LlamafuToken** out_tokens, int32_t* out_n_tokens) {
    if (!llamafu || !validate_string_param(text, "text") || !out_tokens || !out_n_tokens) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        std::vector<llama_token> tokens = llama_tokenize(llamafu->ctx, text, true, true);

        *out_n_tokens = static_cast<int32_t>(tokens.size());
        *out_tokens = static_cast<LlamafuToken*>(malloc(tokens.size() * sizeof(LlamafuToken)));

        if (!*out_tokens) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        for (size_t i = 0; i < tokens.size(); ++i) {
            (*out_tokens)[i] = tokens[i];
        }

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_detokenize(Llamafu llamafu, const LlamafuToken* tokens, int32_t n_tokens, char** out_text) {
    if (!llamafu || !tokens || n_tokens <= 0 || !out_text) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_numeric_param(n_tokens, 1, 32768)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        std::string result;

        for (int32_t i = 0; i < n_tokens; ++i) {
            char token_str[256];
            int32_t n_chars = llama_token_to_piece(llamafu->model, tokens[i], token_str, sizeof(token_str), 0, true);
            if (n_chars > 0) {
                result.append(token_str, n_chars);
            }
        }

        *out_text = static_cast<char*>(malloc(result.length() + 1));
        if (!*out_text) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        strcpy(*out_text, result.c_str());
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_get_model_info(Llamafu llamafu, LlamafuModelInfo* out_info) {
    if (!llamafu || !out_info) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        out_info->vocab_size = llama_n_vocab(llamafu->model);
        out_info->context_size = llama_n_ctx(llamafu->ctx);
        out_info->embedding_size = llama_n_embd(llamafu->model);
        out_info->is_multimodal = llamafu->is_multimodal;

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_get_embeddings(Llamafu llamafu, const char* text, float** out_embeddings, int32_t* out_n_embd) {
    if (!llamafu || !validate_string_param(text, "text") || !out_embeddings || !out_n_embd) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Tokenize input
        std::vector<llama_token> tokens = llama_tokenize(llamafu->ctx, text, true, true);

        if (tokens.empty()) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Clear the KV cache
        llama_kv_cache_clear(llamafu->ctx);

        // Evaluate tokens
        if (llama_decode(llamafu->ctx, llama_batch_get_one(tokens.data(), tokens.size())) != 0) {
            return LLAMAFU_ERROR_UNKNOWN;
        }

        // Get embeddings
        int32_t n_embd = llama_n_embd(llamafu->model);
        const float* embeddings = llama_get_embeddings(llamafu->ctx);

        if (!embeddings) {
            return LLAMAFU_ERROR_UNKNOWN;
        }

        *out_n_embd = n_embd;
        *out_embeddings = static_cast<float*>(malloc(n_embd * sizeof(float)));

        if (!*out_embeddings) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        memcpy(*out_embeddings, embeddings, n_embd * sizeof(float));
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuGrammarSampler llamafu_grammar_sampler_init(Llamafu llamafu, const char* grammar_str, const char* grammar_root) {
    if (!llamafu || !validate_string_param(grammar_str, "grammar_str") || !validate_string_param(grammar_root, "grammar_root")) {
        return nullptr;
    }

    // Grammar sampling would need to be implemented with current llama.cpp API
    // Return null for now as placeholder
    return nullptr;
}

void llamafu_grammar_sampler_free(LlamafuGrammarSampler sampler) {
    if (sampler) {
        // Free grammar sampler resources
    }
}

void llamafu_free_string(char* str) {
    if (str) {
        free(str);
    }
}

void llamafu_free_tokens(LlamafuToken* tokens) {
    if (tokens) {
        free(tokens);
    }
}

void llamafu_free_embeddings(float* embeddings) {
    if (embeddings) {
        free(embeddings);
    }
}

void llamafu_free(Llamafu llamafu) {
    if (llamafu) {
        // Free all loaded LoRA adapters
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

        delete llamafu;
        llama_backend_free();
    }
}

} // extern "C"