#ifndef LLAMAFU_H
#define LLAMAFU_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declarations
typedef struct Llamafu_s* Llamafu;
typedef struct LlamafuLoraAdapter_s* LlamafuLoraAdapter;
typedef struct LlamafuGrammarSampler_s* LlamafuGrammarSampler;
typedef struct LlamafuSampler_s* LlamafuSampler;
typedef struct LlamafuBatch_s* LlamafuBatch;
typedef int32_t LlamafuToken;

// Sampler types
typedef enum {
    LLAMAFU_SAMPLER_GREEDY = 0,
    LLAMAFU_SAMPLER_DIST = 1,
    LLAMAFU_SAMPLER_TOP_K = 2,
    LLAMAFU_SAMPLER_TOP_P = 3,
    LLAMAFU_SAMPLER_MIN_P = 4,
    LLAMAFU_SAMPLER_TYPICAL = 5,
    LLAMAFU_SAMPLER_TEMP = 6,
    LLAMAFU_SAMPLER_MIROSTAT = 7,
    LLAMAFU_SAMPLER_MIROSTAT_V2 = 8,
    LLAMAFU_SAMPLER_PENALTIES = 9,
    LLAMAFU_SAMPLER_GRAMMAR = 10,
    LLAMAFU_SAMPLER_CHAIN = 11
} LlamafuSamplerType;

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
    LLAMAFU_ERROR_CONTEXT_INIT_FAILED = -9,
    LLAMAFU_ERROR_TOKENIZATION_FAILED = -10,
    LLAMAFU_ERROR_DECODE_FAILED = -11,

    // Multimodal-specific errors
    LLAMAFU_ERROR_IMAGE_LOAD_FAILED = -20,
    LLAMAFU_ERROR_IMAGE_FORMAT_UNSUPPORTED = -21,
    LLAMAFU_ERROR_IMAGE_DECODE_FAILED = -22,
    LLAMAFU_ERROR_IMAGE_ENCODE_FAILED = -23,
    LLAMAFU_ERROR_IMAGE_RESIZE_FAILED = -24,
    LLAMAFU_ERROR_IMAGE_VALIDATION_FAILED = -25,
    LLAMAFU_ERROR_BASE64_DECODE_FAILED = -26,
    LLAMAFU_ERROR_BASE64_ENCODE_FAILED = -27,
    LLAMAFU_ERROR_FILE_NOT_FOUND = -28,
    LLAMAFU_ERROR_FILE_READ_FAILED = -29,
    LLAMAFU_ERROR_VISION_INIT_FAILED = -30,
    LLAMAFU_ERROR_VISION_PROCESS_FAILED = -31,
    LLAMAFU_ERROR_IMAGE_TOO_LARGE = -32,
    LLAMAFU_ERROR_IMAGE_TOO_SMALL = -33,
    LLAMAFU_ERROR_INVALID_DIMENSIONS = -34,
    LLAMAFU_ERROR_BATCH_PROCESS_FAILED = -35,
    LLAMAFU_ERROR_ABORTED = -36,
} LlamafuError;

// Model parameters - simplified for FFI compatibility
typedef struct {
    const char* model_path;           // Path to model file
    const char* mmproj_path;          // Multi-modal projector path (optional)
    int32_t n_threads;                // Number of threads (-1 = auto)
    int32_t n_ctx;                    // Context size
    uint8_t use_gpu;                  // Whether to use GPU (0 = no, 1 = yes)
} LlamafuModelParams;

// Context parameters (updated)
typedef struct {
    uint32_t n_ctx;                   // Context size
    uint32_t n_batch;                 // Batch size for prompt processing (>= 32)
    uint32_t n_ubatch;                // Physical batch size for computation
    uint32_t n_seq_max;               // Maximum number of sequences
    int32_t n_threads;                // Number of threads (-1 = auto)
    int32_t n_threads_batch;          // Number of threads for batch processing

    // Rope scaling
    float rope_freq_base;             // RoPE frequency base (0.0 = model default)
    float rope_freq_scale;            // RoPE frequency scale (0.0 = model default)

    // Attention and memory
    float yarn_ext_factor;            // YaRN extrapolation factor
    float yarn_attn_factor;           // YaRN attention factor
    float yarn_beta_fast;             // YaRN beta fast
    float yarn_beta_slow;             // YaRN beta slow
    uint32_t yarn_orig_ctx;           // YaRN original context size

    bool embeddings;                  // Enable embeddings mode
    bool causal_attn;                 // Enable causal attention
    bool offload_kqv;                 // Offload K, Q, V to GPU
    bool flash_attn;                  // Enable flash attention

    // Abort callback
    bool (*abort_callback)(void* data);
    void* abort_callback_data;
} LlamafuContextParams;

// Inference parameters (enhanced)
typedef struct {
    const char* prompt;
    int32_t max_tokens;

    // Basic sampling
    float temperature;
    int32_t top_k;
    float top_p;
    float min_p;
    float typical_p;

    // Penalties
    float repeat_penalty;
    int32_t repeat_last_n;
    float frequency_penalty;
    float presence_penalty;

    // Advanced sampling
    bool penalize_nl;                 // Penalize newlines
    bool ignore_eos;                  // Ignore EOS token

    // Mirostat
    int32_t mirostat;                 // 0 = disabled, 1 = v1, 2 = v2
    float mirostat_tau;               // Target entropy
    float mirostat_eta;               // Learning rate

    // Seed and determinism
    uint32_t seed;

    // Grammar (optional)
    const char* grammar_str;
    const char* grammar_root;
} LlamafuInferParams;

