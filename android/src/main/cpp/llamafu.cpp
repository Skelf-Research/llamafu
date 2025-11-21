#include "llamafu.h"
#include "llama.h"
#include <stdexcept>
#include <cstring>
#include <vector>
#include <string>
#include <memory>
#include <map>
#include <cmath>
#include <thread>
#include <chrono>
#include <fstream>
#include <algorithm>
#include <cctype>
#include <filesystem>

// Include CLIP for multimodal support
#ifdef __cplusplus
extern "C" {
#endif
#include "../../llama.cpp/tools/mtmd/clip.h"
#ifdef __cplusplus
}
#endif

// Base64 encoding/decoding utilities
#include <array>
#include <sstream>

// Type aliases for types not in header
typedef llama_memory_t LlamafuMemory;
typedef llama_seq_id LlamafuSeqId;
typedef llama_pos LlamafuPos;

struct LlamafuSampler_s {
    llama_sampler* sampler;
    LlamafuSamplerType type;
};

struct Llamafu_s {
    llama_model* model;
    llama_context* ctx;
    bool is_multimodal;
    std::map<LlamafuLoraAdapter, llama_adapter_lora*> lora_adapters;
    std::vector<LlamafuSampler> samplers;
    llama_sampler* default_sampler;
    LlamafuAbortCallback abort_callback;
    void* abort_callback_data;

    // Multimodal support
    struct clip_ctx* clip_ctx_vision;      // CLIP vision context
    struct clip_ctx* clip_ctx_audio;       // CLIP audio context (future)
    bool vision_initialized;               // Whether vision context is ready

