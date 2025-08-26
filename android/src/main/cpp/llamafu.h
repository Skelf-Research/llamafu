#ifndef LLAMAFU_H
#define LLAMAFU_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle to the Llamafu instance
typedef struct Llamafu_s* Llamafu;

// Error codes
typedef enum {
    LLAMAFU_SUCCESS = 0,
    LLAMAFU_ERROR_UNKNOWN = -1,
    LLAMAFU_ERROR_INVALID_PARAM = -2,
    LLAMAFU_ERROR_MODEL_LOAD_FAILED = -3,
    LLAMAFU_ERROR_OUT_OF_MEMORY = -4,
} LlamafuError;

// Model parameters
typedef struct {
    const char* model_path;
    int n_threads;
    int n_ctx;
    // Add more parameters as needed
} LlamafuModelParams;

// Inference parameters
typedef struct {
    const char* prompt;
    int max_tokens;
    float temperature;
    // Add more parameters as needed
} LlamafuInferParams;

// Callback for streaming output
typedef void (*LlamafuStreamCallback)(const char* token, void* user_data);

// Initialize the Llamafu library
LlamafuError llamafu_init(LlamafuModelParams* params, Llamafu* out_llamafu);

// Perform text completion
LlamafuError llamafu_complete(Llamafu llamafu, LlamafuInferParams* params, char** out_result);

// Perform text completion with streaming
LlamafuError llamafu_complete_stream(Llamafu llamafu, LlamafuInferParams* params, LlamafuStreamCallback callback, void* user_data);

// Clean up resources
void llamafu_free(Llamafu llamafu);

#ifdef __cplusplus
}
#endif

#endif // LLAMAFU_H