// Batch for efficient processing
typedef struct {
    LlamafuToken* tokens;             // Tokens to process
    int32_t n_tokens;                 // Number of tokens
    int32_t* pos;                     // Position of each token
    int32_t* seq_id;                  // Sequence ID for each token
    bool* logits;                     // Whether to output logits for each token
} LlamafuBatchParams;

// Enhanced Multi-modal types with comprehensive support
typedef enum {
    LLAMAFU_MEDIA_TYPE_TEXT = 0,
    LLAMAFU_MEDIA_TYPE_IMAGE = 1,
    LLAMAFU_MEDIA_TYPE_AUDIO = 2,
    LLAMAFU_MEDIA_TYPE_VIDEO = 3,      // Future support
} LlamafuMediaType;

// Audio format support
typedef enum {
    LLAMAFU_AUDIO_FORMAT_AUTO = 0,     // Auto-detect from data/extension
    LLAMAFU_AUDIO_FORMAT_WAV = 1,
    LLAMAFU_AUDIO_FORMAT_MP3 = 2,
    LLAMAFU_AUDIO_FORMAT_FLAC = 3,
    LLAMAFU_AUDIO_FORMAT_OGG = 4,
    LLAMAFU_AUDIO_FORMAT_AAC = 5,
    LLAMAFU_AUDIO_FORMAT_PCM_16 = 6,   // Raw 16-bit PCM
    LLAMAFU_AUDIO_FORMAT_PCM_32 = 7,   // Raw 32-bit PCM
} LlamafuAudioFormat;

// Streaming types for different media
typedef enum {
    LLAMAFU_STREAM_TYPE_TEXT_TOKENS = 0,     // Individual text tokens
    LLAMAFU_STREAM_TYPE_TEXT_CHUNKS = 1,     // Text chunks/words
    LLAMAFU_STREAM_TYPE_AUDIO_FRAMES = 2,    // Audio frame data
    LLAMAFU_STREAM_TYPE_AUDIO_SAMPLES = 3,   // Raw audio samples
    LLAMAFU_STREAM_TYPE_STRUCTURED_JSON = 4, // Structured JSON output
} LlamafuStreamType;

// Image format support
typedef enum {
    LLAMAFU_IMAGE_FORMAT_AUTO = 0,    // Auto-detect from data/extension
    LLAMAFU_IMAGE_FORMAT_JPEG = 1,
    LLAMAFU_IMAGE_FORMAT_PNG = 2,
    LLAMAFU_IMAGE_FORMAT_BMP = 3,
    LLAMAFU_IMAGE_FORMAT_WEBP = 4,
    LLAMAFU_IMAGE_FORMAT_RGB24 = 5,   // Raw RGB data
    LLAMAFU_IMAGE_FORMAT_RGBA32 = 6,  // Raw RGBA data
} LlamafuImageFormat;

// Input data source types
typedef enum {
    LLAMAFU_DATA_SOURCE_FILE_PATH = 0,      // File system path
    LLAMAFU_DATA_SOURCE_BASE64 = 1,         // Base64 encoded data
    LLAMAFU_DATA_SOURCE_BINARY = 2,         // Raw binary data
    LLAMAFU_DATA_SOURCE_URL = 3,            // HTTP/HTTPS URL (future)
    LLAMAFU_DATA_SOURCE_RGB_PIXELS = 4,     // Raw RGB pixel data
} LlamafuDataSource;

// Enhanced media input with validation and conversion support
typedef struct {
    LlamafuMediaType type;
    LlamafuDataSource source_type;

    // Data specification
    const void* data;                       // Pointer to data (path string, binary data, etc.)
    size_t data_size;                       // Size in bytes (0 for null-terminated strings)

    // Image-specific properties
    LlamafuImageFormat image_format;
    int32_t width;                          // Image width (0 = auto-detect)
    int32_t height;                         // Image height (0 = auto-detect)

    // Audio-specific properties
    LlamafuAudioFormat audio_format;
    int32_t sample_rate;                    // Audio sample rate (0 = auto-detect)
    int32_t channels;                       // Number of audio channels (0 = auto-detect)
    int32_t duration_ms;                    // Duration in milliseconds (0 = auto-detect)

    // Processing options
    bool resize_to_model;                   // Auto-resize to model requirements
    bool maintain_aspect_ratio;             // Preserve aspect ratio when resizing
    bool pad_to_square;                     // Pad image to square if needed
    bool resample_audio;                    // Auto-resample audio to model requirements

    // Metadata
    const char* caption;                    // Optional media caption/description
    float quality_hint;                     // Quality hint for processing (0.0-1.0)
    int64_t timestamp_ms;                   // Timestamp for streaming media
} LlamafuMediaInput;

// Structured output types
typedef enum {
    LLAMAFU_OUTPUT_FORMAT_TEXT = 0,         // Plain text output
    LLAMAFU_OUTPUT_FORMAT_JSON = 1,         // JSON object
    LLAMAFU_OUTPUT_FORMAT_JSON_SCHEMA = 2,  // JSON with schema validation
    LLAMAFU_OUTPUT_FORMAT_YAML = 3,         // YAML format
    LLAMAFU_OUTPUT_FORMAT_XML = 4,          // XML format
    LLAMAFU_OUTPUT_FORMAT_MARKDOWN = 5,     // Markdown format
    LLAMAFU_OUTPUT_FORMAT_CSV = 6,          // CSV format
} LlamafuOutputFormat;