    // Image processing cache
    std::map<std::string, std::vector<float>> image_embeddings_cache;
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

// Forward declarations
static LlamafuError initialize_clip_context(Llamafu llamafu, const char* mmproj_path);

extern "C" {

LlamafuError llamafu_init(LlamafuModelParams* params, Llamafu* out_llamafu) {
    if (!params || !out_llamafu) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_string_param(params->model_path, "model_path")) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Initialize llama backend
        llama_backend_init();

        // Load model with modern API
        llama_model_params model_params = llama_model_default_params();
        model_params.n_gpu_layers = params->n_gpu_layers;

        llama_model* model = llama_model_load_from_file(params->model_path, model_params);
        if (!model) {
            llama_backend_free();
            return LLAMAFU_ERROR_MODEL_LOAD_FAILED;
        }

        // Create context with modern API
        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 2048;  // Default context size
        ctx_params.n_threads = -1;  // Auto-detect threads
        ctx_params.n_threads_batch = -1;  // Auto-detect batch threads

        llama_context* ctx = llama_init_from_model(model, ctx_params);
        if (!ctx) {
            llama_model_free(model);
            llama_backend_free();
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        // Check if model supports multimodal (simplified check)
        bool is_multimodal = params->mmproj_path && strlen(params->mmproj_path) > 0;

        Llamafu llamafu = new Llamafu_s{
            model, ctx, is_multimodal,
            std::map<LlamafuLoraAdapter, llama_adapter_lora*>{},
            std::vector<LlamafuSampler>{},
            nullptr, nullptr, nullptr,
            nullptr, nullptr, false,
            std::map<std::string, std::vector<float>>{}
        };

        // Initialize CLIP context if multimodal is enabled
        if (is_multimodal) {
            LlamafuError clip_init_result = initialize_clip_context(llamafu, params->mmproj_path);
            if (clip_init_result != LLAMAFU_SUCCESS) {
                // Cleanup and return error
                if (llamafu->ctx) {
                    llama_free(llamafu->ctx);
                }
                if (llamafu->model) {
                    llama_model_free(llamafu->model);
                }
                delete llamafu;
                llama_backend_free();
                return clip_init_result;
            }
        }

        *out_llamafu = llamafu;
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_complete(Llamafu llamafu, LlamafuInferParams* params, char** out_result) {
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
        // Tokenize prompt using modern API
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        const int32_t text_len = static_cast<int32_t>(strlen(params->prompt));

        // First pass to get the number of tokens
        const int32_t n_tokens_max = text_len + 16; // Conservative estimate
        std::vector<llama_token> tokens(n_tokens_max);

        const int32_t n_tokens = llama_tokenize(vocab, params->prompt, text_len, tokens.data(), n_tokens_max, true, true);
        if (n_tokens < 0) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        tokens.resize(n_tokens);

        if (tokens.empty()) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Clear the KV cache
        llama_memory_clear(llama_get_memory(llamafu->ctx), false);

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

LlamafuError llamafu_complete_with_grammar(Llamafu llamafu, LlamafuInferParams* params,
                                     void* grammar_params, char** out_result) {
    if (!llamafu || !params || !grammar_params || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    // For now, fall back to regular completion (grammar support can be added later)
    return llamafu_complete(llamafu, params, out_result);
}

LlamafuError llamafu_multimodal_complete(Llamafu llamafu, LlamafuMultimodalInferParams* params, char** out_result) {
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

LlamafuError llamafu_load_lora_adapter_from_file(Llamafu llamafu, const char* lora_path,
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

LlamafuError llamafu_set_lora_adapter(Llamafu llamafu, LlamafuLoraAdapter adapter, float scale) {
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

LlamafuError llamafu_unload_lora_adapter(Llamafu llamafu, LlamafuLoraAdapter adapter) {
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

LlamafuError llamafu_tokenize(Llamafu llamafu, const char* text, int32_t text_len, LlamafuToken** out_tokens, int32_t* out_n_tokens, bool add_special, bool parse_special) {
    if (!llamafu || !text || text_len <= 0 || !out_tokens || !out_n_tokens) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Use modern tokenization API
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);

        // First pass to get the number of tokens
        const int32_t n_tokens_max = text_len + 16; // Conservative estimate
        std::vector<llama_token> tokens(n_tokens_max);

        const int32_t n_tokens = llama_tokenize(vocab, text, text_len, tokens.data(), n_tokens_max, add_special, parse_special);
        if (n_tokens < 0) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        *out_n_tokens = n_tokens;
        *out_tokens = static_cast<LlamafuToken*>(malloc(n_tokens * sizeof(LlamafuToken)));

        if (!*out_tokens) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        for (int32_t i = 0; i < n_tokens; ++i) {
            (*out_tokens)[i] = tokens[i];
        }

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_detokenize(Llamafu llamafu, const LlamafuToken* tokens, int32_t n_tokens, char** out_text, bool remove_special, bool unparse_special) {
    if (!llamafu || !tokens || n_tokens <= 0 || !out_text) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_numeric_param(n_tokens, 1, 32768)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Use modern detokenization API
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);

        // First pass to get required buffer size
        const int32_t text_len_max = n_tokens * 8; // Conservative estimate
        std::vector<char> text_buf(text_len_max);

        const int32_t text_len = llama_detokenize(vocab, tokens, n_tokens, text_buf.data(), text_len_max, remove_special, unparse_special);
        if (text_len < 0) {
            return LLAMAFU_ERROR_UNKNOWN;
        }

        *out_text = static_cast<char*>(malloc(text_len + 1));
        if (!*out_text) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        memcpy(*out_text, text_buf.data(), text_len);
        (*out_text)[text_len] = '\0';

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_get_model_info(Llamafu llamafu, LlamafuModelInfo* out_info) {
    if (!llamafu || !out_info) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        out_info->n_vocab = llama_vocab_n_tokens(vocab);
        out_info->n_ctx_train = llama_model_n_ctx_train(llamafu->model);
        out_info->n_embd = llama_model_n_embd(llamafu->model);
        out_info->supports_multimodal = llamafu->is_multimodal;

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_get_embeddings(Llamafu llamafu, const char* text, float** out_embeddings, int32_t* out_n_embd) {
    if (!llamafu || !validate_string_param(text, "text") || !out_embeddings || !out_n_embd) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Tokenize input using modern API
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        const int32_t text_len = static_cast<int32_t>(strlen(text));

        // First pass to get the number of tokens
        const int32_t n_tokens_max = text_len + 16; // Conservative estimate
        std::vector<llama_token> tokens(n_tokens_max);

        const int32_t n_tokens = llama_tokenize(vocab, text, text_len, tokens.data(), n_tokens_max, true, true);
        if (n_tokens < 0) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        tokens.resize(n_tokens);

        if (tokens.empty()) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Clear the KV cache
        llama_memory_clear(llama_get_memory(llamafu->ctx), false);

        // Evaluate tokens
        if (llama_decode(llamafu->ctx, llama_batch_get_one(tokens.data(), tokens.size())) != 0) {
            return LLAMAFU_ERROR_UNKNOWN;
        }

        // Get embeddings
        int32_t n_embd = llama_model_n_embd(llamafu->model);
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

// Sampler chain implementation
LlamafuSampler llamafu_sampler_chain_init(void) {
    try {
        llama_sampler* chain = llama_sampler_chain_init(llama_sampler_chain_default_params());
        if (!chain) {
            return nullptr;
        }

        LlamafuSampler sampler = new LlamafuSampler_s{chain, LLAMAFU_SAMPLER_CHAIN};
        return sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_top_k(int32_t k) {
    if (k <= 0) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_init_top_k(k);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_TOP_K};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_top_p(float p, size_t min_keep) {
    if (p < 0.0f || p > 1.0f) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_init_top_p(p, min_keep);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_TOP_P};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_min_p(float p, size_t min_keep) {
    if (p < 0.0f || p > 1.0f) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_init_min_p(p, min_keep);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_MIN_P};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_tail_free(float z, size_t min_keep) {
    // Tail free sampling has been removed from llama.cpp
    // Return nullptr to indicate unsupported
    (void)z;
    (void)min_keep;
    return nullptr;
}

LlamafuSampler llamafu_sampler_init_typical(float p, size_t min_keep) {
    if (p < 0.0f || p > 1.0f) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_init_typical(p, min_keep);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_TYPICAL};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_temp(float temp) {
    if (temp < 0.0f) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_init_temp(temp);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_TEMP};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_temp_ext(float temp, float delta, float exponent) {
    if (temp < 0.0f) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_init_temp_ext(temp, delta, exponent);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_TEMP};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_mirostat(int32_t n_vocab, uint32_t seed, float tau, float eta, int32_t m) {
    if (n_vocab <= 0 || tau <= 0.0f || eta <= 0.0f || m <= 0) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_init_mirostat(n_vocab, seed, tau, eta, m);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_MIROSTAT};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_mirostat_v2(uint32_t seed, float tau, float eta) {
    if (tau <= 0.0f || eta <= 0.0f) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_init_mirostat_v2(seed, tau, eta);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_MIROSTAT_V2};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

LlamafuSampler llamafu_sampler_init_grammar(const char* grammar_str, const char* root) {
    // Grammar sampler requires a vocab reference which we don't have in this simplified API
    // Return nullptr to indicate unsupported
    (void)grammar_str;
    (void)root;
    return nullptr;
}

LlamafuSampler llamafu_sampler_init_penalties(int32_t n_vocab, LlamafuToken eos_token, LlamafuToken nl_token,
                                             int32_t repeat_last_n, float repeat_penalty, float freq_penalty,
                                             float presence_penalty, bool penalize_nl, bool ignore_eos) {
    if (repeat_last_n < 0) {
        return nullptr;
    }

    // Note: n_vocab, eos_token, nl_token, penalize_nl, ignore_eos are no longer used in the new API
    (void)n_vocab;
    (void)eos_token;
    (void)nl_token;
    (void)penalize_nl;
    (void)ignore_eos;

    try {
        llama_sampler* sampler = llama_sampler_init_penalties(repeat_last_n, repeat_penalty, freq_penalty, presence_penalty);
        if (!sampler) {
            return nullptr;
        }

        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_PENALTIES};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

int32_t llamafu_sampler_chain_add(LlamafuSampler chain, LlamafuSampler sampler) {
    if (!chain || !sampler || chain->type != LLAMAFU_SAMPLER_CHAIN) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        llama_sampler_chain_add(chain->sampler, sampler->sampler);
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_sampler_chain_remove(LlamafuSampler chain, int32_t i) {
    if (!chain || chain->type != LLAMAFU_SAMPLER_CHAIN || i < 0) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        llama_sampler* removed = llama_sampler_chain_remove(chain->sampler, i);
        if (removed) {
            llama_sampler_free(removed);
        }
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_sampler_chain_n(LlamafuSampler chain) {
    if (!chain || chain->type != LLAMAFU_SAMPLER_CHAIN) {
        return -1;
    }

    try {
        return llama_sampler_chain_n(chain->sampler);
    } catch (const std::exception& e) {
        return -1;
    }
}

LlamafuSampler llamafu_sampler_chain_get(LlamafuSampler chain, int32_t i) {
    if (!chain || chain->type != LLAMAFU_SAMPLER_CHAIN || i < 0) {
        return nullptr;
    }

    try {
        llama_sampler* sampler = llama_sampler_chain_get(chain->sampler, i);
        if (!sampler) {
            return nullptr;
        }

        // Note: This returns a reference to the internal sampler, not owned by caller
        LlamafuSampler llamafu_sampler = new LlamafuSampler_s{sampler, LLAMAFU_SAMPLER_CHAIN};
        return llamafu_sampler;
    } catch (const std::exception& e) {
        return nullptr;
    }
}

llama_token llamafu_sampler_sample(LlamafuSampler sampler, Llamafu llamafu, int32_t idx) {
    if (!sampler || !llamafu || idx < 0) {
        return -1;
    }

    try {
        return llama_sampler_sample(sampler->sampler, llamafu->ctx, idx);
    } catch (const std::exception& e) {
        return -1;
    }
}

void llamafu_sampler_accept(LlamafuSampler sampler, llama_token token) {
    if (!sampler) {
        return;
    }

    try {
        llama_sampler_accept(sampler->sampler, token);
    } catch (const std::exception& e) {
        // Ignore errors in accept
    }
}

void llamafu_sampler_reset(LlamafuSampler sampler) {
    if (!sampler) {
        return;
    }

    try {
        llama_sampler_reset(sampler->sampler);
    } catch (const std::exception& e) {
        // Ignore errors in reset
    }
}

void llamafu_sampler_free(LlamafuSampler sampler) {
    if (sampler) {
        if (sampler->sampler) {
            llama_sampler_free(sampler->sampler);
        }
        delete sampler;
    }
}

// Modern tokenization helper functions
int32_t llamafu_tokenize_modern(Llamafu llamafu, const char* text, LlamafuToken** out_tokens, int32_t* out_n_tokens, bool add_special, bool parse_special) {
    if (!llamafu || !validate_string_param(text, "text") || !out_tokens || !out_n_tokens) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        const int32_t text_len = static_cast<int32_t>(strlen(text));

        // Conservative estimate for token buffer size
        const int32_t n_tokens_max = text_len + 16;
        std::vector<llama_token> tokens(n_tokens_max);

        const int32_t n_tokens = llama_tokenize(vocab, text, text_len, tokens.data(), n_tokens_max, add_special, parse_special);
        if (n_tokens < 0) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }

        *out_n_tokens = n_tokens;
        *out_tokens = static_cast<LlamafuToken*>(malloc(n_tokens * sizeof(LlamafuToken)));

        if (!*out_tokens) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        for (int32_t i = 0; i < n_tokens; ++i) {
            (*out_tokens)[i] = tokens[i];
        }

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

int32_t llamafu_detokenize_modern(Llamafu llamafu, const LlamafuToken* tokens, int32_t n_tokens, char** out_text, bool remove_special, bool unparse_special) {
    if (!llamafu || !tokens || n_tokens <= 0 || !out_text) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_numeric_param(n_tokens, 1, 32768)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);

        // Conservative estimate for text buffer size
        const int32_t text_len_max = n_tokens * 8;
        std::vector<char> text_buf(text_len_max);

        const int32_t text_len = llama_detokenize(vocab, tokens, n_tokens, text_buf.data(), text_len_max, remove_special, unparse_special);
        if (text_len < 0) {
            return LLAMAFU_ERROR_UNKNOWN;
        }

        *out_text = static_cast<char*>(malloc(text_len + 1));
        if (!*out_text) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        memcpy(*out_text, text_buf.data(), text_len);
        (*out_text)[text_len] = '\0';

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_token_to_piece(Llamafu llamafu, LlamafuToken token, char** out_piece) {
    if (!llamafu || !out_piece) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);

        // First call to get required size
        char buf[256];
        int32_t n_chars = llama_token_to_piece(vocab, token, buf, sizeof(buf), 0, true);
        if (n_chars < 0) {
            return LLAMAFU_ERROR_UNKNOWN;
        }

        *out_piece = static_cast<char*>(malloc(n_chars + 1));
        if (!*out_piece) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        memcpy(*out_piece, buf, n_chars);
        (*out_piece)[n_chars] = '\0';

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

// Token information functions
float llamafu_token_get_score(Llamafu llamafu, LlamafuToken token) {
    if (!llamafu) {
        return 0.0f;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_get_score(vocab, token);
    } catch (const std::exception& e) {
        return 0.0f;
    }
}

int32_t llamafu_token_get_attr(Llamafu llamafu, LlamafuToken token) {
    if (!llamafu) {
        return 0;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return static_cast<int32_t>(llama_vocab_get_attr(vocab, token));
    } catch (const std::exception& e) {
        return 0;
    }
}

bool llamafu_token_is_eog(Llamafu llamafu, LlamafuToken token) {
    if (!llamafu) {
        return false;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_is_eog(vocab, token);
    } catch (const std::exception& e) {
        return false;
    }
}

bool llamafu_token_is_control(Llamafu llamafu, LlamafuToken token) {
    if (!llamafu) {
        return false;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_is_control(vocab, token);
    } catch (const std::exception& e) {
        return false;
    }
}

// Special token functions
LlamafuToken llamafu_token_bos(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_bos(vocab);
    } catch (const std::exception& e) {
        return -1;
    }
}

LlamafuToken llamafu_token_eos(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_eos(vocab);
    } catch (const std::exception& e) {
        return -1;
    }
}

LlamafuToken llamafu_token_eot(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_eot(vocab);
    } catch (const std::exception& e) {
        return -1;
    }
}

LlamafuToken llamafu_token_sep(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_sep(vocab);
    } catch (const std::exception& e) {
        return -1;
    }
}

LlamafuToken llamafu_token_nl(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_nl(vocab);
    } catch (const std::exception& e) {
        return -1;
    }
}

LlamafuToken llamafu_token_pad(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }

    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        return llama_vocab_pad(vocab);
    } catch (const std::exception& e) {
        return -1;
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

        // Free all samplers
        for (auto& sampler : llamafu->samplers) {
            llamafu_sampler_free(sampler);
        }
        llamafu->samplers.clear();

        // Free CLIP contexts
        if (llamafu->clip_ctx_vision) {
            clip_free(llamafu->clip_ctx_vision);
        }
        if (llamafu->clip_ctx_audio) {
            clip_free(llamafu->clip_ctx_audio);
        }

        // Clear image embeddings cache
        llamafu->image_embeddings_cache.clear();

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

// Context and memory management functions
LlamafuMemory llamafu_get_memory(Llamafu llamafu) {
    if (!llamafu) {
        return nullptr;
    }
    
    try {
        return llama_get_memory(llamafu->ctx);
    } catch (const std::exception& e) {
        return nullptr;
    }
}

void llamafu_memory_clear(LlamafuMemory memory, bool clear_data) {
    if (memory) {
        try {
            llama_memory_clear(memory, clear_data);
        } catch (const std::exception& e) {
            // Ignore errors in memory clear
        }
    }
}

bool llamafu_memory_seq_rm(LlamafuMemory memory, LlamafuSeqId seq_id, LlamafuPos p0, LlamafuPos p1) {
    if (!memory) {
        return false;
    }
    
    try {
        return llama_memory_seq_rm(memory, seq_id, p0, p1);
    } catch (const std::exception& e) {
        return false;
    }
}

void llamafu_memory_seq_cp(LlamafuMemory memory, LlamafuSeqId seq_id_src, LlamafuSeqId seq_id_dst, LlamafuPos p0, LlamafuPos p1) {
    if (!memory) {
        return;
    }
    
    try {
        llama_memory_seq_cp(memory, seq_id_src, seq_id_dst, p0, p1);
    } catch (const std::exception& e) {
        // Ignore errors in memory copy
    }
}

void llamafu_memory_seq_keep(LlamafuMemory memory, LlamafuSeqId seq_id) {
    if (!memory) {
        return;
    }
    
    try {
        llama_memory_seq_keep(memory, seq_id);
    } catch (const std::exception& e) {
        // Ignore errors in memory keep
    }
}

void llamafu_memory_seq_add(LlamafuMemory memory, LlamafuSeqId seq_id, LlamafuPos p0, LlamafuPos p1, LlamafuPos delta) {
    if (!memory) {
        return;
    }
    
    try {
        llama_memory_seq_add(memory, seq_id, p0, p1, delta);
    } catch (const std::exception& e) {
        // Ignore errors in memory add
    }
}

void llamafu_memory_seq_div(LlamafuMemory memory, LlamafuSeqId seq_id, LlamafuPos p0, LlamafuPos p1, int32_t d) {
    if (!memory || d <= 0) {
        return;
    }
    
    try {
        llama_memory_seq_div(memory, seq_id, p0, p1, d);
    } catch (const std::exception& e) {
        // Ignore errors in memory div
    }
}

LlamafuPos llamafu_memory_seq_pos_min(LlamafuMemory memory, LlamafuSeqId seq_id) {
    if (!memory) {
        return -1;
    }
    
    try {
        return llama_memory_seq_pos_min(memory, seq_id);
    } catch (const std::exception& e) {
        return -1;
    }
}

LlamafuPos llamafu_memory_seq_pos_max(LlamafuMemory memory, LlamafuSeqId seq_id) {
    if (!memory) {
        return -1;
    }
    
    try {
        return llama_memory_seq_pos_max(memory, seq_id);
    } catch (const std::exception& e) {
        return -1;
    }
}

bool llamafu_memory_can_shift(LlamafuMemory memory) {
    if (!memory) {
        return false;
    }
    
    try {
        return llama_memory_can_shift(memory);
    } catch (const std::exception& e) {
        return false;
    }
}

void llamafu_set_warmup(Llamafu llamafu, bool warmup) {
    if (!llamafu) {
        return;
    }
    
    try {
        llama_set_warmup(llamafu->ctx, warmup);
    } catch (const std::exception& e) {
        // Ignore errors in warmup setting
    }
}

size_t llamafu_get_state_size(Llamafu llamafu) {
    if (!llamafu) {
        return 0;
    }

    try {
        return llama_state_get_size(llamafu->ctx);
    } catch (const std::exception& e) {
        return 0;
    }
}

size_t llamafu_copy_state_data(Llamafu llamafu, uint8_t* dest) {
    if (!llamafu || !dest) {
        return 0;
    }

    try {
        return llama_state_get_data(llamafu->ctx, dest, llama_state_get_size(llamafu->ctx));
    } catch (const std::exception& e) {
        return 0;
    }
}

size_t llamafu_set_state_data(Llamafu llamafu, const uint8_t* src) {
    if (!llamafu || !src) {
        return 0;
    }

    try {
        return llama_state_set_data(llamafu->ctx, src, llama_state_get_size(llamafu->ctx));
    } catch (const std::exception& e) {
        return 0;
    }
}

bool llamafu_load_session_file(Llamafu llamafu, const char* path_session, LlamafuToken* tokens_out, size_t n_token_capacity, size_t* n_token_count_out) {
    if (!llamafu || !validate_string_param(path_session, "path_session") || !tokens_out || !n_token_count_out) {
        return false;
    }

    try {
        return llama_state_load_file(llamafu->ctx, path_session, tokens_out, n_token_capacity, n_token_count_out);
    } catch (const std::exception& e) {
        return false;
    }
}

bool llamafu_save_session_file(Llamafu llamafu, const char* path_session, const LlamafuToken* tokens, size_t n_token_count) {
    if (!llamafu || !validate_string_param(path_session, "path_session") || !tokens) {
        return false;
    }

    try {
        return llama_state_save_file(llamafu->ctx, path_session, tokens, n_token_count);
    } catch (const std::exception& e) {
        return false;
    }
}


// Model introspection functions
int32_t llamafu_model_n_ctx_train(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return llama_model_n_ctx_train(llamafu->model);
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_model_n_embd(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return llama_model_n_embd(llamafu->model);
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_model_n_layer(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return llama_model_n_layer(llamafu->model);
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_model_n_head(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return llama_model_n_head(llamafu->model);
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_model_n_head_kv(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return llama_model_n_head_kv(llamafu->model);
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_model_n_swa(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return llama_model_n_swa(llamafu->model);
    } catch (const std::exception& e) {
        return -1;
    }
}

float llamafu_model_rope_freq_scale_train(Llamafu llamafu) {
    if (!llamafu) {
        return 0.0f;
    }
    
    try {
        return llama_model_rope_freq_scale_train(llamafu->model);
    } catch (const std::exception& e) {
        return 0.0f;
    }
}

int32_t llamafu_model_rope_type(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return static_cast<int32_t>(llama_model_rope_type(llamafu->model));
    } catch (const std::exception& e) {
        return -1;
    }
}

uint64_t llamafu_model_size(Llamafu llamafu) {
    if (!llamafu) {
        return 0;
    }
    
    try {
        return llama_model_size(llamafu->model);
    } catch (const std::exception& e) {
        return 0;
    }
}

uint64_t llamafu_model_n_params(Llamafu llamafu) {
    if (!llamafu) {
        return 0;
    }
    
    try {
        return llama_model_n_params(llamafu->model);
    } catch (const std::exception& e) {
        return 0;
    }
}

bool llamafu_model_has_encoder(Llamafu llamafu) {
    if (!llamafu) {
        return false;
    }
    
    try {
        return llama_model_has_encoder(llamafu->model);
    } catch (const std::exception& e) {
        return false;
    }
}

bool llamafu_model_has_decoder(Llamafu llamafu) {
    if (!llamafu) {
        return false;
    }
    
    try {
        return llama_model_has_decoder(llamafu->model);
    } catch (const std::exception& e) {
        return false;
    }
}

LlamafuToken llamafu_model_decoder_start_token(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return llama_model_decoder_start_token(llamafu->model);
    } catch (const std::exception& e) {
        return -1;
    }
}

bool llamafu_model_is_recurrent(Llamafu llamafu) {
    if (!llamafu) {
        return false;
    }
    
    try {
        return llama_model_is_recurrent(llamafu->model);
    } catch (const std::exception& e) {
        return false;
    }
}

bool llamafu_model_is_diffusion(Llamafu llamafu) {
    if (!llamafu) {
        return false;
    }
    
    try {
        return llama_model_is_diffusion(llamafu->model);
    } catch (const std::exception& e) {
        return false;
    }
}

int32_t llamafu_model_desc(Llamafu llamafu, char* buf, size_t buf_size) {
    if (!llamafu || !buf || buf_size == 0) {
        return -1;
    }
    
    try {
        return llama_model_desc(llamafu->model, buf, buf_size);
    } catch (const std::exception& e) {
        return -1;
    }
}

const char* llamafu_model_chat_template(Llamafu llamafu, const char* name) {
    if (!llamafu) {
        return nullptr;
    }
    
    try {
        return llama_model_chat_template(llamafu->model, name);
    } catch (const std::exception& e) {
        return nullptr;
    }
}

// Model metadata functions
int32_t llamafu_model_meta_count(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        return llama_model_meta_count(llamafu->model);
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_model_meta_key_by_index(Llamafu llamafu, int32_t i, char* buf, size_t buf_size) {
    if (!llamafu || !buf || buf_size == 0 || i < 0) {
        return -1;
    }
    
    try {
        return llama_model_meta_key_by_index(llamafu->model, i, buf, buf_size);
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_model_meta_val_str_by_index(Llamafu llamafu, int32_t i, char* buf, size_t buf_size) {
    if (!llamafu || !buf || buf_size == 0 || i < 0) {
        return -1;
    }
    
    try {
        return llama_model_meta_val_str_by_index(llamafu->model, i, buf, buf_size);
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_model_meta_val_str(Llamafu llamafu, const char* key, char* buf, size_t buf_size) {
    if (!llamafu || !validate_string_param(key, "key") || !buf || buf_size == 0) {
        return -1;
    }
    
    try {
        return llama_model_meta_val_str(llamafu->model, key, buf, buf_size);
    } catch (const std::exception& e) {
        return -1;
    }
}

// Vocabulary introspection
int32_t llamafu_vocab_type(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        if (!vocab) {
            return -1;
        }
        return static_cast<int32_t>(llama_vocab_type(vocab));
    } catch (const std::exception& e) {
        return -1;
    }
}

int32_t llamafu_vocab_n_tokens(Llamafu llamafu) {
    if (!llamafu) {
        return -1;
    }
    
    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        if (!vocab) {
            return -1;
        }
        return llama_vocab_n_tokens(vocab);
    } catch (const std::exception& e) {
        return -1;
    }
}

const char* llamafu_vocab_get_text(Llamafu llamafu, LlamafuToken token) {
    if (!llamafu) {
        return nullptr;
    }
    
    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        if (!vocab) {
            return nullptr;
        }
        return llama_vocab_get_text(vocab, token);
    } catch (const std::exception& e) {
        return nullptr;
    }
}

bool llamafu_vocab_get_add_bos(Llamafu llamafu) {
    if (!llamafu) {
        return false;
    }
    
    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        if (!vocab) {
            return false;
        }
        return llama_vocab_get_add_bos(vocab);
    } catch (const std::exception& e) {
        return false;
    }
}

bool llamafu_vocab_get_add_eos(Llamafu llamafu) {
    if (!llamafu) {
        return false;
    }
    
    try {
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        if (!vocab) {
            return false;
        }
        return llama_vocab_get_add_eos(vocab);
    } catch (const std::exception& e) {
        return false;
    }
}

// Advanced model introspection
uint32_t llamafu_model_n_cls_out(Llamafu llamafu) {
    if (!llamafu) {
        return 0;
    }
    
    try {
        return llama_model_n_cls_out(llamafu->model);
    } catch (const std::exception& e) {
        return 0;
    }
}

const char* llamafu_model_cls_label(Llamafu llamafu, uint32_t i) {
    if (!llamafu) {
        return nullptr;
    }
    
    try {
        return llama_model_cls_label(llamafu->model, i);
    } catch (const std::exception& e) {
        return nullptr;
    }
}


// Text generation functions
float* llamafu_get_logits(Llamafu llamafu) {
    if (!llamafu) {
        return nullptr;
    }
    
    try {
        return llama_get_logits(llamafu->ctx);
    } catch (const std::exception& e) {
        return nullptr;
    }
}

float* llamafu_get_logits_ith(Llamafu llamafu, int32_t i) {
    if (!llamafu || i < 0) {
        return nullptr;
    }
    
    try {
        return llama_get_logits_ith(llamafu->ctx, i);
    } catch (const std::exception& e) {
        return nullptr;
    }
}

// Advanced text generation with sampling
LlamafuError llamafu_generate_text(Llamafu llamafu, const char* prompt, LlamafuInferParams* params, char** out_result) {
    if (!llamafu || !validate_string_param(prompt, "prompt") || !params || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!validate_numeric_param(params->max_tokens, 1, 32768) ||
        !validate_float_param(params->temperature, 0.0f, 2.0f) ||
        !validate_float_param(params->top_p, 0.0f, 1.0f) ||
        !validate_numeric_param(params->top_k, 1, 200)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Tokenize prompt
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        const int32_t text_len = static_cast<int32_t>(strlen(prompt));
        const int32_t n_tokens_max = text_len + 16;
        std::vector<llama_token> prompt_tokens(n_tokens_max);

        const int32_t n_prompt = llama_tokenize(vocab, prompt, text_len, prompt_tokens.data(), n_tokens_max, true, true);
        if (n_prompt < 0) {
            return LLAMAFU_ERROR_INVALID_PARAM;
        }
        prompt_tokens.resize(n_prompt);

        // Create sampler chain
        LlamafuSampler sampler_chain = llamafu_sampler_chain_init();
        if (!sampler_chain) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        // Add samplers based on parameters
        if (params->top_k > 0) {
            LlamafuSampler top_k_sampler = llamafu_sampler_init_top_k(params->top_k);
            if (top_k_sampler) {
                llamafu_sampler_chain_add(sampler_chain, top_k_sampler);
            }
        }

        if (params->top_p < 1.0f) {
            LlamafuSampler top_p_sampler = llamafu_sampler_init_top_p(params->top_p, 1);
            if (top_p_sampler) {
                llamafu_sampler_chain_add(sampler_chain, top_p_sampler);
            }
        }

        if (params->temperature > 0.0f) {
            LlamafuSampler temp_sampler = llamafu_sampler_init_temp(params->temperature);
            if (temp_sampler) {
                llamafu_sampler_chain_add(sampler_chain, temp_sampler);
            }
        }

        // Add penalties if specified
        if (params->repeat_penalty != 1.0f || params->frequency_penalty != 0.0f || params->presence_penalty != 0.0f) {
            const int32_t vocab_size = llamafu_vocab_n_tokens(llamafu);
            const LlamafuToken eos_token = llamafu_token_eos(llamafu);
            const LlamafuToken nl_token = llamafu_token_nl(llamafu);
            
            LlamafuSampler penalty_sampler = llamafu_sampler_init_penalties(
                vocab_size, eos_token, nl_token, 64, // penalty_last_n
                params->repeat_penalty, params->frequency_penalty, params->presence_penalty,
                params->penalize_nl, params->ignore_eos
            );
            if (penalty_sampler) {
                llamafu_sampler_chain_add(sampler_chain, penalty_sampler);
            }
        }

        // Clear KV cache and process prompt
        LlamafuMemory memory = llamafu_get_memory(llamafu);
        if (memory) {
            llamafu_memory_clear(memory, false);
        }

        // Process prompt
        if (llama_decode(llamafu->ctx, llama_batch_get_one(prompt_tokens.data(), n_prompt)) != 0) {
            llamafu_sampler_free(sampler_chain);
            return LLAMAFU_ERROR_DECODE_FAILED;
        }

        // Generate tokens
        std::vector<llama_token> generated_tokens;
        generated_tokens.reserve(params->max_tokens);

        for (int32_t i = 0; i < params->max_tokens; ++i) {
            // Sample next token
            llama_token next_token = llamafu_sampler_sample(sampler_chain, llamafu, -1);
            if (next_token < 0) {
                break;
            }

            generated_tokens.push_back(next_token);

            // Check for stop tokens
            if (!params->ignore_eos && next_token == llamafu_token_eos(llamafu)) {
                break;
            }

            // Accept the token for sampling state
            llamafu_sampler_accept(sampler_chain, next_token);

            // Process the token for next iteration
            if (llama_decode(llamafu->ctx, llama_batch_get_one(&next_token, 1)) != 0) {
                break;
            }
        }

        llamafu_sampler_free(sampler_chain);

        // Convert generated tokens to text
        if (generated_tokens.empty()) {
            *out_result = static_cast<char*>(malloc(1));
            if (*out_result) {
                (*out_result)[0] = '\0';
            }
            return LLAMAFU_SUCCESS;
        }

        // Detokenize generated tokens
        const int32_t text_len_max = static_cast<int32_t>(generated_tokens.size()) * 8;
        std::vector<char> text_buf(text_len_max);

        const int32_t generated_text_len = llama_detokenize(vocab, generated_tokens.data(), 
                                                           static_cast<int32_t>(generated_tokens.size()), 
                                                           text_buf.data(), text_len_max, false, false);
        
        if (generated_text_len < 0) {
            return LLAMAFU_ERROR_UNKNOWN;
        }

        // Return generated text
        std::string result(text_buf.data(), generated_text_len);

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

// Streaming text generation - stub implementation
LlamafuError llamafu_generate_text_streaming(Llamafu llamafu, const char* prompt, LlamafuInferParams* params,
                                       void* callback, void* user_data) {
    // Streaming not fully implemented yet
    (void)llamafu;
    (void)prompt;
    (void)params;
    (void)callback;
    (void)user_data;
    return LLAMAFU_ERROR_UNKNOWN;
}

// Simple completion with default parameters
LlamafuError llamafu_complete_simple(Llamafu llamafu, const char* prompt, int32_t max_tokens, char** out_result) {
    if (!llamafu || !validate_string_param(prompt, "prompt") || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    LlamafuInferParams params = {};
    params.prompt = prompt;
    params.max_tokens = max_tokens > 0 ? max_tokens : 128;
    params.temperature = 0.7f;
    params.top_p = 0.9f;
    params.top_k = 40;
    params.repeat_penalty = 1.1f;
    params.frequency_penalty = 0.0f;
    params.presence_penalty = 0.0f;
    // params.stop_on_eos = true;  // Field doesn't exist in struct
    // params.include_prompt = false;  // Field doesn't exist in struct

    return llamafu_complete(llamafu, &params, out_result);
}


// =============================================================================
// Performance and Threading Controls
// =============================================================================

LlamafuError llamafu_set_n_threads(Llamafu llamafu, int32_t n_threads, int32_t n_threads_batch) {
    if (!llamafu) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    if (!validate_numeric_param(n_threads, 1, 128) || !validate_numeric_param(n_threads_batch, 1, 128)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    try {
        llama_set_n_threads(llamafu->ctx, n_threads, n_threads_batch);
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_get_n_threads(Llamafu llamafu, int32_t* out_n_threads, int32_t* out_n_threads_batch) {
    if (!llamafu || !out_n_threads || !out_n_threads_batch) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    try {
        *out_n_threads = llama_n_threads(llamafu->ctx);
        *out_n_threads_batch = llama_n_threads_batch(llamafu->ctx);
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_warmup(Llamafu llamafu) {
    if (!llamafu) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    try {
        // Create a small batch for warmup
        std::vector<llama_token> tokens = {0, 1, 2, 3}; // Simple token sequence
        llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());
        
        // Save current KV cache state
        llamafu_kv_cache_clear(llamafu);

        // Perform warmup decode
        llama_decode(llamafu->ctx, batch);

        // Clear cache after warmup
        llamafu_kv_cache_clear(llamafu);
        
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_get_timings(Llamafu llamafu, LlamafuTimings* out_timings) {
    if (!llamafu || !out_timings) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Simplified implementation - timing API not available in current llama.cpp
        memset(out_timings, 0, sizeof(LlamafuTimings));
        out_timings->t_start_ms = 0.0;
        out_timings->t_end_ms = 0.0;
        out_timings->t_load_ms = 0.0;
        out_timings->t_sample_ms = 0.0;
        out_timings->t_p_eval_ms = 0.0;
        out_timings->t_eval_ms = 0.0;

        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

void llamafu_reset_timings(Llamafu llamafu) {
    if (llamafu) {
        // Simplified implementation - timing API not available in current llama.cpp
        // No-op for now
    }
}

void llamafu_print_timings(Llamafu llamafu) {
    if (llamafu) {
        // Simplified implementation - timing API not available in current llama.cpp
        // No-op for now
    }
}

LlamafuError llamafu_get_system_info(LlamafuSystemInfo* out_info) {
    if (!out_info) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    try {
        const char* sys_info = llama_print_system_info();
        if (sys_info) {
            strncpy(out_info->system_info, sys_info, sizeof(out_info->system_info) - 1);
            out_info->system_info[sizeof(out_info->system_info) - 1] = '\0';
        } else {
            strcpy(out_info->system_info, "System info not available");
        }
        
        // Get CPU info
        out_info->n_cpu_physical = std::thread::hardware_concurrency();
        out_info->n_cpu_logical = std::thread::hardware_concurrency();
        
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_bench_model(Llamafu llamafu, int32_t n_threads, int32_t n_predict, LlamafuBenchResult* out_result) {
    if (!llamafu || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    if (!validate_numeric_param(n_threads, 1, 128) || !validate_numeric_param(n_predict, 1, 1024)) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    try {
        // Save original thread count
        int32_t orig_threads = llama_n_threads(llamafu->ctx);
        int32_t orig_threads_batch = llama_n_threads_batch(llamafu->ctx);
        
        // Set benchmark thread count
        llama_set_n_threads(llamafu->ctx, n_threads, n_threads);
        
        // Reset timings (simplified)
        llamafu_reset_timings(llamafu);

        // Clear cache
        llamafu_kv_cache_clear(llamafu);
        
        // Create benchmark prompt
        const char* bench_prompt = "The quick brown fox jumps over the lazy dog. ";

        // Use modern tokenization API
        const llama_vocab* vocab = llama_model_get_vocab(llamafu->model);
        std::vector<llama_token> tokens(256);  // Reserve space for tokens
        int32_t n_tokens = llama_tokenize(vocab, bench_prompt, strlen(bench_prompt), tokens.data(), tokens.size(), true, true);
        tokens.resize(n_tokens);
        
        auto start_time = std::chrono::high_resolution_clock::now();
        
        // Prompt processing benchmark
        if (llama_decode(llamafu->ctx, llama_batch_get_one(tokens.data(), tokens.size())) != 0) {
            // Restore original settings
            llama_set_n_threads(llamafu->ctx, orig_threads, orig_threads_batch);
            return LLAMAFU_ERROR_UNKNOWN;
        }
        
        auto prompt_time = std::chrono::high_resolution_clock::now();
        
        // Generation benchmark
        for (int32_t i = 0; i < n_predict; ++i) {
            llama_token new_token = llama_sampler_sample(llamafu->default_sampler, llamafu->ctx, -1);
            
            if (llama_decode(llamafu->ctx, llama_batch_get_one(&new_token, 1)) != 0) {
                break;
            }
        }
        
        auto end_time = std::chrono::high_resolution_clock::now();
        
        // Calculate results
        auto prompt_duration = std::chrono::duration_cast<std::chrono::milliseconds>(prompt_time - start_time).count();
        auto total_duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time).count();
        auto generation_duration = total_duration - prompt_duration;
        
        out_result->prompt_tokens = static_cast<int32_t>(tokens.size());
        out_result->prompt_time_ms = static_cast<float>(prompt_duration);
        out_result->generation_tokens = n_predict;
        out_result->generation_time_ms = static_cast<float>(generation_duration);
        out_result->total_time_ms = static_cast<float>(total_duration);
        
        // Calculate speeds
        out_result->prompt_speed_tps = out_result->prompt_time_ms > 0 ? 
            (out_result->prompt_tokens * 1000.0f) / out_result->prompt_time_ms : 0.0f;
        out_result->generation_speed_tps = out_result->generation_time_ms > 0 ? 
            (out_result->generation_tokens * 1000.0f) / out_result->generation_time_ms : 0.0f;
        
        // Restore original thread settings
        llama_set_n_threads(llamafu->ctx, orig_threads, orig_threads_batch);
        
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        // Restore original settings on error
        llama_set_n_threads(llamafu->ctx, llama_n_threads(llamafu->ctx), llama_n_threads_batch(llamafu->ctx));
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_set_abort_callback(Llamafu llamafu, LlamafuAbortCallback callback, void* user_data) {
    if (!llamafu) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    try {
        llamafu->abort_callback = callback;
        llamafu->abort_callback_data = user_data;
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_set_log_callback(LlamafuLogCallback callback, void* user_data) {
    try {
        // Note: llama.cpp's log callback is global, not per-context
        if (callback) {
            llama_log_set([](ggml_log_level level, const char* text, void* user_data) {
                LlamafuLogCallback cb = reinterpret_cast<LlamafuLogCallback>(user_data);
                LlamafuLogLevel llamafu_level;
                
                switch (level) {
                    case GGML_LOG_LEVEL_DEBUG: llamafu_level = LLAMAFU_LOG_DEBUG; break;
                    case GGML_LOG_LEVEL_INFO:  llamafu_level = LLAMAFU_LOG_INFO; break;
                    case GGML_LOG_LEVEL_WARN:  llamafu_level = LLAMAFU_LOG_WARN; break;
                    case GGML_LOG_LEVEL_ERROR: llamafu_level = LLAMAFU_LOG_ERROR; break;
                    default: llamafu_level = LLAMAFU_LOG_INFO; break;
                }
                
                cb(llamafu_level, text, user_data);
            }, reinterpret_cast<void*>(callback));
        } else {
            llama_log_set(nullptr, nullptr);
        }
        
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_get_memory_usage(Llamafu llamafu, LlamafuMemoryUsage* out_usage) {
    if (!llamafu || !out_usage) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }
    
    try {
        // Get model memory usage
        out_usage->model_size_bytes = llama_model_size(llamafu->model);
        
        // Get context memory usage (approximation)
        int32_t n_ctx = llama_n_ctx(llamafu->ctx);
        int32_t n_embd = llama_model_n_embd(llamafu->model);
        int32_t n_layer = llama_model_n_layer(llamafu->model);
        
        // Estimate KV cache size (simplified calculation)
        out_usage->kv_cache_size_bytes = static_cast<uint64_t>(n_ctx) * n_embd * n_layer * 2 * sizeof(float);
        
        // Estimate compute buffer size
        out_usage->compute_buffer_size_bytes = static_cast<uint64_t>(n_ctx) * n_embd * sizeof(float) * 4;
        
        out_usage->total_size_bytes = out_usage->model_size_bytes + 
                                     out_usage->kv_cache_size_bytes + 
                                     out_usage->compute_buffer_size_bytes;
        
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}


// =============================================================================
// Base64 Encoding/Decoding Utilities
// =============================================================================

static const std::string base64_chars = 
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
    "0123456789+/";

static inline bool is_base64(unsigned char c) {
    return (isalnum(c) || (c == '+') || (c == '/'));
}

static std::string base64_encode(unsigned char const* bytes_to_encode, unsigned int in_len) {
    std::string ret;
    int i = 0;
    int j = 0;
    unsigned char char_array_3[3];
    unsigned char char_array_4[4];

    while (in_len--) {
        char_array_3[i++] = *(bytes_to_encode++);
        if (i == 3) {
            char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
            char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
            char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
            char_array_4[3] = char_array_3[2] & 0x3f;

            for (i = 0; (i < 4) ; i++)
                ret += base64_chars[char_array_4[i]];
            i = 0;
        }
    }

    if (i) {
        for (j = i; j < 3; j++)
            char_array_3[j] = '\0';

        char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
        char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
        char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
        char_array_4[3] = char_array_3[2] & 0x3f;

        for (j = 0; (j < i + 1); j++)
            ret += base64_chars[char_array_4[j]];

        while ((i++ < 3))
            ret += '=';
    }

    return ret;
}

static std::vector<unsigned char> base64_decode(std::string const& encoded_string) {
    int in_len = encoded_string.size();
    int i = 0;
    int j = 0;
    int in = 0;
    unsigned char char_array_4[4], char_array_3[3];
    std::vector<unsigned char> ret;

    while (in_len-- && (encoded_string[in] != '=') && is_base64(encoded_string[in])) {
        char_array_4[i++] = encoded_string[in]; in++;
        if (i == 4) {
            for (i = 0; i < 4; i++)
                char_array_4[i] = base64_chars.find(char_array_4[i]);

            char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
            char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
            char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

            for (i = 0; (i < 3); i++)
                ret.push_back(char_array_3[i]);
            i = 0;
        }
    }

    if (i) {
        for (j = i; j < 4; j++)
            char_array_4[j] = 0;

        for (j = 0; j < 4; j++)
            char_array_4[j] = base64_chars.find(char_array_4[j]);

        char_array_3[0] = (char_array_4[0] << 2) + ((char_array_4[1] & 0x30) >> 4);
        char_array_3[1] = ((char_array_4[1] & 0xf) << 4) + ((char_array_4[2] & 0x3c) >> 2);
        char_array_3[2] = ((char_array_4[2] & 0x3) << 6) + char_array_4[3];

        for (j = 0; (j < i - 1); j++) ret.push_back(char_array_3[j]);
    }

    return ret;
}

// =============================================================================
// Image Format Detection and Validation
// =============================================================================

static LlamafuImageFormat detect_image_format_from_header(const unsigned char* data, size_t size) {
    if (size < 4) return LLAMAFU_IMAGE_FORMAT_AUTO;

    // JPEG magic numbers
    if (data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF) {
        return LLAMAFU_IMAGE_FORMAT_JPEG;
    }

    // PNG magic number
    if (size >= 8 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 &&
        data[4] == 0x0D && data[5] == 0x0A && data[6] == 0x1A && data[7] == 0x0A) {
        return LLAMAFU_IMAGE_FORMAT_PNG;
    }

    // BMP magic number
    if (data[0] == 0x42 && data[1] == 0x4D) {
        return LLAMAFU_IMAGE_FORMAT_BMP;
    }

    // WebP magic number
    if (size >= 12 && memcmp(data, "RIFF", 4) == 0 && memcmp(data + 8, "WEBP", 4) == 0) {
        return LLAMAFU_IMAGE_FORMAT_WEBP;
    }

    return LLAMAFU_IMAGE_FORMAT_AUTO;
}

static LlamafuImageFormat detect_format_from_extension(const char* file_path) {
    if (!file_path) return LLAMAFU_IMAGE_FORMAT_AUTO;

    std::string path(file_path);
    std::string ext;

    // Extract extension
    size_t dot_pos = path.find_last_of('.');
    if (dot_pos != std::string::npos) {
        ext = path.substr(dot_pos + 1);
        std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
    }

    if (ext == "jpg" || ext == "jpeg") return LLAMAFU_IMAGE_FORMAT_JPEG;
    if (ext == "png") return LLAMAFU_IMAGE_FORMAT_PNG;
    if (ext == "bmp") return LLAMAFU_IMAGE_FORMAT_BMP;
    if (ext == "webp") return LLAMAFU_IMAGE_FORMAT_WEBP;

    return LLAMAFU_IMAGE_FORMAT_AUTO;
}

// =============================================================================
// Image Loading and Conversion Utilities
// =============================================================================

static LlamafuError load_file_to_memory(const char* file_path, std::vector<unsigned char>& buffer) {
    std::ifstream file(file_path, std::ios::binary | std::ios::ate);
    if (!file.is_open()) {
        return LLAMAFU_ERROR_FILE_NOT_FOUND;
    }

    std::streamsize size = file.tellg();
    file.seekg(0, std::ios::beg);

    buffer.resize(size);
    if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
        return LLAMAFU_ERROR_FILE_READ_FAILED;
    }

    return LLAMAFU_SUCCESS;
}


// =============================================================================
// Enhanced Multimodal API Implementation
// =============================================================================

LlamafuError llamafu_image_validate(const LlamafuMediaInput* input, LlamafuImageValidation* out_validation) {
    if (!input || !out_validation) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    memset(out_validation, 0, sizeof(LlamafuImageValidation));

    try {
        std::vector<unsigned char> image_data;
        
        // Load image data based on source type
        switch (input->source_type) {
            case LLAMAFU_DATA_SOURCE_FILE_PATH: {
                const char* file_path = static_cast<const char*>(input->data);
                if (!validate_string_param(file_path, "file_path")) {
                    out_validation->error_code = LLAMAFU_ERROR_INVALID_PARAM;
                    strcpy(out_validation->error_message, "Invalid file path");
                    return LLAMAFU_ERROR_INVALID_PARAM;
                }

                LlamafuError load_result = load_file_to_memory(file_path, image_data);
                if (load_result != LLAMAFU_SUCCESS) {
                    out_validation->error_code = load_result;
                    strcpy(out_validation->error_message, "Failed to load image file");
                    return load_result;
                }

                out_validation->detected_format = detect_format_from_extension(file_path);
                break;
            }

            case LLAMAFU_DATA_SOURCE_BASE64: {
                const char* base64_str = static_cast<const char*>(input->data);
                if (!validate_string_param(base64_str, "base64_data")) {
                    out_validation->error_code = LLAMAFU_ERROR_INVALID_PARAM;
                    strcpy(out_validation->error_message, "Invalid base64 data");
                    return LLAMAFU_ERROR_INVALID_PARAM;
                }

                try {
                    image_data = base64_decode(base64_str);
                } catch (const std::exception& e) {
                    out_validation->error_code = LLAMAFU_ERROR_BASE64_DECODE_FAILED;
                    strcpy(out_validation->error_message, "Failed to decode base64 data");
                    return LLAMAFU_ERROR_BASE64_DECODE_FAILED;
                }
                break;
            }

            case LLAMAFU_DATA_SOURCE_BINARY: {
                if (!input->data || input->data_size == 0) {
                    out_validation->error_code = LLAMAFU_ERROR_INVALID_PARAM;
                    strcpy(out_validation->error_message, "Invalid binary data");
                    return LLAMAFU_ERROR_INVALID_PARAM;
                }

                const unsigned char* binary_data = static_cast<const unsigned char*>(input->data);
                image_data.assign(binary_data, binary_data + input->data_size);
                break;
            }

            default:
                out_validation->error_code = LLAMAFU_ERROR_INVALID_PARAM;
                strcpy(out_validation->error_message, "Unsupported data source type");
                return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Detect format from data if not specified
        if (out_validation->detected_format == LLAMAFU_IMAGE_FORMAT_AUTO) {
            out_validation->detected_format = detect_image_format_from_header(image_data.data(), image_data.size());
        }

        // Basic validation
        out_validation->file_size_bytes = image_data.size();
        out_validation->is_valid = (out_validation->detected_format != LLAMAFU_IMAGE_FORMAT_AUTO) && 
                                  (image_data.size() > 0);

        // Set basic compatibility info (simplified for now)
        out_validation->supported_by_model = (out_validation->detected_format == LLAMAFU_IMAGE_FORMAT_JPEG ||
                                            out_validation->detected_format == LLAMAFU_IMAGE_FORMAT_PNG);
        out_validation->requires_preprocessing = true;
        out_validation->estimated_processing_time_ms = image_data.size() / 1000.0f; // Rough estimate

        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        out_validation->error_code = LLAMAFU_ERROR_IMAGE_VALIDATION_FAILED;
        snprintf(out_validation->error_message, sizeof(out_validation->error_message), 
                "Validation failed: %s", e.what());
        return LLAMAFU_ERROR_IMAGE_VALIDATION_FAILED;
    }
}

LlamafuError llamafu_image_load_from_file(const char* file_path, LlamafuImageFormat format, LlamafuMediaInput* out_input) {
    if (!validate_string_param(file_path, "file_path") || !out_input) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Initialize media input structure
        memset(out_input, 0, sizeof(LlamafuMediaInput));
        
        out_input->type = LLAMAFU_MEDIA_TYPE_IMAGE;
        out_input->source_type = LLAMAFU_DATA_SOURCE_FILE_PATH;
        out_input->image_format = (format == LLAMAFU_IMAGE_FORMAT_AUTO) ? 
                                 detect_format_from_extension(file_path) : format;
        
        // Store file path (caller is responsible for keeping it valid)
        out_input->data = file_path;
        out_input->data_size = 0; // Not needed for file paths

        // Set default processing options
        out_input->resize_to_model = true;
        out_input->maintain_aspect_ratio = true;
        out_input->pad_to_square = false;
        out_input->quality_hint = 1.0f;

        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_IMAGE_LOAD_FAILED;
    }
}

LlamafuError llamafu_image_load_from_base64(const char* base64_data, LlamafuImageFormat format, LlamafuMediaInput* out_input) {
    if (!validate_string_param(base64_data, "base64_data") || !out_input) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Initialize media input structure
        memset(out_input, 0, sizeof(LlamafuMediaInput));
        
        out_input->type = LLAMAFU_MEDIA_TYPE_IMAGE;
        out_input->source_type = LLAMAFU_DATA_SOURCE_BASE64;
        out_input->image_format = format;
        
        // Store base64 string (caller is responsible for keeping it valid)
        out_input->data = base64_data;
        out_input->data_size = strlen(base64_data);

        // Set default processing options
        out_input->resize_to_model = true;
        out_input->maintain_aspect_ratio = true;
        out_input->pad_to_square = false;
        out_input->quality_hint = 1.0f;

        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_IMAGE_LOAD_FAILED;
    }
}

LlamafuError llamafu_image_load_from_pixels(const unsigned char* rgb_pixels, int32_t width, int32_t height, 
                                           LlamafuImageFormat format, LlamafuMediaInput* out_input) {
    if (!rgb_pixels || width <= 0 || height <= 0 || !out_input) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Initialize media input structure
        memset(out_input, 0, sizeof(LlamafuMediaInput));
        
        out_input->type = LLAMAFU_MEDIA_TYPE_IMAGE;
        out_input->source_type = LLAMAFU_DATA_SOURCE_RGB_PIXELS;
        out_input->image_format = format;
        out_input->width = width;
        out_input->height = height;
        
        // Store pixel data (caller is responsible for keeping it valid)
        out_input->data = rgb_pixels;
        out_input->data_size = width * height * 3; // RGB = 3 bytes per pixel

        // Set default processing options
        out_input->resize_to_model = true;
        out_input->maintain_aspect_ratio = true;
        out_input->pad_to_square = false;
        out_input->quality_hint = 1.0f;

        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_IMAGE_LOAD_FAILED;
    }
}

// Convenience functions for common formats
LlamafuError llamafu_image_from_jpeg_file(const char* path, LlamafuMediaInput* out_input) {
    return llamafu_image_load_from_file(path, LLAMAFU_IMAGE_FORMAT_JPEG, out_input);
}

LlamafuError llamafu_image_from_png_file(const char* path, LlamafuMediaInput* out_input) {
    return llamafu_image_load_from_file(path, LLAMAFU_IMAGE_FORMAT_PNG, out_input);
}

LlamafuError llamafu_image_from_base64_jpeg(const char* base64, LlamafuMediaInput* out_input) {
    return llamafu_image_load_from_base64(base64, LLAMAFU_IMAGE_FORMAT_JPEG, out_input);
}

LlamafuError llamafu_image_from_base64_png(const char* base64, LlamafuMediaInput* out_input) {
    return llamafu_image_load_from_base64(base64, LLAMAFU_IMAGE_FORMAT_PNG, out_input);
}


// =============================================================================
// Image Processing and CLIP Integration
// =============================================================================

static LlamafuError initialize_clip_context(Llamafu llamafu, const char* mmproj_path) {
    if (!llamafu || llamafu->vision_initialized) {
        return LLAMAFU_SUCCESS; // Already initialized
    }

    if (!mmproj_path || strlen(mmproj_path) == 0) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        struct clip_context_params clip_params = {};
        clip_params.use_gpu = true;
        clip_params.verbosity = GGML_LOG_LEVEL_WARN;

        struct clip_init_result clip_result = clip_init(mmproj_path, clip_params);
        
        if (!clip_result.ctx_v) {
            return LLAMAFU_ERROR_VISION_INIT_FAILED;
        }

        llamafu->clip_ctx_vision = clip_result.ctx_v;
        llamafu->clip_ctx_audio = clip_result.ctx_a; // May be null
        llamafu->vision_initialized = true;

        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_VISION_INIT_FAILED;
    }
}

LlamafuError llamafu_image_process(Llamafu llamafu, const LlamafuMediaInput* input, LlamafuImageProcessResult* out_result) {
    if (!llamafu || !input || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!llamafu->is_multimodal || !llamafu->vision_initialized) {
        return LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED;
    }

    memset(out_result, 0, sizeof(LlamafuImageProcessResult));
    auto start_time = std::chrono::high_resolution_clock::now();

    try {
        // Load image data based on source type
        std::vector<unsigned char> image_data;
        
        switch (input->source_type) {
            case LLAMAFU_DATA_SOURCE_FILE_PATH: {
                const char* file_path = static_cast<const char*>(input->data);
                LlamafuError load_result = load_file_to_memory(file_path, image_data);
                if (load_result != LLAMAFU_SUCCESS) {
                    return load_result;
                }
                break;
            }

            case LLAMAFU_DATA_SOURCE_BASE64: {
                const char* base64_str = static_cast<const char*>(input->data);
                try {
                    image_data = base64_decode(base64_str);
                } catch (const std::exception& e) {
                    return LLAMAFU_ERROR_BASE64_DECODE_FAILED;
                }
                break;
            }

            case LLAMAFU_DATA_SOURCE_BINARY: {
                const unsigned char* binary_data = static_cast<const unsigned char*>(input->data);
                image_data.assign(binary_data, binary_data + input->data_size);
                break;
            }

            case LLAMAFU_DATA_SOURCE_RGB_PIXELS: {
                // For raw pixels, we need to create a format that CLIP can understand
                // This would require integration with stb_image or similar
                return LLAMAFU_ERROR_IMAGE_FORMAT_UNSUPPORTED; // TODO: Implement raw pixel processing
            }

            default:
                return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Initialize CLIP image structures
        struct clip_image_u8* img_u8 = clip_image_u8_init();
        if (!img_u8) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        struct clip_image_f32_batch* img_batch = clip_image_f32_batch_init();
        if (!img_batch) {
            clip_image_u8_free(img_u8);
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        // Load image from binary data (this requires stb_image integration)
        // For now, we'll use a simplified approach
        // TODO: Integrate with stb_image for proper image decoding
        
        // Get image requirements from model
        int32_t required_size = clip_get_image_size(llamafu->clip_ctx_vision);
        out_result->processed_width = required_size;
        out_result->processed_height = required_size;

        // Process the image through CLIP
        bool preprocess_success = clip_image_preprocess(llamafu->clip_ctx_vision, img_u8, img_batch);
        if (!preprocess_success) {
            clip_image_u8_free(img_u8);
            clip_image_f32_batch_free(img_batch);
            return LLAMAFU_ERROR_VISION_PROCESS_FAILED;
        }

        // Get embedding dimensions
        int32_t n_embd = clip_n_mmproj_embd(llamafu->clip_ctx_vision);
        out_result->n_embeddings = n_embd;
        out_result->embeddings = static_cast<float*>(malloc(n_embd * sizeof(float)));
        
        if (!out_result->embeddings) {
            clip_image_u8_free(img_u8);
            clip_image_f32_batch_free(img_batch);
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        // Encode image to embeddings
        bool encode_success = clip_image_batch_encode(llamafu->clip_ctx_vision, -1, img_batch, out_result->embeddings);
        if (!encode_success) {
            free(out_result->embeddings);
            out_result->embeddings = nullptr;
            clip_image_u8_free(img_u8);
            clip_image_f32_batch_free(img_batch);
            return LLAMAFU_ERROR_VISION_PROCESS_FAILED;
        }

        // Calculate number of output tokens
        if (clip_image_f32_batch_n_images(img_batch) > 0) {
            struct clip_image_f32* first_img = clip_image_f32_get_img(img_batch, 0);
            out_result->n_tokens = clip_n_output_tokens(llamafu->clip_ctx_vision, first_img);
        }

        // Set processing metadata
        out_result->was_resized = (input->width != required_size || input->height != required_size);
        out_result->was_padded = input->pad_to_square;
        out_result->memory_used_bytes = n_embd * sizeof(float);

        auto end_time = std::chrono::high_resolution_clock::now();
        auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end_time - start_time);
        out_result->processing_time_ms = duration.count() / 1000.0;

        // Cleanup
        clip_image_u8_free(img_u8);
        clip_image_f32_batch_free(img_batch);

        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_VISION_PROCESS_FAILED;
    }
}

LlamafuError llamafu_image_batch_process(Llamafu llamafu, const LlamafuMediaBatch* batch, 
                                        LlamafuImageProcessResult** out_results, size_t* out_n_results) {
    if (!llamafu || !batch || !out_results || !out_n_results) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (batch->n_inputs == 0) {
        *out_results = nullptr;
        *out_n_results = 0;
        return LLAMAFU_SUCCESS;
    }

    try {
        // Allocate results array
        *out_results = static_cast<LlamafuImageProcessResult*>(
            malloc(batch->n_inputs * sizeof(LlamafuImageProcessResult)));
        
        if (!*out_results) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        *out_n_results = batch->n_inputs;
        size_t successful_processed = 0;

        // Process each image
        for (size_t i = 0; i < batch->n_inputs; ++i) {
            LlamafuError result = llamafu_image_process(llamafu, &batch->inputs[i], &(*out_results)[i]);
            if (result == LLAMAFU_SUCCESS) {
                successful_processed++;
            } else {
                // Initialize failed result
                memset(&(*out_results)[i], 0, sizeof(LlamafuImageProcessResult));
            }
        }

        return (successful_processed == batch->n_inputs) ? LLAMAFU_SUCCESS : LLAMAFU_ERROR_BATCH_PROCESS_FAILED;

    } catch (const std::exception& e) {
        if (*out_results) {
            free(*out_results);
            *out_results = nullptr;
        }
        *out_n_results = 0;
        return LLAMAFU_ERROR_BATCH_PROCESS_FAILED;
    }
}

// =============================================================================
// Format Conversion and Utility Functions
// =============================================================================

LlamafuError llamafu_image_to_base64(const LlamafuMediaInput* input, LlamafuImageFormat format, char** out_base64) {
    if (!input || !out_base64) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        std::vector<unsigned char> image_data;
        
        // Load image data
        switch (input->source_type) {
            case LLAMAFU_DATA_SOURCE_FILE_PATH: {
                const char* file_path = static_cast<const char*>(input->data);
                LlamafuError load_result = load_file_to_memory(file_path, image_data);
                if (load_result != LLAMAFU_SUCCESS) {
                    return load_result;
                }
                break;
            }

            case LLAMAFU_DATA_SOURCE_BINARY: {
                const unsigned char* binary_data = static_cast<const unsigned char*>(input->data);
                image_data.assign(binary_data, binary_data + input->data_size);
                break;
            }

            case LLAMAFU_DATA_SOURCE_BASE64: {
                // Already base64, just copy if format matches
                const char* existing_base64 = static_cast<const char*>(input->data);
                size_t len = strlen(existing_base64);
                *out_base64 = static_cast<char*>(malloc(len + 1));
                if (!*out_base64) {
                    return LLAMAFU_ERROR_OUT_OF_MEMORY;
                }
                strcpy(*out_base64, existing_base64);
                return LLAMAFU_SUCCESS;
            }

            default:
                return LLAMAFU_ERROR_INVALID_PARAM;
        }

        // Encode to base64
        std::string base64_result = base64_encode(image_data.data(), image_data.size());
        
        *out_base64 = static_cast<char*>(malloc(base64_result.length() + 1));
        if (!*out_base64) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }

        strcpy(*out_base64, base64_result.c_str());
        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_BASE64_ENCODE_FAILED;
    }
}

const char* llamafu_image_format_to_string(LlamafuImageFormat format) {
    switch (format) {
        case LLAMAFU_IMAGE_FORMAT_AUTO: return "auto";
        case LLAMAFU_IMAGE_FORMAT_JPEG: return "jpeg";
        case LLAMAFU_IMAGE_FORMAT_PNG: return "png";
        case LLAMAFU_IMAGE_FORMAT_BMP: return "bmp";
        case LLAMAFU_IMAGE_FORMAT_WEBP: return "webp";
        case LLAMAFU_IMAGE_FORMAT_RGB24: return "rgb24";
        case LLAMAFU_IMAGE_FORMAT_RGBA32: return "rgba32";
        default: return "unknown";
    }
}

LlamafuImageFormat llamafu_image_format_from_string(const char* format_str) {
    if (!format_str) return LLAMAFU_IMAGE_FORMAT_AUTO;
    
    std::string fmt(format_str);
    std::transform(fmt.begin(), fmt.end(), fmt.begin(), ::tolower);
    
    if (fmt == "auto") return LLAMAFU_IMAGE_FORMAT_AUTO;
    if (fmt == "jpeg" || fmt == "jpg") return LLAMAFU_IMAGE_FORMAT_JPEG;
    if (fmt == "png") return LLAMAFU_IMAGE_FORMAT_PNG;
    if (fmt == "bmp") return LLAMAFU_IMAGE_FORMAT_BMP;
    if (fmt == "webp") return LLAMAFU_IMAGE_FORMAT_WEBP;
    if (fmt == "rgb24" || fmt == "rgb") return LLAMAFU_IMAGE_FORMAT_RGB24;
    if (fmt == "rgba32" || fmt == "rgba") return LLAMAFU_IMAGE_FORMAT_RGBA32;
    
    return LLAMAFU_IMAGE_FORMAT_AUTO;
}

LlamafuImageFormat llamafu_image_detect_format_from_data(const void* data, size_t size) {
    if (!data || size < 4) return LLAMAFU_IMAGE_FORMAT_AUTO;
    return detect_image_format_from_header(static_cast<const unsigned char*>(data), size);
}

LlamafuImageFormat llamafu_image_detect_format_from_path(const char* file_path) {
    return detect_format_from_extension(file_path);
}


// =============================================================================
// Enhanced Multimodal Completion API
// =============================================================================

LlamafuError llamafu_multimodal_complete_enhanced(Llamafu llamafu, LlamafuMultimodalInferParams* params, char** out_result) {
    if (!llamafu || !params || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!llamafu->is_multimodal) {
        return LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED;
    }

    if (!validate_string_param(params->prompt, "prompt")) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Initialize vision context if needed
        if (!llamafu->vision_initialized && params->n_media_inputs > 0) {
            return LLAMAFU_ERROR_VISION_INIT_FAILED;
        }

        // Process all image inputs
        std::vector<LlamafuImageProcessResult> image_results;
        image_results.reserve(params->n_media_inputs);

        for (size_t i = 0; i < params->n_media_inputs; ++i) {
            if (params->media_inputs[i].type == LLAMAFU_MEDIA_TYPE_IMAGE) {
                LlamafuImageProcessResult result;
                LlamafuError process_result = llamafu_image_process(llamafu, &params->media_inputs[i], &result);
                
                if (process_result != LLAMAFU_SUCCESS) {
                    // Cleanup previously processed images
                    for (auto& prev_result : image_results) {
                        if (prev_result.embeddings) {
                            free(prev_result.embeddings);
                        }
                    }
                    return process_result;
                }
                
                image_results.push_back(result);
            }
        }

        // Create enhanced prompt with image tokens
        std::string enhanced_prompt = params->prompt;
        
        if (!image_results.empty() && params->include_image_tokens) {
            std::string image_tokens;
            const char* token_format = params->image_token_format ? params->image_token_format : "<image>";
            
            for (size_t i = 0; i < image_results.size(); ++i) {
                if (i > 0) image_tokens += " ";
                image_tokens += token_format;
            }
            
            if (params->preserve_image_order) {
                enhanced_prompt = image_tokens + " " + enhanced_prompt;
            } else {
                enhanced_prompt = enhanced_prompt + " " + image_tokens;
            }
        }

        // Convert to standard inference parameters
        LlamafuInferParams text_params = {};
        text_params.prompt = enhanced_prompt.c_str();
        text_params.max_tokens = params->max_tokens;
        text_params.temperature = params->temperature;
        text_params.top_k = params->top_k;
        text_params.top_p = params->top_p;
        text_params.min_p = params->min_p;
        text_params.repeat_penalty = params->repeat_penalty;

        // Perform text completion
        LlamafuError completion_result = llamafu_complete(llamafu, &text_params, out_result);

        // Cleanup image processing results
        for (auto& result : image_results) {
            if (result.embeddings) {
                free(result.embeddings);
            }
        }

        return completion_result;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_multimodal_complete_streaming(Llamafu llamafu, LlamafuMultimodalInferParams* params, 
                                                  LlamafuStreamCallback callback, void* user_data) {
    if (!llamafu || !params || !callback) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    // For now, fall back to non-streaming and call callback with complete result
    char* result = nullptr;
    LlamafuError error = llamafu_multimodal_complete_enhanced(llamafu, params, &result);
    
    if (error == LLAMAFU_SUCCESS && result) {
        callback(result, user_data);
        llamafu_free_string(result);
    }
    
    return error;
}

// =============================================================================
// Convenience Functions for Common Use Cases
// =============================================================================

LlamafuError llamafu_chat_with_image_file(Llamafu llamafu, const char* prompt, const char* image_path, 
                                          int32_t max_tokens, char** out_result) {
    if (!llamafu || !validate_string_param(prompt, "prompt") || 
        !validate_string_param(image_path, "image_path") || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Create image input
        LlamafuMediaInput image_input;
        LlamafuError load_result = llamafu_image_load_from_file(image_path, LLAMAFU_IMAGE_FORMAT_AUTO, &image_input);
        if (load_result != LLAMAFU_SUCCESS) {
            return load_result;
        }

        // Create multimodal parameters
        LlamafuMultimodalInferParams mm_params = {};
        mm_params.prompt = prompt;
        mm_params.media_inputs = &image_input;
        mm_params.n_media_inputs = 1;
        mm_params.max_tokens = max_tokens > 0 ? max_tokens : 512;
        mm_params.temperature = 0.7f;
        mm_params.top_k = 40;
        mm_params.top_p = 0.9f;
        mm_params.include_image_tokens = true;
        mm_params.preserve_image_order = true;

        return llamafu_multimodal_complete_enhanced(llamafu, &mm_params, out_result);

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_chat_with_image_base64(Llamafu llamafu, const char* prompt, const char* image_base64, 
                                           int32_t max_tokens, char** out_result) {
    if (!llamafu || !validate_string_param(prompt, "prompt") || 
        !validate_string_param(image_base64, "image_base64") || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Create image input
        LlamafuMediaInput image_input;
        LlamafuError load_result = llamafu_image_load_from_base64(image_base64, LLAMAFU_IMAGE_FORMAT_AUTO, &image_input);
        if (load_result != LLAMAFU_SUCCESS) {
            return load_result;
        }

        // Create multimodal parameters
        LlamafuMultimodalInferParams mm_params = {};
        mm_params.prompt = prompt;
        mm_params.media_inputs = &image_input;
        mm_params.n_media_inputs = 1;
        mm_params.max_tokens = max_tokens > 0 ? max_tokens : 512;
        mm_params.temperature = 0.7f;
        mm_params.top_k = 40;
        mm_params.top_p = 0.9f;
        mm_params.include_image_tokens = true;
        mm_params.preserve_image_order = true;

        return llamafu_multimodal_complete_enhanced(llamafu, &mm_params, out_result);

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_chat_with_multiple_images(Llamafu llamafu, const char* prompt, const char** image_paths, 
                                              size_t n_images, int32_t max_tokens, char** out_result) {
    if (!llamafu || !validate_string_param(prompt, "prompt") || !image_paths || n_images == 0 || !out_result) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Create image inputs array
        std::vector<LlamafuMediaInput> image_inputs(n_images);
        
        for (size_t i = 0; i < n_images; ++i) {
            if (!validate_string_param(image_paths[i], "image_path")) {
                return LLAMAFU_ERROR_INVALID_PARAM;
            }
            
            LlamafuError load_result = llamafu_image_load_from_file(image_paths[i], LLAMAFU_IMAGE_FORMAT_AUTO, &image_inputs[i]);
            if (load_result != LLAMAFU_SUCCESS) {
                return load_result;
            }
        }

        // Create multimodal parameters
        LlamafuMultimodalInferParams mm_params = {};
        mm_params.prompt = prompt;
        mm_params.media_inputs = image_inputs.data();
        mm_params.n_media_inputs = n_images;
        mm_params.max_tokens = max_tokens > 0 ? max_tokens : 512;
        mm_params.temperature = 0.7f;
        mm_params.top_k = 40;
        mm_params.top_p = 0.9f;
        mm_params.include_image_tokens = true;
        mm_params.preserve_image_order = true;

        return llamafu_multimodal_complete_enhanced(llamafu, &mm_params, out_result);

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

// =============================================================================
// Model Information and Utility Functions
// =============================================================================

LlamafuError llamafu_get_image_requirements(Llamafu llamafu, int32_t* out_max_width, int32_t* out_max_height, 
                                           int32_t* out_preferred_size, bool* out_requires_square) {
    if (!llamafu || !out_max_width || !out_max_height || !out_preferred_size || !out_requires_square) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    if (!llamafu->is_multimodal || !llamafu->vision_initialized) {
        return LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED;
    }

    try {
        // Get requirements from CLIP context
        int32_t image_size = clip_get_image_size(llamafu->clip_ctx_vision);
        
        *out_max_width = image_size;
        *out_max_height = image_size;
        *out_preferred_size = image_size;
        *out_requires_square = true; // Most vision models expect square images
        
        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_get_supported_formats(LlamafuImageFormat** out_formats, size_t* out_n_formats) {
    if (!out_formats || !out_n_formats) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    static LlamafuImageFormat supported_formats[] = {
        LLAMAFU_IMAGE_FORMAT_JPEG,
        LLAMAFU_IMAGE_FORMAT_PNG,
        LLAMAFU_IMAGE_FORMAT_BMP,
        LLAMAFU_IMAGE_FORMAT_WEBP
    };

    *out_n_formats = sizeof(supported_formats) / sizeof(supported_formats[0]);
    *out_formats = static_cast<LlamafuImageFormat*>(malloc(*out_n_formats * sizeof(LlamafuImageFormat)));
    
    if (!*out_formats) {
        return LLAMAFU_ERROR_OUT_OF_MEMORY;
    }

    memcpy(*out_formats, supported_formats, *out_n_formats * sizeof(LlamafuImageFormat));
    return LLAMAFU_SUCCESS;
}

// =============================================================================
// Memory Management Functions
// =============================================================================

void llamafu_media_input_free(LlamafuMediaInput* input) {
    if (input) {
        // Note: We don't free input->data as it's owned by the caller
        memset(input, 0, sizeof(LlamafuMediaInput));
    }
}

void llamafu_media_batch_free(LlamafuMediaBatch* batch) {
    if (batch) {
        if (batch->inputs) {
            for (size_t i = 0; i < batch->n_inputs; ++i) {
                llamafu_media_input_free(&batch->inputs[i]);
            }
            free(batch->inputs);
        }
        memset(batch, 0, sizeof(LlamafuMediaBatch));
    }
}

void llamafu_image_process_result_free(LlamafuImageProcessResult* result) {
    if (result) {
        if (result->embeddings) {
            free(result->embeddings);
        }
        memset(result, 0, sizeof(LlamafuImageProcessResult));
    }
}

void llamafu_image_validation_free(LlamafuImageValidation* validation) {
    if (validation) {
        memset(validation, 0, sizeof(LlamafuImageValidation));
    }
}


// =============================================================================
// JSON Schema to GBNF Grammar Conversion
// =============================================================================

// Helper to escape string for GBNF
static std::string gbnf_escape(const std::string& s) {
    std::string result;
    for (char c : s) {
        if (c == '"' || c == '\\') {
            result += '\\';
        }
        result += c;
    }
    return result;
}

// Generate unique rule name
static std::string generate_rule_name(const std::string& base, int& counter) {
    return base + "_" + std::to_string(counter++);
}

// Forward declaration
static std::string schema_to_gbnf_rule(const std::string& json_schema, const std::string& rule_name, 
                                       std::string& rules, int& counter);

// Convert JSON Schema type to GBNF
static std::string json_type_to_gbnf(const std::string& type_str, const std::string& schema_json,
                                     std::string& rules, int& counter) {
    if (type_str == "string") {
        return "\"\\\"\" [^\"]* \"\\\"\"";
    } else if (type_str == "integer") {
        return "\"-\"? [0-9]+";
    } else if (type_str == "number") {
        return "\"-\"? [0-9]+ (\".\" [0-9]+)?";
    } else if (type_str == "boolean") {
        return "(\"true\" | \"false\")";
    } else if (type_str == "null") {
        return "\"null\"";
    } else if (type_str == "array") {
        return "\"[\" ws (value (ws \",\" ws value)*)? ws \"]\"";
    } else if (type_str == "object") {
        return "\"{\" ws (string ws \":\" ws value (ws \",\" ws string ws \":\" ws value)*)? ws \"}\"";
    }
    return "value";
}

// Parse simple JSON to extract field
static std::string extract_json_field(const std::string& json, const std::string& field) {
    std::string search = "\"" + field + "\"";
    size_t pos = json.find(search);
    if (pos == std::string::npos) return "";
    
    pos = json.find(':', pos);
    if (pos == std::string::npos) return "";
    pos++;
    
    // Skip whitespace
    while (pos < json.size() && (json[pos] == ' ' || json[pos] == '\n' || json[pos] == '\t')) pos++;
    
    if (pos >= json.size()) return "";
    
    // Extract value
    if (json[pos] == '"') {
        // String value
        size_t end = json.find('"', pos + 1);
        if (end != std::string::npos) {
            return json.substr(pos + 1, end - pos - 1);
        }
    } else if (json[pos] == '{' || json[pos] == '[') {
        // Object or array - find matching bracket
        char open = json[pos];
        char close = (open == '{') ? '}' : ']';
        int depth = 1;
        size_t end = pos + 1;
        while (end < json.size() && depth > 0) {
            if (json[end] == open) depth++;
            else if (json[end] == close) depth--;
            end++;
        }
        return json.substr(pos, end - pos);
    } else {
        // Primitive value
        size_t end = pos;
        while (end < json.size() && json[end] != ',' && json[end] != '}' && json[end] != ']') end++;
        std::string val = json.substr(pos, end - pos);
        // Trim
        while (!val.empty() && (val.back() == ' ' || val.back() == '\n')) val.pop_back();
        return val;
    }
    return "";
}

LlamafuError llamafu_schema_to_grammar(const char* json_schema, char** out_grammar) {
    if (!json_schema || !out_grammar) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        std::string schema(json_schema);
        std::string rules;
        int counter = 0;
        
        // Basic GBNF structure
        std::string grammar = R"(
root ::= json
json ::= object | array | string | number | "true" | "false" | "null"
object ::= "{" ws (pair (ws "," ws pair)*)? ws "}"
pair ::= string ws ":" ws json
array ::= "[" ws (json (ws "," ws json)*)? ws "]"
string ::= "\"" ([^"\\] | "\\" .)* "\""
number ::= "-"? [0-9]+ ("." [0-9]+)? ([eE] [+-]? [0-9]+)?
ws ::= [ \t\n\r]*
)";
        
        // If schema specifies type, we can be more specific
        std::string type_str = extract_json_field(schema, "type");
        if (type_str == "object") {
            std::string properties = extract_json_field(schema, "properties");
            if (!properties.empty()) {
                // Build specific object grammar
                grammar = "root ::= specific-object\n";
                grammar += "specific-object ::= \"{\" ws ";
                
                // Parse properties (simplified)
                // In production, use proper JSON parser
                grammar += "pair (ws \",\" ws pair)* ";
                grammar += "ws \"}\"\n";
                grammar += R"(
pair ::= string ws ":" ws value
string ::= "\"" ([^"\\] | "\\" .)* "\""
value ::= string | number | "true" | "false" | "null" | object | array
object ::= "{" ws (pair (ws "," ws pair)*)? ws "}"
array ::= "[" ws (value (ws "," ws value)*)? ws "]"
number ::= "-"? [0-9]+ ("." [0-9]+)?
ws ::= [ \t\n\r]*
)";
            }
        }
        
        *out_grammar = strdup(grammar.c_str());
        if (!*out_grammar) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }
        
        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

// =============================================================================
// Tool Calling Implementation
// =============================================================================

LlamafuError llamafu_build_tool_grammar(const LlamafuTool* tools, size_t n_tools, 
                                        bool allow_multiple, char** out_grammar) {
    if (!tools || n_tools == 0 || !out_grammar) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        std::string grammar;
        
        if (allow_multiple) {
            grammar = "root ::= \"{\" ws \"\\\"tool_calls\\\"\" ws \":\" ws \"[\" ws tool-call (ws \",\" ws tool-call)* ws \"]\" ws \"}\"\n";
        } else {
            grammar = "root ::= tool-call\n";
        }
        
        // Build tool-call rule with all possible tools
        grammar += "tool-call ::= \"{\" ws ";
        grammar += "\"\\\"id\\\"\" ws \":\" ws string ws \",\" ws ";
        grammar += "\"\\\"name\\\"\" ws \":\" ws tool-name ws \",\" ws ";
        grammar += "\"\\\"arguments\\\"\" ws \":\" ws tool-args ws ";
        grammar += "\"}\"\n";
        
        // Tool names
        grammar += "tool-name ::= ";
        for (size_t i = 0; i < n_tools; i++) {
            if (i > 0) grammar += " | ";
            grammar += "\"\\\"" + std::string(tools[i].name) + "\\\"\"";
        }
        grammar += "\n";
        
        // Tool arguments (JSON object)
        grammar += "tool-args ::= \"{\" ws (pair (ws \",\" ws pair)*)? ws \"}\"\n";
        
        // Common rules
        grammar += R"(
pair ::= string ws ":" ws value
string ::= "\"" ([^"\\] | "\\" .)* "\""
value ::= string | number | "true" | "false" | "null" | object | array
object ::= "{" ws (pair (ws "," ws pair)*)? ws "}"
array ::= "[" ws (value (ws "," ws value)*)? ws "]"
number ::= "-"? [0-9]+ ("." [0-9]+)?
ws ::= [ \t\n\r]*
)";
        
        *out_grammar = strdup(grammar.c_str());
        if (!*out_grammar) {
            return LLAMAFU_ERROR_OUT_OF_MEMORY;
        }
        
        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

// Generate unique ID for tool call
static std::string generate_call_id() {
    static int call_counter = 0;
    return "call_" + std::to_string(++call_counter);
}

// Parse tool call from generated JSON
static bool parse_tool_call(const std::string& json, LlamafuToolCall* call) {
    call->id = strdup(extract_json_field(json, "id").c_str());
    if (!call->id || strlen(call->id) == 0) {
        free(call->id);
        call->id = strdup(generate_call_id().c_str());
    }
    
    std::string name = extract_json_field(json, "name");
    call->name = strdup(name.c_str());
    
    std::string args = extract_json_field(json, "arguments");
    call->arguments_json = strdup(args.c_str());
    
    return call->name && strlen(call->name) > 0;
}

LlamafuError llamafu_generate_tool_call(Llamafu llamafu, const LlamafuToolCallParams* params,
                                        LlamafuToolCall** out_calls, size_t* out_n_calls) {
    if (!llamafu || !params || !out_calls || !out_n_calls) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Build grammar for tool calling
        char* grammar = nullptr;
        LlamafuError err = llamafu_build_tool_grammar(params->tools, params->n_tools, 
                                                      params->allow_multiple_calls, &grammar);
        if (err != LLAMAFU_SUCCESS) {
            return err;
        }
        
        // Build prompt with tool definitions
        std::string full_prompt = "You have access to the following tools:\n\n";
        for (size_t i = 0; i < params->n_tools; i++) {
            full_prompt += "- " + std::string(params->tools[i].name) + ": ";
            full_prompt += std::string(params->tools[i].description) + "\n";
            if (params->tools[i].parameters_schema) {
                full_prompt += "  Parameters: " + std::string(params->tools[i].parameters_schema) + "\n";
            }
        }
        full_prompt += "\nUser: " + std::string(params->prompt) + "\n";
        full_prompt += "\nRespond with a tool call in JSON format:\n";
        
        // Set up inference parameters
        LlamafuInferParams infer_params = {};
        infer_params.prompt = full_prompt.c_str();
        infer_params.max_tokens = params->max_tokens > 0 ? params->max_tokens : 256;
        infer_params.temperature = params->temperature > 0 ? params->temperature : 0.1f;
        infer_params.seed = params->seed;
        infer_params.grammar_str = grammar;
        infer_params.grammar_root = "root";
        
        // Generate
        char* result = nullptr;
        err = llamafu_complete(llamafu, &infer_params, &result);
        free(grammar);
        
        if (err != LLAMAFU_SUCCESS) {
            return err;
        }
        
        // Parse result
        std::string result_str(result);
        free(result);
        
        if (params->allow_multiple_calls) {
            // Parse array of tool calls
            std::string calls_json = extract_json_field(result_str, "tool_calls");
            // Simplified: assume single call for now
            *out_n_calls = 1;
            *out_calls = (LlamafuToolCall*)calloc(1, sizeof(LlamafuToolCall));
            if (!*out_calls) {
                return LLAMAFU_ERROR_OUT_OF_MEMORY;
            }
            // Parse from array - simplified
            size_t start = calls_json.find('{');
            size_t end = calls_json.rfind('}');
            if (start != std::string::npos && end != std::string::npos) {
                std::string call_json = calls_json.substr(start, end - start + 1);
                parse_tool_call(call_json, &(*out_calls)[0]);
            }
        } else {
            // Single tool call
            *out_n_calls = 1;
            *out_calls = (LlamafuToolCall*)calloc(1, sizeof(LlamafuToolCall));
            if (!*out_calls) {
                return LLAMAFU_ERROR_OUT_OF_MEMORY;
            }
            parse_tool_call(result_str, &(*out_calls)[0]);
        }
        
        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_generate_tool_call_streaming(Llamafu llamafu, const LlamafuToolCallParams* params,
                                                  LlamafuStreamCallback callback, void* user_data,
                                                  LlamafuToolCall** out_calls, size_t* out_n_calls) {
    // For now, use non-streaming and return result
    // Streaming will call back with tokens as they're generated
    return llamafu_generate_tool_call(llamafu, params, out_calls, out_n_calls);
}

void llamafu_free_tool_calls(LlamafuToolCall* calls, size_t n_calls) {
    if (calls) {
        for (size_t i = 0; i < n_calls; i++) {
            free(calls[i].id);
            free(calls[i].name);
            free(calls[i].arguments_json);
        }
        free(calls);
    }
}

// =============================================================================
// JSON Output Implementation
// =============================================================================

LlamafuError llamafu_generate_json(Llamafu llamafu, const LlamafuJsonParams* params, char** out_json) {
    if (!llamafu || !params || !out_json) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Convert schema to grammar
        char* grammar = nullptr;
        LlamafuError err = llamafu_schema_to_grammar(params->schema, &grammar);
        if (err != LLAMAFU_SUCCESS) {
            return err;
        }
        
        // Set up inference parameters
        LlamafuInferParams infer_params = {};
        infer_params.prompt = params->prompt;
        infer_params.max_tokens = params->max_tokens > 0 ? params->max_tokens : 256;
        infer_params.temperature = params->temperature > 0 ? params->temperature : 0.1f;
        infer_params.seed = params->seed;
        infer_params.grammar_str = grammar;
        infer_params.grammar_root = "root";
        
        // Generate
        err = llamafu_complete(llamafu, &infer_params, out_json);
        free(grammar);
        
        return err;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_generate_json_streaming(Llamafu llamafu, const LlamafuJsonParams* params,
                                             LlamafuStreamCallback callback, void* user_data) {
    if (!llamafu || !params || !callback) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Convert schema to grammar
        char* grammar = nullptr;
        LlamafuError err = llamafu_schema_to_grammar(params->schema, &grammar);
        if (err != LLAMAFU_SUCCESS) {
            return err;
        }
        
        // Set up inference parameters
        LlamafuInferParams infer_params = {};
        infer_params.prompt = params->prompt;
        infer_params.max_tokens = params->max_tokens > 0 ? params->max_tokens : 256;
        infer_params.temperature = params->temperature > 0 ? params->temperature : 0.1f;
        infer_params.seed = params->seed;
        infer_params.grammar_str = grammar;
        infer_params.grammar_root = "root";
        
        // Generate with streaming
        err = llamafu_complete_stream(llamafu, &infer_params, callback, user_data);
        free(grammar);
        
        return err;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}

LlamafuError llamafu_json_validate(const char* json_string, const char* schema, 
                                   bool* out_valid, char** out_error) {
    if (!json_string || !schema || !out_valid) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    try {
        // Basic JSON validation - check for balanced braces
        int brace_count = 0;
        int bracket_count = 0;
        bool in_string = false;
        bool escape_next = false;
        
        for (const char* p = json_string; *p; p++) {
            if (escape_next) {
                escape_next = false;
                continue;
            }
            
            if (*p == '\\') {
                escape_next = true;
                continue;
            }
            
            if (*p == '"') {
                in_string = !in_string;
                continue;
            }
            
            if (!in_string) {
                if (*p == '{') brace_count++;
                else if (*p == '}') brace_count--;
                else if (*p == '[') bracket_count++;
                else if (*p == ']') bracket_count--;
            }
        }
        
        *out_valid = (brace_count == 0 && bracket_count == 0 && !in_string);
        
        if (!*out_valid && out_error) {
            if (brace_count != 0) {
                *out_error = strdup("Unbalanced braces in JSON");
            } else if (bracket_count != 0) {
                *out_error = strdup("Unbalanced brackets in JSON");
            } else {
                *out_error = strdup("Unterminated string in JSON");
            }
        }
        
        return LLAMAFU_SUCCESS;

    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}
