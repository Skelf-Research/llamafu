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
    // Add more parameters as needed
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

// Clean up resources
void llamafu_free(Llamafu llamafu);

#ifdef __cplusplus
}
#endif

#endif // LLAMAFU_H