// Structured output configuration
typedef struct {
    LlamafuOutputFormat format;
    const char* schema;                     // JSON schema or format specification
    bool strict_validation;                 // Enforce strict schema compliance
    bool pretty_print;                      // Format output for readability
    int32_t max_depth;                      // Maximum nesting depth
    const char* field_separator;            // For CSV/delimited formats
    const char* custom_template;            // Custom output template
} LlamafuStructuredOutput;

// Audio processing result
typedef struct {
    float* audio_features;                  // Processed audio features/embeddings
    size_t n_features;                      // Number of feature dimensions
    int32_t n_frames;                       // Number of audio frames processed

    // Processed audio properties
    int32_t processed_sample_rate;
    int32_t processed_channels;
    int32_t processed_duration_ms;
    bool was_resampled;
    bool was_normalized;

    // Performance metrics
    double processing_time_ms;
    size_t memory_used_bytes;
} LlamafuAudioProcessResult;

// Batch processing for multiple images
typedef struct {
    LlamafuMediaInput* inputs;              // Array of media inputs
    size_t n_inputs;                        // Number of inputs
    bool process_parallel;                  // Process images in parallel
    int32_t max_batch_size;                 // Maximum batch size for processing
} LlamafuMediaBatch;

// Enhanced LoRA adapter information
typedef struct {
    const char* name;                       // Adapter name/identifier
    const char* file_path;                  // Path to adapter file
    float scale;                            // Current scale factor
    bool is_active;                         // Whether adapter is currently applied
    size_t parameter_count;                 // Number of parameters in adapter
    const char* target_modules;             // Comma-separated list of target modules
    const char* description;                // Optional description
    int64_t created_timestamp;              // Creation timestamp
} LlamafuLoraAdapterInfo;

// LoRA management batch operations
typedef struct {
    LlamafuLoraAdapter* adapters;           // Array of adapter handles
    float* scales;                          // Scale for each adapter
    size_t n_adapters;                      // Number of adapters
    bool merge_adapters;                    // Merge multiple adapters
    const char* merge_strategy;             // Merging strategy ("add", "concat", "weighted")
} LlamafuLoraBatch;

// Enhanced multimodal inference parameters
typedef struct {
    const char* prompt;                     // Text prompt
    LlamafuMediaInput* media_inputs;        // Media inputs
    size_t n_media_inputs;                  // Number of media inputs

    // Generation parameters (inherited from LlamafuInferParams)
    int32_t max_tokens;
    float temperature;
    int32_t top_k;
    float top_p;
    float min_p;
    float repeat_penalty;

    // Multimodal-specific options
    bool include_image_tokens;              // Include special image tokens in output
    bool preserve_image_order;              // Maintain order of images in context
    const char* image_token_format;         // Custom format for image tokens

    // Performance options
    int32_t vision_threads;                 // Threads for vision processing (-1 = auto)
    bool use_vision_cache;                  // Cache processed image embeddings

    // Structured output options
    LlamafuStructuredOutput* structured_output; // Optional structured output configuration

    // LoRA adapter override for this inference
    LlamafuLoraBatch* lora_batch;           // Optional LoRA batch for this inference
} LlamafuMultimodalInferParams;

// Image processing result with metadata
typedef struct {
    float* embeddings;                      // Processed image embeddings
    size_t n_embeddings;                    // Number of embedding dimensions
    int32_t n_tokens;                       // Number of image tokens generated

    // Processed image properties
    int32_t processed_width;
    int32_t processed_height;
    bool was_resized;
    bool was_padded;

    // Performance metrics
    double processing_time_ms;
    size_t memory_used_bytes;
} LlamafuImageProcessResult;

// Image validation result
typedef struct {
    bool is_valid;
    LlamafuImageFormat detected_format;
    int32_t width;
    int32_t height;
    size_t file_size_bytes;

    // Validation errors
    LlamafuError error_code;
    char error_message[256];

    // Compatibility info
    bool supported_by_model;
    bool requires_preprocessing;
    float estimated_processing_time_ms;
} LlamafuImageValidation;

// Model information (comprehensive)
typedef struct {
    // Vocabulary
    int32_t n_vocab;                  // Vocabulary size
    int32_t n_ctx_train;              // Training context length
    int32_t n_embd;                   // Embedding dimensions
    int32_t n_layer;                  // Number of layers
    int32_t n_head;                   // Number of attention heads
    int32_t n_head_kv;                // Number of key-value heads

    // Model properties
    const char* name;                 // Model name
    const char* architecture;         // Architecture type
    const char* description;          // Model description
    uint64_t n_params;                // Number of parameters
    uint64_t size_bytes;              // Model size in bytes

    // Capabilities
    bool has_encoder;                 // Has encoder
    bool has_decoder;                 // Has decoder
    bool is_recurrent;                // Is recurrent model
    bool supports_embeddings;         // Supports embeddings
    bool supports_multimodal;         // Supports multimodal

    // Training info
    float rope_freq_base_train;       // Training RoPE frequency base
    float rope_freq_scale_train;      // Training RoPE frequency scale
} LlamafuModelInfo;

// Performance statistics
typedef struct {
    double t_start_ms;                // Start time
    double t_end_ms;                  // End time
    double t_load_ms;                 // Model load time
    double t_p_eval_ms;               // Prompt evaluation time
    double t_eval_ms;                 // Generation time

    int32_t n_p_eval;                 // Number of tokens in prompt
    int32_t n_eval;                   // Number of generated tokens

    // Rates
    double t_p_eval_per_token_ms;     // Prompt eval per token
    double t_eval_per_token_ms;       // Generation per token
} LlamafuPerfStats;

