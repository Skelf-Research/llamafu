#ifndef LLAMAFU_H
#define LLAMAFU_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to the Llamafu instance
typedef struct Llamafu_s* Llamafu;

// Opaque handle to the LoRA adapter
typedef struct LlamafuLoraAdapter_s* LlamafuLoraAdapter;

// Opaque handle to the grammar sampler
typedef struct LlamafuGrammarSampler_s* LlamafuGrammarSampler;

// Error codes
typedef enum {
    LLAMAFU_SUCCESS = 0,
    LLAMAFU_ERROR_UNKNOWN = -1,
    LLAMAFU_ERROR_INVALID_PARAM = -2,
    LLAMAFU_ERROR_MODEL_LOAD_FAILED = -3,
    LLAMAFU_ERROR_OUT_OF_MEMORY = -4,
    LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED = -5,
    LLAMAFU_ERROR_LORA_LOAD_FAILED = -6,
    LLAMAFU_ERROR_LORA_NOT_FOUND = -7,
    LLAMAFU_ERROR_GRAMMAR_INIT_FAILED = -8,
} LlamafuError;

// Model parameters
typedef struct {
    const char* model_path;
    const char* mmproj_path;  // Multi-modal projector path (optional)
    int n_threads;
    int n_ctx;
    bool use_gpu;             // Whether to use GPU for multi-modal processing
} LlamafuModelParams;

// Inference parameters
typedef struct {
    const char* prompt;
    int max_tokens;
    float temperature;
    int top_k;                // Top-K sampling (0 = disabled)
    float top_p;              // Top-P/nucleus sampling (1.0 = disabled)
    float repeat_penalty;     // Repetition penalty (1.0 = disabled)
    int repeat_last_n;        // Last n tokens for repetition penalty
    uint32_t seed;            // Random seed for sampling
    float min_p;              // Minimum P sampling (0.0 = disabled)
    float typical_p;          // Typical P sampling (1.0 = disabled)
} LlamafuInferParams;

// Constrained generation parameters
typedef struct {
    const char* grammar_str;     // GBNF grammar string
    const char* grammar_root;    // Root symbol of the grammar
} LlamafuGrammarParams;

// Multi-modal input types
typedef enum {
    LLAMAFU_MEDIA_TYPE_TEXT = 0,
    LLAMAFU_MEDIA_TYPE_IMAGE = 1,
    LLAMAFU_MEDIA_TYPE_AUDIO = 2,
} LlamafuMediaType;

// Multi-modal input data
typedef struct {
    LlamafuMediaType type;
    const char* data;        // Path to file or base64 encoded data
    size_t data_size;        // Size of data in bytes
} LlamafuMediaInput;

// Multi-modal inference parameters
typedef struct {
    const char* prompt;
    LlamafuMediaInput* media_inputs;
    size_t n_media_inputs;
    int max_tokens;
    float temperature;
} LlamafuMultimodalInferParams;

// Callback for streaming output
typedef void (*LlamafuStreamCallback)(const char* token, void* user_data);

// Initialize the Llamafu library
LlamafuError llamafu_init(LlamafuModelParams* params, Llamafu* out_llamafu);

// Perform text completion
LlamafuError llamafu_complete(Llamafu llamafu, LlamafuInferParams* params, char** out_result);

// Perform text completion with streaming
LlamafuError llamafu_complete_stream(Llamafu llamafu, LlamafuInferParams* params, LlamafuStreamCallback callback, void* user_data);

// Perform text completion with grammar constraints
LlamafuError llamafu_complete_with_grammar(Llamafu llamafu, LlamafuInferParams* params, LlamafuGrammarParams* grammar_params, char** out_result);

// Perform text completion with grammar constraints and streaming
LlamafuError llamafu_complete_with_grammar_stream(Llamafu llamafu, LlamafuInferParams* params, LlamafuGrammarParams* grammar_params, LlamafuStreamCallback callback, void* user_data);

// Perform multi-modal completion
LlamafuError llamafu_multimodal_complete(Llamafu llamafu, LlamafuMultimodalInferParams* params, char** out_result);

// Perform multi-modal completion with streaming
LlamafuError llamafu_multimodal_complete_stream(Llamafu llamafu, LlamafuMultimodalInferParams* params, LlamafuStreamCallback callback, void* user_data);

// LoRA adapter functions
LlamafuError llamafu_lora_adapter_init(Llamafu llamafu, const char* lora_path, LlamafuLoraAdapter* out_adapter);
LlamafuError llamafu_lora_adapter_apply(Llamafu llamafu, LlamafuLoraAdapter adapter, float scale);
LlamafuError llamafu_lora_adapter_remove(Llamafu llamafu, LlamafuLoraAdapter adapter);
LlamafuError llamafu_lora_adapter_clear_all(Llamafu llamafu);
void llamafu_lora_adapter_free(LlamafuLoraAdapter adapter);

// Grammar sampler functions
LlamafuError llamafu_grammar_sampler_init(Llamafu llamafu, const char* grammar_str, const char* grammar_root, LlamafuGrammarSampler* out_sampler);
void llamafu_grammar_sampler_free(LlamafuGrammarSampler sampler);

// Model information
typedef struct {
    int n_vocab;              // Vocabulary size
    int n_ctx_train;          // Training context length
    int n_embd;               // Embedding dimensions
    int n_layer;              // Number of layers
    const char* architecture; // Model architecture name
} LlamafuModelInfo;

// Token-level operations
LlamafuError llamafu_tokenize(Llamafu llamafu, const char* text, int* tokens, int max_tokens, int* n_tokens);
LlamafuError llamafu_detokenize(Llamafu llamafu, const int* tokens, int n_tokens, char** out_text);
LlamafuError llamafu_get_logits(Llamafu llamafu, float** out_logits, int* n_logits);

// Model introspection
LlamafuError llamafu_get_model_info(Llamafu llamafu, LlamafuModelInfo* out_info);

// Embeddings support
LlamafuError llamafu_get_embeddings(Llamafu llamafu, const char* text, float** out_embeddings, int* n_embeddings);

// Clean up resources
void llamafu_free(Llamafu llamafu);
void llamafu_free_string(char* str);

#ifdef __cplusplus
}
#endif

#endif // LLAMAFU_H