// Enhanced streaming callbacks
typedef void (*LlamafuStreamCallback)(const char* token, void* user_data);
typedef void (*LlamafuAudioStreamCallback)(const float* audio_data, size_t n_samples, int32_t sample_rate, void* user_data);
typedef void (*LlamafuStructuredStreamCallback)(const char* json_chunk, bool is_complete, void* user_data);

// Universal streaming callback with type information
typedef struct {
    LlamafuStreamType stream_type;
    union {
        struct {
            const char* token;
            bool is_final_token;
        } text;
        struct {
            const float* samples;
            size_t n_samples;
            int32_t sample_rate;
            bool is_final_chunk;
        } audio;
        struct {
            const char* json_chunk;
            bool is_complete;
            bool is_valid_json;
        } structured;
    } data;
    void* user_data;
} LlamafuStreamEvent;

typedef void (*LlamafuUniversalStreamCallback)(const LlamafuStreamEvent* event);

// Text processing and templating utilities
typedef struct {
    const char* template_string;            // Template with placeholders like {{variable}}
    const char** variable_names;            // Array of variable names
    const char** variable_values;           // Array of variable values
    size_t n_variables;                     // Number of variables
    bool escape_html;                       // Escape HTML characters
    bool preserve_whitespace;               // Preserve whitespace formatting
} LlamafuTextTemplate;

//
// CORE API
//

// Backend management
void llamafu_backend_init(void);
void llamafu_backend_free(void);

// Get default parameters
LlamafuModelParams llamafu_model_default_params(void);
LlamafuContextParams llamafu_context_default_params(void);

// Model loading and management
LlamafuError llamafu_model_load(const char* path, LlamafuModelParams params, Llamafu* out_model);
LlamafuError llamafu_init_context(Llamafu model, LlamafuContextParams params);
void llamafu_free(Llamafu llamafu);

// Model information
LlamafuError llamafu_get_model_info(Llamafu llamafu, LlamafuModelInfo* out_info);

//
// TOKENIZATION API
//

LlamafuError llamafu_tokenize(
    Llamafu llamafu,
    const char* text,
    int32_t text_len,
    LlamafuToken** out_tokens,
    int32_t* out_n_tokens,
    bool add_special,
    bool parse_special
);

LlamafuError llamafu_detokenize(
    Llamafu llamafu,
    const LlamafuToken* tokens,
    int32_t n_tokens,
    char** out_text,
    bool remove_special,
    bool unparse_special
);

LlamafuError llamafu_token_to_piece(
    Llamafu llamafu,
    LlamafuToken token,
    char** out_piece
);

// Special tokens
LlamafuToken llamafu_token_bos(Llamafu llamafu);
LlamafuToken llamafu_token_eos(Llamafu llamafu);
LlamafuToken llamafu_token_eot(Llamafu llamafu);
LlamafuToken llamafu_token_nl(Llamafu llamafu);

//
// SAMPLING API
//

// Create samplers
LlamafuSampler llamafu_sampler_chain_init(void);
int32_t llamafu_sampler_chain_add(LlamafuSampler chain, LlamafuSampler sampler);
void llamafu_sampler_free(LlamafuSampler sampler);

// Individual samplers
LlamafuSampler llamafu_sampler_init_greedy(void);
LlamafuSampler llamafu_sampler_init_dist(uint32_t seed);
LlamafuSampler llamafu_sampler_init_top_k(int32_t k);
LlamafuSampler llamafu_sampler_init_top_p(float p, size_t min_keep);
LlamafuSampler llamafu_sampler_init_min_p(float p, size_t min_keep);
LlamafuSampler llamafu_sampler_init_typical(float p, size_t min_keep);
LlamafuSampler llamafu_sampler_init_temp(float temp);
LlamafuSampler llamafu_sampler_init_mirostat(int32_t n_vocab, uint32_t seed, float tau, float eta, int32_t m);
LlamafuSampler llamafu_sampler_init_mirostat_v2(uint32_t seed, float tau, float eta);
LlamafuSampler llamafu_sampler_init_penalties(
    int32_t n_vocab,
    LlamafuToken eos_token,
    LlamafuToken nl_token,
    int32_t repeat_last_n,
    float repeat_penalty,
    float freq_penalty,
    float presence_penalty,
    bool penalize_nl,
    bool ignore_eos
);
LlamafuSampler llamafu_sampler_init_grammar(const char* grammar_str, const char* root);

// Sampling
LlamafuToken llamafu_sampler_sample(LlamafuSampler sampler, Llamafu llamafu, int32_t idx);
void llamafu_sampler_accept(LlamafuSampler sampler, LlamafuToken token);
void llamafu_sampler_reset(LlamafuSampler sampler);

//
// BATCH PROCESSING API
//

LlamafuBatch llamafu_batch_init(int32_t n_tokens_max, int32_t embd, int32_t n_seq_max);
void llamafu_batch_free(LlamafuBatch batch);
void llamafu_batch_clear(LlamafuBatch batch);
void llamafu_batch_add(
    LlamafuBatch batch,
    LlamafuToken token,
    int32_t pos,
    const int32_t* seq_ids,
    size_t n_seq_ids,
    bool logits
);

// Inference
LlamafuError llamafu_decode(Llamafu llamafu, LlamafuBatch batch);
LlamafuError llamafu_encode(Llamafu llamafu, LlamafuBatch batch);

//
// ENHANCED MULTIMODAL API
//

// Image processing and validation utilities
LlamafuError llamafu_image_validate(
    const LlamafuMediaInput* input,
    LlamafuImageValidation* out_validation
);

LlamafuError llamafu_image_load_from_file(
    const char* file_path,
    LlamafuImageFormat format,
    LlamafuMediaInput* out_input
);

LlamafuError llamafu_image_load_from_base64(
    const char* base64_data,
    LlamafuImageFormat format,
    LlamafuMediaInput* out_input
);

LlamafuError llamafu_image_load_from_pixels(
    const unsigned char* rgb_pixels,
    int32_t width,
    int32_t height,
    LlamafuImageFormat format,
    LlamafuMediaInput* out_input
);

// Convenience functions for common formats
LlamafuError llamafu_image_from_jpeg_file(const char* path, LlamafuMediaInput* out_input);
LlamafuError llamafu_image_from_png_file(const char* path, LlamafuMediaInput* out_input);
LlamafuError llamafu_image_from_base64_jpeg(const char* base64, LlamafuMediaInput* out_input);
LlamafuError llamafu_image_from_base64_png(const char* base64, LlamafuMediaInput* out_input);

// Format conversion utilities
LlamafuError llamafu_image_convert_format(
    const LlamafuMediaInput* input,
    LlamafuImageFormat target_format,
    LlamafuMediaInput* out_converted
);

LlamafuError llamafu_image_resize(
    const LlamafuMediaInput* input,
    int32_t target_width,
    int32_t target_height,
    bool maintain_aspect_ratio,
    LlamafuMediaInput* out_resized
);

LlamafuError llamafu_image_to_base64(
    const LlamafuMediaInput* input,
    LlamafuImageFormat format,
    char** out_base64
);

// Image processing and encoding
LlamafuError llamafu_image_process(
    Llamafu llamafu,
    const LlamafuMediaInput* input,
    LlamafuImageProcessResult* out_result
);

LlamafuError llamafu_image_batch_process(
    Llamafu llamafu,
    const LlamafuMediaBatch* batch,
    LlamafuImageProcessResult** out_results,
    size_t* out_n_results
);

// Enhanced multimodal completion with comprehensive support
LlamafuError llamafu_multimodal_complete_enhanced(
    Llamafu llamafu,
    LlamafuMultimodalInferParams* params,
    char** out_result
);

LlamafuError llamafu_multimodal_complete_streaming(
    Llamafu llamafu,
    LlamafuMultimodalInferParams* params,
    LlamafuStreamCallback callback,
    void* user_data
);

// Convenience functions for common use cases
LlamafuError llamafu_chat_with_image_file(
    Llamafu llamafu,
    const char* prompt,
    const char* image_path,
    int32_t max_tokens,
    char** out_result
);

LlamafuError llamafu_chat_with_image_base64(
    Llamafu llamafu,
    const char* prompt,
    const char* image_base64,
    int32_t max_tokens,
    char** out_result
);

LlamafuError llamafu_chat_with_multiple_images(
    Llamafu llamafu,
    const char* prompt,
    const char** image_paths,
    size_t n_images,
    int32_t max_tokens,
    char** out_result
);

// Image metadata and utility functions
LlamafuError llamafu_get_image_requirements(
    Llamafu llamafu,
    int32_t* out_max_width,
    int32_t* out_max_height,
    int32_t* out_preferred_size,
    bool* out_requires_square
);

LlamafuError llamafu_get_supported_formats(
    LlamafuImageFormat** out_formats,
    size_t* out_n_formats
);

const char* llamafu_image_format_to_string(LlamafuImageFormat format);
LlamafuImageFormat llamafu_image_format_from_string(const char* format_str);
LlamafuImageFormat llamafu_image_detect_format_from_data(const void* data, size_t size);
LlamafuImageFormat llamafu_image_detect_format_from_path(const char* file_path);

// Memory management for multimodal resources
void llamafu_media_input_free(LlamafuMediaInput* input);
void llamafu_media_batch_free(LlamafuMediaBatch* batch);
void llamafu_image_process_result_free(LlamafuImageProcessResult* result);
void llamafu_image_validation_free(LlamafuImageValidation* validation);

//
// TEXT GENERATION API (Legacy/Simple)
//

LlamafuError llamafu_complete(
    Llamafu llamafu,
    LlamafuInferParams* params,
    char** out_result
);

LlamafuError llamafu_complete_stream(
    Llamafu llamafu,
    LlamafuInferParams* params,
    LlamafuStreamCallback callback,
    void* user_data
);

LlamafuError llamafu_multimodal_complete(
    Llamafu llamafu,
    LlamafuMultimodalInferParams* params,
    char** out_result
);

//
// EMBEDDINGS API
//

LlamafuError llamafu_get_embeddings(
    Llamafu llamafu,
    const char* text,
    float** out_embeddings,
    int32_t* out_n_embd
);

LlamafuError llamafu_get_embeddings_batch(
    Llamafu llamafu,
    LlamafuBatch* batch,
    float** out_embeddings,
    int32_t* out_n_embd
);

//
// COMPREHENSIVE AUDIO API
//

// Audio processing and validation utilities
LlamafuError llamafu_audio_validate(
    const LlamafuMediaInput* input,
    LlamafuImageValidation* out_validation  // Reusing validation structure
);

LlamafuError llamafu_audio_load_from_file(
    const char* file_path,
    LlamafuAudioFormat format,
    LlamafuMediaInput* out_input
);

LlamafuError llamafu_audio_load_from_samples(
    const float* samples,
    size_t n_samples,
    int32_t sample_rate,
    int32_t channels,
    LlamafuMediaInput* out_input
);

LlamafuError llamafu_audio_process(
    Llamafu llamafu,
    const LlamafuMediaInput* input,
    LlamafuAudioProcessResult* out_result
);

// Audio streaming functions
LlamafuError llamafu_audio_stream_start(
    Llamafu llamafu,
    const LlamafuMediaInput* input,
    LlamafuAudioStreamCallback callback,
    void* user_data
);

LlamafuError llamafu_audio_stream_push(
    Llamafu llamafu,
    const float* samples,
    size_t n_samples,
    bool is_final_chunk
);

LlamafuError llamafu_audio_stream_stop(Llamafu llamafu);

// Audio format conversion
LlamafuError llamafu_audio_convert_format(
    const LlamafuMediaInput* input,
    LlamafuAudioFormat target_format,
    int32_t target_sample_rate,
    LlamafuMediaInput* out_converted
);

LlamafuError llamafu_audio_resample(
    const float* input_samples,
    size_t n_input_samples,
    int32_t input_rate,
    int32_t target_rate,
    float** out_samples,
    size_t* out_n_samples
);

// Audio utility functions
const char* llamafu_audio_format_to_string(LlamafuAudioFormat format);
LlamafuAudioFormat llamafu_audio_format_from_string(const char* format_str);
LlamafuAudioFormat llamafu_audio_detect_format_from_data(const void* data, size_t size);
LlamafuAudioFormat llamafu_audio_detect_format_from_path(const char* file_path);

//
// STRUCTURED OUTPUT AND VALIDATION API
//

// JSON schema validation and structured output
LlamafuError llamafu_generate_structured(
    Llamafu llamafu,
    const char* prompt,
    const LlamafuStructuredOutput* output_config,
    char** out_result
);

LlamafuError llamafu_generate_structured_streaming(
    Llamafu llamafu,
    const char* prompt,
    const LlamafuStructuredOutput* output_config,
    LlamafuStructuredStreamCallback callback,
    void* user_data
);

LlamafuError llamafu_validate_json_schema(
    const char* json_string,
    const char* schema,
    bool* out_is_valid,
    char** out_error_message
);

LlamafuError llamafu_format_output(
    const char* content,
    LlamafuOutputFormat format,
    const char* template_or_schema,
    char** out_formatted
);

// Template processing
LlamafuError llamafu_process_template(
    const LlamafuTextTemplate* template_config,
    char** out_result
);

LlamafuError llamafu_create_template(
    const char* template_string,
    const char** variable_names,
    const char** variable_values,
    size_t n_variables,
    LlamafuTextTemplate* out_template
);

//
// ENHANCED LORA ADAPTER API
//

// Basic LoRA operations (existing)
LlamafuError llamafu_load_lora_adapter_from_file(
    Llamafu llamafu,
    const char* lora_path,
    float scale,
    LlamafuLoraAdapter* out_adapter
);

LlamafuError llamafu_set_lora_adapter(
    Llamafu llamafu,
    LlamafuLoraAdapter adapter,
    float scale
);

LlamafuError llamafu_unload_lora_adapter(
    Llamafu llamafu,
    LlamafuLoraAdapter adapter
);

void llamafu_clear_lora_adapters(Llamafu llamafu);

// Enhanced LoRA management
LlamafuError llamafu_load_lora_adapter_with_info(
    Llamafu llamafu,
    const char* lora_path,
    const char* name,
    const char* description,
    float scale,
    LlamafuLoraAdapter* out_adapter
);

LlamafuError llamafu_get_lora_adapter_info(
    Llamafu llamafu,
    LlamafuLoraAdapter adapter,
    LlamafuLoraAdapterInfo* out_info
);

LlamafuError llamafu_list_lora_adapters(
    Llamafu llamafu,
    LlamafuLoraAdapterInfo** out_adapters,
    size_t* out_n_adapters
);

LlamafuError llamafu_apply_lora_batch(
    Llamafu llamafu,
    const LlamafuLoraBatch* batch
);

LlamafuError llamafu_save_lora_adapter_config(
    Llamafu llamafu,
    const char* config_path
);

LlamafuError llamafu_load_lora_adapter_config(
    Llamafu llamafu,
    const char* config_path
);

// LoRA utility functions
LlamafuError llamafu_merge_lora_adapters(
    Llamafu llamafu,
    const LlamafuLoraAdapter* adapters,
    const float* weights,
    size_t n_adapters,
    const char* output_path
);

LlamafuError llamafu_validate_lora_compatibility(
    Llamafu llamafu,
    const char* lora_path,
    bool* out_is_compatible,
    char** out_error_message
);

//
// CONTEXT AND MEMORY MANAGEMENT
//

void llamafu_kv_cache_clear(Llamafu llamafu);
void llamafu_kv_cache_seq_rm(Llamafu llamafu, int32_t seq_id, int32_t p0, int32_t p1);
void llamafu_kv_cache_seq_cp(Llamafu llamafu, int32_t seq_id_src, int32_t seq_id_dst, int32_t p0, int32_t p1);
void llamafu_kv_cache_seq_keep(Llamafu llamafu, int32_t seq_id);
void llamafu_kv_cache_seq_add(Llamafu llamafu, int32_t seq_id, int32_t p0, int32_t p1, int32_t delta);
void llamafu_kv_cache_seq_div(Llamafu llamafu, int32_t seq_id, int32_t p0, int32_t p1, int32_t d);

// State management
size_t llamafu_state_get_size(Llamafu llamafu);
size_t llamafu_state_get_data(Llamafu llamafu, void* dst);
size_t llamafu_state_set_data(Llamafu llamafu, const void* src);
LlamafuError llamafu_state_save_file(Llamafu llamafu, const char* path);
LlamafuError llamafu_state_load_file(Llamafu llamafu, const char* path);

//
// PERFORMANCE AND THREADING
//

// (Removed duplicate - see performance section below)
LlamafuError llamafu_get_perf_stats(Llamafu llamafu, LlamafuPerfStats* out_stats);
void llamafu_reset_perf_stats(Llamafu llamafu);

//
// LOGITS AND OUTPUT ACCESS
//

float* llamafu_get_logits(Llamafu llamafu);
float* llamafu_get_logits_ith(Llamafu llamafu, int32_t i);

//
// UNIVERSAL STREAMING API
//

// Universal streaming for all media types
LlamafuError llamafu_stream_universal_start(
    Llamafu llamafu,
    const char* prompt,
    const LlamafuMediaInput* media_inputs,
    size_t n_media_inputs,
    LlamafuStreamType stream_type,
    LlamafuUniversalStreamCallback callback,
    void* user_data
);

LlamafuError llamafu_stream_universal_push_media(
    Llamafu llamafu,
    const LlamafuMediaInput* input
);

LlamafuError llamafu_stream_universal_stop(Llamafu llamafu);

// Streaming configuration
LlamafuError llamafu_stream_set_buffer_size(
    Llamafu llamafu,
    size_t buffer_size_bytes
);

LlamafuError llamafu_stream_set_chunk_size(
    Llamafu llamafu,
    size_t chunk_size
);

//
// ADVANCED TEXT PROCESSING HELPERS
//

// Text preprocessing and formatting
LlamafuError llamafu_text_preprocess(
    const char* input_text,
    bool normalize_whitespace,
    bool remove_markdown,
    bool escape_special_chars,
    char** out_processed
);

LlamafuError llamafu_text_tokenize_words(
    const char* text,
    char*** out_words,
    size_t* out_n_words
);

LlamafuError llamafu_text_extract_entities(
    Llamafu llamafu,
    const char* text,
    const char* entity_types,  // "person,location,organization"
    char** out_entities_json
);

LlamafuError llamafu_text_summarize(
    Llamafu llamafu,
    const char* text,
    int32_t max_summary_length,
    const char* style,  // "brief", "detailed", "bullet_points"
    char** out_summary
);

// Chat utilities with conversation management
LlamafuError llamafu_chat_session_create(
    Llamafu llamafu,
    const char* system_prompt,
    void** out_session
);

LlamafuError llamafu_chat_session_add_message(
    void* session,
    const char* role,  // "user", "assistant", "system"
    const char* content,
    const LlamafuMediaInput* media_inputs,
    size_t n_media_inputs
);

LlamafuError llamafu_chat_session_complete(
    void* session,
    const char* user_message,
    const LlamafuMediaInput* media_inputs,
    size_t n_media_inputs,
    char** out_response
);

LlamafuError llamafu_chat_session_get_history(
    void* session,
    char** out_history_json
);

void llamafu_chat_session_free(void* session);

// Language detection and translation helpers
LlamafuError llamafu_detect_language(
    Llamafu llamafu,
    const char* text,
    char** out_language_code,
    float* out_confidence
);

LlamafuError llamafu_translate_text(
    Llamafu llamafu,
    const char* text,
    const char* source_language,
    const char* target_language,
    char** out_translated
);

// Content analysis and classification
LlamafuError llamafu_analyze_sentiment(
    Llamafu llamafu,
    const char* text,
    float* out_positive_score,
    float* out_negative_score,
    float* out_neutral_score
);

LlamafuError llamafu_classify_content(
    Llamafu llamafu,
    const char* text,
    const char** categories,
    size_t n_categories,
    float** out_scores,
    char** out_best_category
);

LlamafuError llamafu_extract_keywords(
    Llamafu llamafu,
    const char* text,
    int32_t max_keywords,
    char** out_keywords_json
);

//
// UTILITY FUNCTIONS
//

void llamafu_free_string(char* str);
void llamafu_free_tokens(LlamafuToken* tokens);
void llamafu_free_embeddings(float* embeddings);
const char* llamafu_print_system_info(void);

// Chat template support
LlamafuError llamafu_chat_apply_template(
    Llamafu llamafu,
    const char* tmpl,
    const char** messages,
    size_t n_messages,
    bool add_ass,
    char** out_formatted
);

// Additional performance and threading types
typedef struct {
    double t_start_ms;                // Start time
    double t_end_ms;                  // End time  
    double t_load_ms;                 // Model load time
    double t_sample_ms;               // Sampling time
    double t_p_eval_ms;               // Prompt evaluation time
    double t_eval_ms;                 // Generation time
    
    int32_t n_sample;                 // Number of samples
    int32_t n_p_eval;                 // Number of tokens in prompt
    int32_t n_eval;                   // Number of generated tokens
} LlamafuTimings;

typedef struct {
    char system_info[1024];           // System information string
    int32_t n_cpu_physical;           // Physical CPU cores
    int32_t n_cpu_logical;            // Logical CPU cores
} LlamafuSystemInfo;

typedef struct {
    int32_t prompt_tokens;            // Number of prompt tokens
    float prompt_time_ms;             // Prompt processing time
    int32_t generation_tokens;        // Number of generated tokens
    float generation_time_ms;         // Generation time
    float total_time_ms;              // Total time
    float prompt_speed_tps;           // Prompt tokens per second
    float generation_speed_tps;       // Generation tokens per second
} LlamafuBenchResult;

typedef struct {
    uint64_t model_size_bytes;        // Model size in memory
    uint64_t kv_cache_size_bytes;     // KV cache size
    uint64_t compute_buffer_size_bytes; // Compute buffer size
    uint64_t total_size_bytes;        // Total memory usage
} LlamafuMemoryUsage;

typedef enum {
    LLAMAFU_LOG_DEBUG = 0,
    LLAMAFU_LOG_INFO = 1, 
    LLAMAFU_LOG_WARN = 2,
    LLAMAFU_LOG_ERROR = 3
} LlamafuLogLevel;

// Callback types
typedef bool (*LlamafuAbortCallback)(void* user_data);
typedef void (*LlamafuLogCallback)(LlamafuLogLevel level, const char* text, void* user_data);

//
// TOOL CALLING TYPES
//

// Tool choice behavior
typedef enum {
    LLAMAFU_TOOL_CHOICE_AUTO = 0,      // Model decides whether to call tools
    LLAMAFU_TOOL_CHOICE_NONE = 1,      // Never call tools
    LLAMAFU_TOOL_CHOICE_REQUIRED = 2,  // Must call at least one tool
    LLAMAFU_TOOL_CHOICE_SPECIFIC = 3,  // Call specific tool by name
} LlamafuToolChoiceType;

// Tool definition
typedef struct {
    const char* name;                   // Tool name (e.g., "get_weather")
    const char* description;            // Tool description
    const char* parameters_schema;      // JSON Schema for parameters
} LlamafuTool;

// Tool call result
typedef struct {
    char* id;                           // Unique call ID
    char* name;                         // Tool name that was called
    char* arguments_json;               // JSON string of arguments
} LlamafuToolCall;

// Tool choice configuration
typedef struct {
    LlamafuToolChoiceType type;
    const char* tool_name;              // For SPECIFIC type
} LlamafuToolChoice;

// Tool calling parameters
typedef struct {
    const char* prompt;                 // User prompt
    const LlamafuTool* tools;           // Available tools
    size_t n_tools;                     // Number of tools
    LlamafuToolChoice tool_choice;      // Tool choice behavior

    // Generation parameters
    int32_t max_tokens;
    float temperature;
    uint32_t seed;

    // Output control
    bool allow_multiple_calls;          // Allow multiple tool calls
    int32_t max_calls;                  // Maximum tool calls (0 = unlimited)
} LlamafuToolCallParams;

// JSON generation parameters
typedef struct {
    const char* prompt;                 // User prompt
    const char* schema;                 // JSON Schema string

    // Generation parameters
    int32_t max_tokens;
    float temperature;
    uint32_t seed;
} LlamafuJsonParams;

// Extended performance and threading API
LlamafuError llamafu_set_n_threads(Llamafu llamafu, int32_t n_threads, int32_t n_threads_batch);
LlamafuError llamafu_get_n_threads(Llamafu llamafu, int32_t* out_n_threads, int32_t* out_n_threads_batch);
LlamafuError llamafu_warmup(Llamafu llamafu);
LlamafuError llamafu_get_timings(Llamafu llamafu, LlamafuTimings* out_timings);
void llamafu_reset_timings(Llamafu llamafu);
void llamafu_print_timings(Llamafu llamafu);
LlamafuError llamafu_get_system_info(LlamafuSystemInfo* out_info);
LlamafuError llamafu_bench_model(Llamafu llamafu, int32_t n_threads, int32_t n_predict, LlamafuBenchResult* out_result);
LlamafuError llamafu_set_abort_callback(Llamafu llamafu, LlamafuAbortCallback callback, void* user_data);
LlamafuError llamafu_set_log_callback(LlamafuLogCallback callback, void* user_data);
LlamafuError llamafu_get_memory_usage(Llamafu llamafu, LlamafuMemoryUsage* out_usage);

//
// TOOL CALLING API
//

// Generate tool call from prompt
LlamafuError llamafu_generate_tool_call(
    Llamafu llamafu,
    const LlamafuToolCallParams* params,
    LlamafuToolCall** out_calls,
    size_t* out_n_calls
);

// Generate tool call with streaming
LlamafuError llamafu_generate_tool_call_streaming(
    Llamafu llamafu,
    const LlamafuToolCallParams* params,
    LlamafuStreamCallback callback,
    void* user_data,
    LlamafuToolCall** out_calls,
    size_t* out_n_calls
);

// Free tool call results
void llamafu_free_tool_calls(LlamafuToolCall* calls, size_t n_calls);

// Convert JSON Schema to GBNF grammar
LlamafuError llamafu_schema_to_grammar(
    const char* json_schema,
    char** out_grammar
);

// Build tool calling grammar from tools
LlamafuError llamafu_build_tool_grammar(
    const LlamafuTool* tools,
    size_t n_tools,
    bool allow_multiple,
    char** out_grammar
);

//
// JSON OUTPUT API
//

// Generate JSON matching schema
LlamafuError llamafu_generate_json(
    Llamafu llamafu,
    const LlamafuJsonParams* params,
    char** out_json
);

// Generate JSON with streaming
LlamafuError llamafu_generate_json_streaming(
    Llamafu llamafu,
    const LlamafuJsonParams* params,
    LlamafuStreamCallback callback,
    void* user_data
);

// Validate JSON against schema
LlamafuError llamafu_json_validate(
    const char* json_string,
    const char* schema,
    bool* out_valid,
    char** out_error
);


#ifdef __cplusplus
}
#endif

#endif // LLAMAFU_H
