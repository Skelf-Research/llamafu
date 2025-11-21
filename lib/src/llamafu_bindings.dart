import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Opaque handle to the Llamafu instance.
typedef Llamafu = Pointer<Void>;

/// Opaque handle to the LoRA adapter.
typedef LlamafuLoraAdapter = Pointer<Void>;

/// Opaque handle to the grammar sampler.
typedef LlamafuGrammarSampler = Pointer<Void>;

/// Opaque handle to a sampler.
typedef LlamafuSamplerHandle = Pointer<Void>;

/// Opaque handle to a batch.
typedef LlamafuBatchHandle = Pointer<Void>;

/// Opaque handle to a chat session.
typedef LlamafuChatSession = Pointer<Void>;

/// Token type.
typedef LlamafuToken = Int32;

/// Error code type returned by native functions.
typedef LlamafuError = Int32;

/// Operation completed successfully.
const int LLAMAFU_SUCCESS = 0;

/// An unknown error occurred.
const int LLAMAFU_ERROR_UNKNOWN = -1;

/// An invalid parameter was provided.
const int LLAMAFU_ERROR_INVALID_PARAM = -2;

/// Failed to load the model.
const int LLAMAFU_ERROR_MODEL_LOAD_FAILED = -3;

/// Out of memory error.
const int LLAMAFU_ERROR_OUT_OF_MEMORY = -4;

/// Multi-modal processing is not supported.
const int LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED = -5;

/// Failed to load the LoRA adapter.
const int LLAMAFU_ERROR_LORA_LOAD_FAILED = -6;

/// The specified LoRA adapter was not found.
const int LLAMAFU_ERROR_LORA_NOT_FOUND = -7;

/// Failed to initialize the grammar sampler.
const int LLAMAFU_ERROR_GRAMMAR_INIT_FAILED = -8;

/// Model parameters for initializing the Llamafu library.
final class LlamafuModelParams extends Struct {
  /// Path to the GGUF model file.
  external Pointer<Utf8> model_path;
  
  /// Path to the multi-modal projector file (optional).
  external Pointer<Utf8> mmproj_path;
  
  /// Number of threads to use for inference.
  @Int32()
  external int n_threads;
  
  /// Context size for the model.
  @Int32()
  external int n_ctx;
  
  /// Whether to use GPU for multi-modal processing.
  @Uint8()
  external int use_gpu;
}

/// Inference parameters structure
final class LlamafuInferParams extends Struct {
  external Pointer<Utf8> prompt;
  
  @Int32()
  external int max_tokens;
  
  @Float()
  external double temperature;
}

/// Constrained generation parameters structure
final class LlamafuGrammarParams extends Struct {
  external Pointer<Utf8> grammar_str;
  external Pointer<Utf8> grammar_root;
}

/// Multi-modal input types
class LlamafuMediaType {
  static const int TEXT = 0;
  static const int IMAGE = 1;
  static const int AUDIO = 2;
}

/// Multi-modal input data
final class LlamafuMediaInput extends Struct {
  @Int32()
  external int type;
  external Pointer<Utf8> data;
  
  @IntPtr()
  external int data_size;
}

/// Multi-modal inference parameters
final class LlamafuMultimodalInferParams extends Struct {
  external Pointer<Utf8> prompt;
  external Pointer<LlamafuMediaInput> media_inputs;

  @IntPtr()
  external int n_media_inputs;

  @Int32()
  external int max_tokens;

  @Float()
  external double temperature;
}

/// Model information structure
final class LlamafuModelInfoStruct extends Struct {
  @Int32()
  external int n_vocab;

  @Int32()
  external int n_ctx_train;

  @Int32()
  external int n_embd;

  @Int32()
  external int n_layer;

  @Int32()
  external int n_head;

  @Int32()
  external int n_head_kv;

  external Pointer<Utf8> name;
  external Pointer<Utf8> architecture;
  external Pointer<Utf8> description;

  @Uint64()
  external int n_params;

  @Uint64()
  external int size_bytes;

  @Bool()
  external bool has_encoder;

  @Bool()
  external bool has_decoder;

  @Bool()
  external bool is_recurrent;

  @Bool()
  external bool supports_embeddings;

  @Bool()
  external bool supports_multimodal;

  @Float()
  external double rope_freq_base_train;

  @Float()
  external double rope_freq_scale_train;
}

/// Performance statistics structure
final class LlamafuPerfStatsStruct extends Struct {
  @Double()
  external double t_start_ms;

  @Double()
  external double t_end_ms;

  @Double()
  external double t_load_ms;

  @Double()
  external double t_p_eval_ms;

  @Double()
  external double t_eval_ms;

  @Int32()
  external int n_p_eval;

  @Int32()
  external int n_eval;

  @Double()
  external double t_p_eval_per_token_ms;

  @Double()
  external double t_eval_per_token_ms;
}

/// Timings structure
final class LlamafuTimingsStruct extends Struct {
  @Double()
  external double t_start_ms;

  @Double()
  external double t_end_ms;

  @Double()
  external double t_load_ms;

  @Double()
  external double t_sample_ms;

  @Double()
  external double t_p_eval_ms;

  @Double()
  external double t_eval_ms;

  @Int32()
  external int n_sample;

  @Int32()
  external int n_p_eval;

  @Int32()
  external int n_eval;
}

/// Memory usage structure
final class LlamafuMemoryUsageStruct extends Struct {
  @Uint64()
  external int model_size_bytes;

  @Uint64()
  external int kv_cache_size_bytes;

  @Uint64()
  external int compute_buffer_size_bytes;

  @Uint64()
  external int total_size_bytes;
}

/// Benchmark result structure
final class LlamafuBenchResultStruct extends Struct {
  @Int32()
  external int prompt_tokens;

  @Float()
  external double prompt_time_ms;

  @Int32()
  external int generation_tokens;

  @Float()
  external double generation_time_ms;

  @Float()
  external double total_time_ms;

  @Float()
  external double prompt_speed_tps;

  @Float()
  external double generation_speed_tps;
}

/// Structured output configuration
final class LlamafuStructuredOutputStruct extends Struct {
  @Int32()
  external int format;

  external Pointer<Utf8> schema;

  @Bool()
  external bool strict_validation;

  @Bool()
  external bool pretty_print;

  @Int32()
  external int max_depth;

  external Pointer<Utf8> field_separator;
  external Pointer<Utf8> custom_template;
}

/// Image validation result
final class LlamafuImageValidationStruct extends Struct {
  @Bool()
  external bool is_valid;

  @Int32()
  external int detected_format;

  @Int32()
  external int width;

  @Int32()
  external int height;

  @IntPtr()
  external int file_size_bytes;

  @Int32()
  external int error_code;

  @Array(256)
  external Array<Uint8> error_message;

  @Bool()
  external bool supported_by_model;

  @Bool()
  external bool requires_preprocessing;

  @Float()
  external double estimated_processing_time_ms;
}

/// Image process result
final class LlamafuImageProcessResultStruct extends Struct {
  external Pointer<Float> embeddings;

  @IntPtr()
  external int n_embeddings;

  @Int32()
  external int n_tokens;

  @Int32()
  external int processed_width;

  @Int32()
  external int processed_height;

  @Bool()
  external bool was_resized;

  @Bool()
  external bool was_padded;

  @Double()
  external double processing_time_ms;

  @IntPtr()
  external int memory_used_bytes;
}

/// Audio process result
final class LlamafuAudioProcessResultStruct extends Struct {
  external Pointer<Float> audio_features;

  @IntPtr()
  external int n_features;

  @Int32()
  external int n_frames;

  @Int32()
  external int processed_sample_rate;

  @Int32()
  external int processed_channels;

  @Int32()
  external int processed_duration_ms;

  @Bool()
  external bool was_resampled;

  @Bool()
  external bool was_normalized;

  @Double()
  external double processing_time_ms;

  @IntPtr()
  external int memory_used_bytes;
}

/// LoRA adapter info
final class LlamafuLoraAdapterInfoStruct extends Struct {
  external Pointer<Utf8> name;
  external Pointer<Utf8> file_path;

  @Float()
  external double scale;

  @Bool()
  external bool is_active;

  @IntPtr()
  external int parameter_count;

  external Pointer<Utf8> target_modules;
  external Pointer<Utf8> description;

  @Int64()
  external int created_timestamp;
}

/// Tool definition for tool calling API
final class LlamafuToolStruct extends Struct {
  external Pointer<Utf8> name;
  external Pointer<Utf8> description;
  external Pointer<Utf8> parameters_schema;
}

/// Tool call result
final class LlamafuToolCallStruct extends Struct {
  external Pointer<Utf8> id;
  external Pointer<Utf8> name;
  external Pointer<Utf8> arguments_json;
}

/// Tool choice configuration
final class LlamafuToolChoiceStruct extends Struct {
  @Int32()
  external int type;
  external Pointer<Utf8> tool_name;
}

/// Tool calling parameters
final class LlamafuToolCallParamsStruct extends Struct {
  external Pointer<Utf8> prompt;
  external Pointer<LlamafuToolStruct> tools;

  @IntPtr()
  external int n_tools;

  @Int32()
  external int tool_choice_type;
  external Pointer<Utf8> tool_choice_name;

  @Int32()
  external int max_tokens;

  @Float()
  external double temperature;

  @Uint32()
  external int seed;

  @Bool()
  external bool allow_multiple_calls;

  @Int32()
  external int max_calls;
}

/// JSON generation parameters
final class LlamafuJsonParamsStruct extends Struct {
  external Pointer<Utf8> prompt;
  external Pointer<Utf8> schema;

  @Int32()
  external int max_tokens;

  @Float()
  external double temperature;

  @Uint32()
  external int seed;
}

// Callback for streaming output
typedef LlamafuStreamCallbackC = Void Function(
    Pointer<Utf8> token, Pointer<Void> user_data);
typedef LlamafuStreamCallbackDart = void Function(
    Pointer<Utf8> token, Pointer<Void> user_data);

// Native function signatures
typedef LlamafuInitC = LlamafuError Function(
    Pointer<LlamafuModelParams> params, Pointer<Llamafu> out_llamafu);
typedef LlamafuInitDart = int Function(
    Pointer<LlamafuModelParams> params, Pointer<Llamafu> out_llamafu);

typedef LlamafuCompleteC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuInferParams> params, Pointer<Pointer<Utf8>> out_result);
typedef LlamafuCompleteDart = int Function(
    Llamafu llamafu, Pointer<LlamafuInferParams> params, Pointer<Pointer<Utf8>> out_result);

typedef LlamafuCompleteWithGrammarC = LlamafuError Function(
    Llamafu llamafu, 
    Pointer<LlamafuInferParams> params, 
    Pointer<LlamafuGrammarParams> grammar_params, 
    Pointer<Pointer<Utf8>> out_result);
typedef LlamafuCompleteWithGrammarDart = int Function(
    Llamafu llamafu, 
    Pointer<LlamafuInferParams> params, 
    Pointer<LlamafuGrammarParams> grammar_params, 
    Pointer<Pointer<Utf8>> out_result);

typedef LlamafuCompleteStreamC = LlamafuError Function(
    Llamafu llamafu,
    Pointer<LlamafuInferParams> params,
    Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
    Pointer<Void> user_data);
typedef LlamafuCompleteStreamDart = int Function(
    Llamafu llamafu,
    Pointer<LlamafuInferParams> params,
    Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
    Pointer<Void> user_data);

typedef LlamafuCompleteWithGrammarStreamC = LlamafuError Function(
    Llamafu llamafu,
    Pointer<LlamafuInferParams> params,
    Pointer<LlamafuGrammarParams> grammar_params,
    Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
    Pointer<Void> user_data);
typedef LlamafuCompleteWithGrammarStreamDart = int Function(
    Llamafu llamafu,
    Pointer<LlamafuInferParams> params,
    Pointer<LlamafuGrammarParams> grammar_params,
    Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
    Pointer<Void> user_data);

typedef LlamafuMultimodalCompleteC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuMultimodalInferParams> params, Pointer<Pointer<Utf8>> out_result);
typedef LlamafuMultimodalCompleteDart = int Function(
    Llamafu llamafu, Pointer<LlamafuMultimodalInferParams> params, Pointer<Pointer<Utf8>> out_result);

typedef LlamafuMultimodalCompleteStreamC = LlamafuError Function(
    Llamafu llamafu,
    Pointer<LlamafuMultimodalInferParams> params,
    Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
    Pointer<Void> user_data);
typedef LlamafuMultimodalCompleteStreamDart = int Function(
    Llamafu llamafu,
    Pointer<LlamafuMultimodalInferParams> params,
    Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
    Pointer<Void> user_data);

// LoRA adapter functions
typedef LlamafuLoraAdapterInitC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> lora_path, Pointer<LlamafuLoraAdapter> out_adapter);
typedef LlamafuLoraAdapterInitDart = int Function(
    Llamafu llamafu, Pointer<Utf8> lora_path, Pointer<LlamafuLoraAdapter> out_adapter);

typedef LlamafuLoraAdapterApplyC = LlamafuError Function(
    Llamafu llamafu, LlamafuLoraAdapter adapter, Float scale);
typedef LlamafuLoraAdapterApplyDart = int Function(
    Llamafu llamafu, LlamafuLoraAdapter adapter, double scale);

typedef LlamafuLoraAdapterRemoveC = LlamafuError Function(
    Llamafu llamafu, LlamafuLoraAdapter adapter);
typedef LlamafuLoraAdapterRemoveDart = int Function(
    Llamafu llamafu, LlamafuLoraAdapter adapter);

typedef LlamafuLoraAdapterClearAllC = LlamafuError Function(Llamafu llamafu);
typedef LlamafuLoraAdapterClearAllDart = int Function(Llamafu llamafu);

typedef LlamafuLoraAdapterFreeC = Void Function(LlamafuLoraAdapter adapter);
typedef LlamafuLoraAdapterFreeDart = void Function(LlamafuLoraAdapter adapter);

// Grammar sampler functions
typedef LlamafuGrammarSamplerInitC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> grammar_str, Pointer<Utf8> grammar_root, Pointer<LlamafuGrammarSampler> out_sampler);
typedef LlamafuGrammarSamplerInitDart = int Function(
    Llamafu llamafu, Pointer<Utf8> grammar_str, Pointer<Utf8> grammar_root, Pointer<LlamafuGrammarSampler> out_sampler);

typedef LlamafuGrammarSamplerFreeC = Void Function(LlamafuGrammarSampler sampler);
typedef LlamafuGrammarSamplerFreeDart = void Function(LlamafuGrammarSampler sampler);

typedef LlamafuFreeC = Void Function(Llamafu llamafu);
typedef LlamafuFreeDart = void Function(Llamafu llamafu);

// Tokenization functions
typedef LlamafuTokenizeC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> text, Int32 text_len,
    Pointer<Pointer<Int32>> out_tokens, Pointer<Int32> out_n_tokens,
    Bool add_special, Bool parse_special);
typedef LlamafuTokenizeDart = int Function(
    Llamafu llamafu, Pointer<Utf8> text, int text_len,
    Pointer<Pointer<Int32>> out_tokens, Pointer<Int32> out_n_tokens,
    bool add_special, bool parse_special);

typedef LlamafuDetokenizeC = LlamafuError Function(
    Llamafu llamafu, Pointer<Int32> tokens, Int32 n_tokens,
    Pointer<Pointer<Utf8>> out_text, Bool remove_special, Bool unparse_special);
typedef LlamafuDetokenizeDart = int Function(
    Llamafu llamafu, Pointer<Int32> tokens, int n_tokens,
    Pointer<Pointer<Utf8>> out_text, bool remove_special, bool unparse_special);

typedef LlamafuTokenToPieceC = LlamafuError Function(
    Llamafu llamafu, Int32 token, Pointer<Pointer<Utf8>> out_piece);
typedef LlamafuTokenToPieceDart = int Function(
    Llamafu llamafu, int token, Pointer<Pointer<Utf8>> out_piece);

typedef LlamafuTokenBosC = Int32 Function(Llamafu llamafu);
typedef LlamafuTokenBosDart = int Function(Llamafu llamafu);

typedef LlamafuTokenEosC = Int32 Function(Llamafu llamafu);
typedef LlamafuTokenEosDart = int Function(Llamafu llamafu);

// Model info
typedef LlamafuGetModelInfoC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuModelInfoStruct> out_info);
typedef LlamafuGetModelInfoDart = int Function(
    Llamafu llamafu, Pointer<LlamafuModelInfoStruct> out_info);

// Embeddings
typedef LlamafuGetEmbeddingsC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> text,
    Pointer<Pointer<Float>> out_embeddings, Pointer<Int32> out_n_embd);
typedef LlamafuGetEmbeddingsDart = int Function(
    Llamafu llamafu, Pointer<Utf8> text,
    Pointer<Pointer<Float>> out_embeddings, Pointer<Int32> out_n_embd);

// KV cache management
typedef LlamafuKvCacheClearC = Void Function(Llamafu llamafu);
typedef LlamafuKvCacheClearDart = void Function(Llamafu llamafu);

typedef LlamafuKvCacheSeqRmC = Void Function(
    Llamafu llamafu, Int32 seq_id, Int32 p0, Int32 p1);
typedef LlamafuKvCacheSeqRmDart = void Function(
    Llamafu llamafu, int seq_id, int p0, int p1);

typedef LlamafuKvCacheSeqCpC = Void Function(
    Llamafu llamafu, Int32 seq_id_src, Int32 seq_id_dst, Int32 p0, Int32 p1);
typedef LlamafuKvCacheSeqCpDart = void Function(
    Llamafu llamafu, int seq_id_src, int seq_id_dst, int p0, int p1);

typedef LlamafuKvCacheSeqKeepC = Void Function(Llamafu llamafu, Int32 seq_id);
typedef LlamafuKvCacheSeqKeepDart = void Function(Llamafu llamafu, int seq_id);

// State management
typedef LlamafuStateGetSizeC = IntPtr Function(Llamafu llamafu);
typedef LlamafuStateGetSizeDart = int Function(Llamafu llamafu);

typedef LlamafuStateSaveFileC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> path);
typedef LlamafuStateSaveFileDart = int Function(
    Llamafu llamafu, Pointer<Utf8> path);

typedef LlamafuStateLoadFileC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> path);
typedef LlamafuStateLoadFileDart = int Function(
    Llamafu llamafu, Pointer<Utf8> path);

// Performance
typedef LlamafuGetPerfStatsC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuPerfStatsStruct> out_stats);
typedef LlamafuGetPerfStatsDart = int Function(
    Llamafu llamafu, Pointer<LlamafuPerfStatsStruct> out_stats);

typedef LlamafuGetTimingsC = Int32 Function(
    Llamafu llamafu, Pointer<LlamafuTimingsStruct> out_timings);
typedef LlamafuGetTimingsDart = int Function(
    Llamafu llamafu, Pointer<LlamafuTimingsStruct> out_timings);

typedef LlamafuResetTimingsC = Void Function(Llamafu llamafu);
typedef LlamafuResetTimingsDart = void Function(Llamafu llamafu);

typedef LlamafuGetMemoryUsageC = Int32 Function(
    Llamafu llamafu, Pointer<LlamafuMemoryUsageStruct> out_usage);
typedef LlamafuGetMemoryUsageDart = int Function(
    Llamafu llamafu, Pointer<LlamafuMemoryUsageStruct> out_usage);

typedef LlamafuBenchModelC = Int32 Function(
    Llamafu llamafu, Int32 n_threads, Int32 n_predict,
    Pointer<LlamafuBenchResultStruct> out_result);
typedef LlamafuBenchModelDart = int Function(
    Llamafu llamafu, int n_threads, int n_predict,
    Pointer<LlamafuBenchResultStruct> out_result);

typedef LlamafuSetNThreadsC = Int32 Function(
    Llamafu llamafu, Int32 n_threads, Int32 n_threads_batch);
typedef LlamafuSetNThreadsDart = int Function(
    Llamafu llamafu, int n_threads, int n_threads_batch);

typedef LlamafuWarmupC = Int32 Function(Llamafu llamafu);
typedef LlamafuWarmupDart = int Function(Llamafu llamafu);

// Sampler functions
typedef LlamafuSamplerChainInitC = LlamafuSamplerHandle Function();
typedef LlamafuSamplerChainInitDart = LlamafuSamplerHandle Function();

typedef LlamafuSamplerChainAddC = Void Function(
    LlamafuSamplerHandle chain, LlamafuSamplerHandle sampler);
typedef LlamafuSamplerChainAddDart = void Function(
    LlamafuSamplerHandle chain, LlamafuSamplerHandle sampler);

typedef LlamafuSamplerFreeC = Void Function(LlamafuSamplerHandle sampler);
typedef LlamafuSamplerFreeDart = void Function(LlamafuSamplerHandle sampler);

typedef LlamafuSamplerInitGreedyC = LlamafuSamplerHandle Function();
typedef LlamafuSamplerInitGreedyDart = LlamafuSamplerHandle Function();

typedef LlamafuSamplerInitDistC = LlamafuSamplerHandle Function(Uint32 seed);
typedef LlamafuSamplerInitDistDart = LlamafuSamplerHandle Function(int seed);

typedef LlamafuSamplerInitTopKC = LlamafuSamplerHandle Function(Int32 k);
typedef LlamafuSamplerInitTopKDart = LlamafuSamplerHandle Function(int k);

typedef LlamafuSamplerInitTopPC = LlamafuSamplerHandle Function(
    Float p, IntPtr min_keep);
typedef LlamafuSamplerInitTopPDart = LlamafuSamplerHandle Function(
    double p, int min_keep);

typedef LlamafuSamplerInitMinPC = LlamafuSamplerHandle Function(
    Float p, IntPtr min_keep);
typedef LlamafuSamplerInitMinPDart = LlamafuSamplerHandle Function(
    double p, int min_keep);

typedef LlamafuSamplerInitTempC = LlamafuSamplerHandle Function(Float temp);
typedef LlamafuSamplerInitTempDart = LlamafuSamplerHandle Function(double temp);

typedef LlamafuSamplerSampleC = Int32 Function(
    LlamafuSamplerHandle sampler, Llamafu llamafu, Int32 idx);
typedef LlamafuSamplerSampleDart = int Function(
    LlamafuSamplerHandle sampler, Llamafu llamafu, int idx);

typedef LlamafuSamplerAcceptC = Void Function(
    LlamafuSamplerHandle sampler, Int32 token);
typedef LlamafuSamplerAcceptDart = void Function(
    LlamafuSamplerHandle sampler, int token);

typedef LlamafuSamplerResetC = Void Function(LlamafuSamplerHandle sampler);
typedef LlamafuSamplerResetDart = void Function(LlamafuSamplerHandle sampler);

// Batch processing
typedef LlamafuBatchInitC = LlamafuBatchHandle Function(
    Int32 n_tokens_max, Int32 embd, Int32 n_seq_max);
typedef LlamafuBatchInitDart = LlamafuBatchHandle Function(
    int n_tokens_max, int embd, int n_seq_max);

typedef LlamafuBatchFreeC = Void Function(LlamafuBatchHandle batch);
typedef LlamafuBatchFreeDart = void Function(LlamafuBatchHandle batch);

typedef LlamafuBatchClearC = Void Function(LlamafuBatchHandle batch);
typedef LlamafuBatchClearDart = void Function(LlamafuBatchHandle batch);

typedef LlamafuDecodeC = LlamafuError Function(
    Llamafu llamafu, LlamafuBatchHandle batch);
typedef LlamafuDecodeDart = int Function(
    Llamafu llamafu, LlamafuBatchHandle batch);

// Logits
typedef LlamafuGetLogitsC = Pointer<Float> Function(Llamafu llamafu);
typedef LlamafuGetLogitsDart = Pointer<Float> Function(Llamafu llamafu);

typedef LlamafuGetLogitsIthC = Pointer<Float> Function(
    Llamafu llamafu, Int32 i);
typedef LlamafuGetLogitsIthDart = Pointer<Float> Function(
    Llamafu llamafu, int i);

// Chat session
typedef LlamafuChatSessionCreateC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> system_prompt,
    Pointer<LlamafuChatSession> out_session);
typedef LlamafuChatSessionCreateDart = int Function(
    Llamafu llamafu, Pointer<Utf8> system_prompt,
    Pointer<LlamafuChatSession> out_session);

typedef LlamafuChatSessionCompleteC = LlamafuError Function(
    LlamafuChatSession session, Pointer<Utf8> user_message,
    Pointer<LlamafuMediaInput> media_inputs, IntPtr n_media_inputs,
    Pointer<Pointer<Utf8>> out_response);
typedef LlamafuChatSessionCompleteDart = int Function(
    LlamafuChatSession session, Pointer<Utf8> user_message,
    Pointer<LlamafuMediaInput> media_inputs, int n_media_inputs,
    Pointer<Pointer<Utf8>> out_response);

typedef LlamafuChatSessionGetHistoryC = LlamafuError Function(
    LlamafuChatSession session, Pointer<Pointer<Utf8>> out_history_json);
typedef LlamafuChatSessionGetHistoryDart = int Function(
    LlamafuChatSession session, Pointer<Pointer<Utf8>> out_history_json);

typedef LlamafuChatSessionFreeC = Void Function(LlamafuChatSession session);
typedef LlamafuChatSessionFreeDart = void Function(LlamafuChatSession session);

// Text analysis
typedef LlamafuDetectLanguageC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> text,
    Pointer<Pointer<Utf8>> out_language_code, Pointer<Float> out_confidence);
typedef LlamafuDetectLanguageDart = int Function(
    Llamafu llamafu, Pointer<Utf8> text,
    Pointer<Pointer<Utf8>> out_language_code, Pointer<Float> out_confidence);

typedef LlamafuAnalyzeSentimentC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> text,
    Pointer<Float> out_positive, Pointer<Float> out_negative,
    Pointer<Float> out_neutral);
typedef LlamafuAnalyzeSentimentDart = int Function(
    Llamafu llamafu, Pointer<Utf8> text,
    Pointer<Float> out_positive, Pointer<Float> out_negative,
    Pointer<Float> out_neutral);

typedef LlamafuExtractKeywordsC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> text, Int32 max_keywords,
    Pointer<Pointer<Utf8>> out_keywords_json);
typedef LlamafuExtractKeywordsDart = int Function(
    Llamafu llamafu, Pointer<Utf8> text, int max_keywords,
    Pointer<Pointer<Utf8>> out_keywords_json);

typedef LlamafuTextSummarizeC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> text, Int32 max_length,
    Pointer<Utf8> style, Pointer<Pointer<Utf8>> out_summary);
typedef LlamafuTextSummarizeDart = int Function(
    Llamafu llamafu, Pointer<Utf8> text, int max_length,
    Pointer<Utf8> style, Pointer<Pointer<Utf8>> out_summary);

// Structured output
typedef LlamafuGenerateStructuredC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> prompt,
    Pointer<LlamafuStructuredOutputStruct> output_config,
    Pointer<Pointer<Utf8>> out_result);
typedef LlamafuGenerateStructuredDart = int Function(
    Llamafu llamafu, Pointer<Utf8> prompt,
    Pointer<LlamafuStructuredOutputStruct> output_config,
    Pointer<Pointer<Utf8>> out_result);

typedef LlamafuValidateJsonSchemaC = LlamafuError Function(
    Pointer<Utf8> json_string, Pointer<Utf8> schema,
    Pointer<Bool> out_is_valid, Pointer<Pointer<Utf8>> out_error_message);
typedef LlamafuValidateJsonSchemaDart = int Function(
    Pointer<Utf8> json_string, Pointer<Utf8> schema,
    Pointer<Bool> out_is_valid, Pointer<Pointer<Utf8>> out_error_message);

// Chat templates
typedef LlamafuChatApplyTemplateC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> tmpl,
    Pointer<Pointer<Utf8>> messages, IntPtr n_messages,
    Bool add_ass, Pointer<Pointer<Utf8>> out_formatted);
typedef LlamafuChatApplyTemplateDart = int Function(
    Llamafu llamafu, Pointer<Utf8> tmpl,
    Pointer<Pointer<Utf8>> messages, int n_messages,
    bool add_ass, Pointer<Pointer<Utf8>> out_formatted);

// Image processing
typedef LlamafuImageValidateC = LlamafuError Function(
    Pointer<LlamafuMediaInput> input,
    Pointer<LlamafuImageValidationStruct> out_validation);
typedef LlamafuImageValidateDart = int Function(
    Pointer<LlamafuMediaInput> input,
    Pointer<LlamafuImageValidationStruct> out_validation);

typedef LlamafuImageProcessC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuMediaInput> input,
    Pointer<LlamafuImageProcessResultStruct> out_result);
typedef LlamafuImageProcessDart = int Function(
    Llamafu llamafu, Pointer<LlamafuMediaInput> input,
    Pointer<LlamafuImageProcessResultStruct> out_result);

typedef LlamafuImageResizeC = LlamafuError Function(
    Pointer<LlamafuMediaInput> input, Int32 target_width, Int32 target_height,
    Bool maintain_aspect_ratio, Pointer<LlamafuMediaInput> out_resized);
typedef LlamafuImageResizeDart = int Function(
    Pointer<LlamafuMediaInput> input, int target_width, int target_height,
    bool maintain_aspect_ratio, Pointer<LlamafuMediaInput> out_resized);

typedef LlamafuImageToBase64C = LlamafuError Function(
    Pointer<LlamafuMediaInput> input, Int32 format,
    Pointer<Pointer<Utf8>> out_base64);
typedef LlamafuImageToBase64Dart = int Function(
    Pointer<LlamafuMediaInput> input, int format,
    Pointer<Pointer<Utf8>> out_base64);

// Audio processing
typedef LlamafuAudioProcessC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuMediaInput> input,
    Pointer<LlamafuAudioProcessResultStruct> out_result);
typedef LlamafuAudioProcessDart = int Function(
    Llamafu llamafu, Pointer<LlamafuMediaInput> input,
    Pointer<LlamafuAudioProcessResultStruct> out_result);

typedef LlamafuAudioResampleC = LlamafuError Function(
    Pointer<Float> input_samples, IntPtr n_input_samples,
    Int32 input_rate, Int32 target_rate,
    Pointer<Pointer<Float>> out_samples, Pointer<IntPtr> out_n_samples);
typedef LlamafuAudioResampleDart = int Function(
    Pointer<Float> input_samples, int n_input_samples,
    int input_rate, int target_rate,
    Pointer<Pointer<Float>> out_samples, Pointer<IntPtr> out_n_samples);

// Enhanced LoRA
typedef LlamafuGetLoraAdapterInfoC = LlamafuError Function(
    Llamafu llamafu, LlamafuLoraAdapter adapter,
    Pointer<LlamafuLoraAdapterInfoStruct> out_info);
typedef LlamafuGetLoraAdapterInfoDart = int Function(
    Llamafu llamafu, LlamafuLoraAdapter adapter,
    Pointer<LlamafuLoraAdapterInfoStruct> out_info);

typedef LlamafuListLoraAdaptersC = LlamafuError Function(
    Llamafu llamafu, Pointer<Pointer<LlamafuLoraAdapterInfoStruct>> out_adapters,
    Pointer<IntPtr> out_n_adapters);
typedef LlamafuListLoraAdaptersDart = int Function(
    Llamafu llamafu, Pointer<Pointer<LlamafuLoraAdapterInfoStruct>> out_adapters,
    Pointer<IntPtr> out_n_adapters);

typedef LlamafuValidateLoraCompatibilityC = LlamafuError Function(
    Llamafu llamafu, Pointer<Utf8> lora_path,
    Pointer<Bool> out_is_compatible, Pointer<Pointer<Utf8>> out_error_message);
typedef LlamafuValidateLoraCompatibilityDart = int Function(
    Llamafu llamafu, Pointer<Utf8> lora_path,
    Pointer<Bool> out_is_compatible, Pointer<Pointer<Utf8>> out_error_message);

// Utility
typedef LlamafuFreeStringC = Void Function(Pointer<Utf8> str);
typedef LlamafuFreeStringDart = void Function(Pointer<Utf8> str);

typedef LlamafuFreeTokensC = Void Function(Pointer<Int32> tokens);
typedef LlamafuFreeTokensDart = void Function(Pointer<Int32> tokens);

typedef LlamafuFreeEmbeddingsC = Void Function(Pointer<Float> embeddings);
typedef LlamafuFreeEmbeddingsDart = void Function(Pointer<Float> embeddings);

typedef LlamafuPrintSystemInfoC = Pointer<Utf8> Function();
typedef LlamafuPrintSystemInfoDart = Pointer<Utf8> Function();

// Tool calling functions
typedef LlamafuGenerateToolCallC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuToolCallParamsStruct> params,
    Pointer<Pointer<LlamafuToolCallStruct>> out_calls, Pointer<IntPtr> out_n_calls);
typedef LlamafuGenerateToolCallDart = int Function(
    Llamafu llamafu, Pointer<LlamafuToolCallParamsStruct> params,
    Pointer<Pointer<LlamafuToolCallStruct>> out_calls, Pointer<IntPtr> out_n_calls);

typedef LlamafuFreeToolCallsC = Void Function(
    Pointer<LlamafuToolCallStruct> calls, IntPtr n_calls);
typedef LlamafuFreeToolCallsDart = void Function(
    Pointer<LlamafuToolCallStruct> calls, int n_calls);

typedef LlamafuSchemaToGrammarC = LlamafuError Function(
    Pointer<Utf8> json_schema, Pointer<Pointer<Utf8>> out_grammar);
typedef LlamafuSchemaToGrammarDart = int Function(
    Pointer<Utf8> json_schema, Pointer<Pointer<Utf8>> out_grammar);

typedef LlamafuBuildToolGrammarC = LlamafuError Function(
    Pointer<LlamafuToolStruct> tools, IntPtr n_tools, Bool allow_multiple,
    Pointer<Pointer<Utf8>> out_grammar);
typedef LlamafuBuildToolGrammarDart = int Function(
    Pointer<LlamafuToolStruct> tools, int n_tools, bool allow_multiple,
    Pointer<Pointer<Utf8>> out_grammar);

// JSON output functions
typedef LlamafuGenerateJsonC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuJsonParamsStruct> params,
    Pointer<Pointer<Utf8>> out_json);
typedef LlamafuGenerateJsonDart = int Function(
    Llamafu llamafu, Pointer<LlamafuJsonParamsStruct> params,
    Pointer<Pointer<Utf8>> out_json);

typedef LlamafuGenerateJsonStreamingC = LlamafuError Function(
    Llamafu llamafu, Pointer<LlamafuJsonParamsStruct> params,
    Pointer<NativeFunction<LlamafuStreamCallbackC>> callback, Pointer<Void> user_data);
typedef LlamafuGenerateJsonStreamingDart = int Function(
    Llamafu llamafu, Pointer<LlamafuJsonParamsStruct> params,
    Pointer<NativeFunction<LlamafuStreamCallbackC>> callback, Pointer<Void> user_data);

typedef LlamafuJsonValidateC = LlamafuError Function(
    Pointer<Utf8> json_string, Pointer<Utf8> schema,
    Pointer<Bool> out_valid, Pointer<Pointer<Utf8>> out_error);
typedef LlamafuJsonValidateDart = int Function(
    Pointer<Utf8> json_string, Pointer<Utf8> schema,
    Pointer<Bool> out_valid, Pointer<Pointer<Utf8>> out_error);

final class LlamafuBindings {
  final DynamicLibrary _dylib;

  // Core functions
  late final LlamafuInitDart _llamafuInit;
  late final LlamafuCompleteDart _llamafuComplete;
  late final LlamafuCompleteWithGrammarDart _llamafuCompleteWithGrammar;
  late final LlamafuCompleteStreamDart _llamafuCompleteStream;
  late final LlamafuCompleteWithGrammarStreamDart _llamafuCompleteWithGrammarStream;
  late final LlamafuMultimodalCompleteDart _llamafuMultimodalComplete;
  late final LlamafuMultimodalCompleteStreamDart _llamafuMultimodalCompleteStream;
  late final LlamafuLoraAdapterInitDart _llamafuLoraAdapterInit;
  late final LlamafuLoraAdapterApplyDart _llamafuLoraAdapterApply;
  late final LlamafuLoraAdapterRemoveDart _llamafuLoraAdapterRemove;
  late final LlamafuLoraAdapterClearAllDart _llamafuLoraAdapterClearAll;
  late final LlamafuLoraAdapterFreeDart _llamafuLoraAdapterFree;
  late final LlamafuGrammarSamplerInitDart _llamafuGrammarSamplerInit;
  late final LlamafuGrammarSamplerFreeDart _llamafuGrammarSamplerFree;
  late final LlamafuFreeDart _llamafuFree;

  // Tokenization
  late final LlamafuTokenizeDart _llamafuTokenize;
  late final LlamafuDetokenizeDart _llamafuDetokenize;
  late final LlamafuTokenToPieceDart _llamafuTokenToPiece;
  late final LlamafuTokenBosDart _llamafuTokenBos;
  late final LlamafuTokenEosDart _llamafuTokenEos;

  // Model info
  late final LlamafuGetModelInfoDart _llamafuGetModelInfo;

  // Embeddings
  late final LlamafuGetEmbeddingsDart _llamafuGetEmbeddings;

  // KV cache
  late final LlamafuKvCacheClearDart _llamafuKvCacheClear;
  late final LlamafuKvCacheSeqRmDart _llamafuKvCacheSeqRm;
  late final LlamafuKvCacheSeqCpDart _llamafuKvCacheSeqCp;
  late final LlamafuKvCacheSeqKeepDart _llamafuKvCacheSeqKeep;

  // State management
  late final LlamafuStateGetSizeDart _llamafuStateGetSize;
  late final LlamafuStateSaveFileDart _llamafuStateSaveFile;
  late final LlamafuStateLoadFileDart _llamafuStateLoadFile;

  // Performance
  late final LlamafuGetPerfStatsDart _llamafuGetPerfStats;
  late final LlamafuGetTimingsDart _llamafuGetTimings;
  late final LlamafuResetTimingsDart _llamafuResetTimings;
  late final LlamafuGetMemoryUsageDart _llamafuGetMemoryUsage;
  late final LlamafuBenchModelDart _llamafuBenchModel;
  late final LlamafuSetNThreadsDart _llamafuSetNThreads;
  late final LlamafuWarmupDart _llamafuWarmup;

  // Samplers
  late final LlamafuSamplerChainInitDart _llamafuSamplerChainInit;
  late final LlamafuSamplerChainAddDart _llamafuSamplerChainAdd;
  late final LlamafuSamplerFreeDart _llamafuSamplerFree;
  late final LlamafuSamplerInitGreedyDart _llamafuSamplerInitGreedy;
  late final LlamafuSamplerInitDistDart _llamafuSamplerInitDist;
  late final LlamafuSamplerInitTopKDart _llamafuSamplerInitTopK;
  late final LlamafuSamplerInitTopPDart _llamafuSamplerInitTopP;
  late final LlamafuSamplerInitMinPDart _llamafuSamplerInitMinP;
  late final LlamafuSamplerInitTempDart _llamafuSamplerInitTemp;
  late final LlamafuSamplerSampleDart _llamafuSamplerSample;
  late final LlamafuSamplerAcceptDart _llamafuSamplerAccept;
  late final LlamafuSamplerResetDart _llamafuSamplerReset;

  // Batch
  late final LlamafuBatchInitDart _llamafuBatchInit;
  late final LlamafuBatchFreeDart _llamafuBatchFree;
  late final LlamafuBatchClearDart _llamafuBatchClear;
  late final LlamafuDecodeDart _llamafuDecode;

  // Logits
  late final LlamafuGetLogitsDart _llamafuGetLogits;
  late final LlamafuGetLogitsIthDart _llamafuGetLogitsIth;

  // Chat session
  late final LlamafuChatSessionCreateDart _llamafuChatSessionCreate;
  late final LlamafuChatSessionCompleteDart _llamafuChatSessionComplete;
  late final LlamafuChatSessionGetHistoryDart _llamafuChatSessionGetHistory;
  late final LlamafuChatSessionFreeDart _llamafuChatSessionFree;

  // Text analysis
  late final LlamafuDetectLanguageDart _llamafuDetectLanguage;
  late final LlamafuAnalyzeSentimentDart _llamafuAnalyzeSentiment;
  late final LlamafuExtractKeywordsDart _llamafuExtractKeywords;
  late final LlamafuTextSummarizeDart _llamafuTextSummarize;

  // Structured output
  late final LlamafuGenerateStructuredDart _llamafuGenerateStructured;
  late final LlamafuValidateJsonSchemaDart _llamafuValidateJsonSchema;
  late final LlamafuChatApplyTemplateDart _llamafuChatApplyTemplate;

  // Image processing
  late final LlamafuImageValidateDart _llamafuImageValidate;
  late final LlamafuImageProcessDart _llamafuImageProcess;
  late final LlamafuImageResizeDart _llamafuImageResize;
  late final LlamafuImageToBase64Dart _llamafuImageToBase64;

  // Audio processing
  late final LlamafuAudioProcessDart _llamafuAudioProcess;
  late final LlamafuAudioResampleDart _llamafuAudioResample;

  // Enhanced LoRA
  late final LlamafuGetLoraAdapterInfoDart _llamafuGetLoraAdapterInfo;
  late final LlamafuListLoraAdaptersDart _llamafuListLoraAdapters;
  late final LlamafuValidateLoraCompatibilityDart _llamafuValidateLoraCompatibility;

  // Utility
  late final LlamafuFreeStringDart _llamafuFreeString;
  late final LlamafuFreeTokensDart _llamafuFreeTokens;
  late final LlamafuFreeEmbeddingsDart _llamafuFreeEmbeddings;
  late final LlamafuPrintSystemInfoDart _llamafuPrintSystemInfo;

  LlamafuBindings._(this._dylib) {
    _llamafuInit = _dylib
        .lookup<NativeFunction<LlamafuInitC>>('llamafu_init')
        .asFunction<LlamafuInitDart>();
    _llamafuComplete = _dylib
        .lookup<NativeFunction<LlamafuCompleteC>>('llamafu_complete')
        .asFunction<LlamafuCompleteDart>();
    _llamafuCompleteWithGrammar = _dylib
        .lookup<NativeFunction<LlamafuCompleteWithGrammarC>>('llamafu_complete_with_grammar')
        .asFunction<LlamafuCompleteWithGrammarDart>();
    _llamafuCompleteStream = _dylib
        .lookup<NativeFunction<LlamafuCompleteStreamC>>('llamafu_complete_stream')
        .asFunction<LlamafuCompleteStreamDart>();
    _llamafuCompleteWithGrammarStream = _dylib
        .lookup<NativeFunction<LlamafuCompleteWithGrammarStreamC>>('llamafu_complete_with_grammar_stream')
        .asFunction<LlamafuCompleteWithGrammarStreamDart>();
    _llamafuMultimodalComplete = _dylib
        .lookup<NativeFunction<LlamafuMultimodalCompleteC>>('llamafu_multimodal_complete')
        .asFunction<LlamafuMultimodalCompleteDart>();
    _llamafuMultimodalCompleteStream = _dylib
        .lookup<NativeFunction<LlamafuMultimodalCompleteStreamC>>('llamafu_multimodal_complete_stream')
        .asFunction<LlamafuMultimodalCompleteStreamDart>();
    _llamafuLoraAdapterInit = _dylib
        .lookup<NativeFunction<LlamafuLoraAdapterInitC>>('llamafu_lora_adapter_init')
        .asFunction<LlamafuLoraAdapterInitDart>();
    _llamafuLoraAdapterApply = _dylib
        .lookup<NativeFunction<LlamafuLoraAdapterApplyC>>('llamafu_lora_adapter_apply')
        .asFunction<LlamafuLoraAdapterApplyDart>();
    _llamafuLoraAdapterRemove = _dylib
        .lookup<NativeFunction<LlamafuLoraAdapterRemoveC>>('llamafu_lora_adapter_remove')
        .asFunction<LlamafuLoraAdapterRemoveDart>();
    _llamafuLoraAdapterClearAll = _dylib
        .lookup<NativeFunction<LlamafuLoraAdapterClearAllC>>('llamafu_lora_adapter_clear_all')
        .asFunction<LlamafuLoraAdapterClearAllDart>();
    _llamafuLoraAdapterFree = _dylib
        .lookup<NativeFunction<LlamafuLoraAdapterFreeC>>('llamafu_lora_adapter_free')
        .asFunction<LlamafuLoraAdapterFreeDart>();
    _llamafuGrammarSamplerInit = _dylib
        .lookup<NativeFunction<LlamafuGrammarSamplerInitC>>('llamafu_grammar_sampler_init')
        .asFunction<LlamafuGrammarSamplerInitDart>();
    _llamafuGrammarSamplerFree = _dylib
        .lookup<NativeFunction<LlamafuGrammarSamplerFreeC>>('llamafu_grammar_sampler_free')
        .asFunction<LlamafuGrammarSamplerFreeDart>();
    _llamafuFree = _dylib
        .lookup<NativeFunction<LlamafuFreeC>>('llamafu_free')
        .asFunction<LlamafuFreeDart>();

    // Tokenization
    _llamafuTokenize = _dylib
        .lookup<NativeFunction<LlamafuTokenizeC>>('llamafu_tokenize')
        .asFunction<LlamafuTokenizeDart>();
    _llamafuDetokenize = _dylib
        .lookup<NativeFunction<LlamafuDetokenizeC>>('llamafu_detokenize')
        .asFunction<LlamafuDetokenizeDart>();
    _llamafuTokenToPiece = _dylib
        .lookup<NativeFunction<LlamafuTokenToPieceC>>('llamafu_token_to_piece')
        .asFunction<LlamafuTokenToPieceDart>();
    _llamafuTokenBos = _dylib
        .lookup<NativeFunction<LlamafuTokenBosC>>('llamafu_token_bos')
        .asFunction<LlamafuTokenBosDart>();
    _llamafuTokenEos = _dylib
        .lookup<NativeFunction<LlamafuTokenEosC>>('llamafu_token_eos')
        .asFunction<LlamafuTokenEosDart>();

    // Model info
    _llamafuGetModelInfo = _dylib
        .lookup<NativeFunction<LlamafuGetModelInfoC>>('llamafu_get_model_info')
        .asFunction<LlamafuGetModelInfoDart>();

    // Embeddings
    _llamafuGetEmbeddings = _dylib
        .lookup<NativeFunction<LlamafuGetEmbeddingsC>>('llamafu_get_embeddings')
        .asFunction<LlamafuGetEmbeddingsDart>();

    // KV cache
    _llamafuKvCacheClear = _dylib
        .lookup<NativeFunction<LlamafuKvCacheClearC>>('llamafu_kv_cache_clear')
        .asFunction<LlamafuKvCacheClearDart>();
    _llamafuKvCacheSeqRm = _dylib
        .lookup<NativeFunction<LlamafuKvCacheSeqRmC>>('llamafu_kv_cache_seq_rm')
        .asFunction<LlamafuKvCacheSeqRmDart>();
    _llamafuKvCacheSeqCp = _dylib
        .lookup<NativeFunction<LlamafuKvCacheSeqCpC>>('llamafu_kv_cache_seq_cp')
        .asFunction<LlamafuKvCacheSeqCpDart>();
    _llamafuKvCacheSeqKeep = _dylib
        .lookup<NativeFunction<LlamafuKvCacheSeqKeepC>>('llamafu_kv_cache_seq_keep')
        .asFunction<LlamafuKvCacheSeqKeepDart>();

    // State management
    _llamafuStateGetSize = _dylib
        .lookup<NativeFunction<LlamafuStateGetSizeC>>('llamafu_state_get_size')
        .asFunction<LlamafuStateGetSizeDart>();
    _llamafuStateSaveFile = _dylib
        .lookup<NativeFunction<LlamafuStateSaveFileC>>('llamafu_state_save_file')
        .asFunction<LlamafuStateSaveFileDart>();
    _llamafuStateLoadFile = _dylib
        .lookup<NativeFunction<LlamafuStateLoadFileC>>('llamafu_state_load_file')
        .asFunction<LlamafuStateLoadFileDart>();

    // Performance
    _llamafuGetPerfStats = _dylib
        .lookup<NativeFunction<LlamafuGetPerfStatsC>>('llamafu_get_perf_stats')
        .asFunction<LlamafuGetPerfStatsDart>();
    _llamafuGetTimings = _dylib
        .lookup<NativeFunction<LlamafuGetTimingsC>>('llamafu_get_timings')
        .asFunction<LlamafuGetTimingsDart>();
    _llamafuResetTimings = _dylib
        .lookup<NativeFunction<LlamafuResetTimingsC>>('llamafu_reset_timings')
        .asFunction<LlamafuResetTimingsDart>();
    _llamafuGetMemoryUsage = _dylib
        .lookup<NativeFunction<LlamafuGetMemoryUsageC>>('llamafu_get_memory_usage')
        .asFunction<LlamafuGetMemoryUsageDart>();
    _llamafuBenchModel = _dylib
        .lookup<NativeFunction<LlamafuBenchModelC>>('llamafu_bench_model')
        .asFunction<LlamafuBenchModelDart>();
    _llamafuSetNThreads = _dylib
        .lookup<NativeFunction<LlamafuSetNThreadsC>>('llamafu_set_n_threads')
        .asFunction<LlamafuSetNThreadsDart>();
    _llamafuWarmup = _dylib
        .lookup<NativeFunction<LlamafuWarmupC>>('llamafu_warmup')
        .asFunction<LlamafuWarmupDart>();

    // Samplers
    _llamafuSamplerChainInit = _dylib
        .lookup<NativeFunction<LlamafuSamplerChainInitC>>('llamafu_sampler_chain_init')
        .asFunction<LlamafuSamplerChainInitDart>();
    _llamafuSamplerChainAdd = _dylib
        .lookup<NativeFunction<LlamafuSamplerChainAddC>>('llamafu_sampler_chain_add')
        .asFunction<LlamafuSamplerChainAddDart>();
    _llamafuSamplerFree = _dylib
        .lookup<NativeFunction<LlamafuSamplerFreeC>>('llamafu_sampler_free')
        .asFunction<LlamafuSamplerFreeDart>();
    _llamafuSamplerInitGreedy = _dylib
        .lookup<NativeFunction<LlamafuSamplerInitGreedyC>>('llamafu_sampler_init_greedy')
        .asFunction<LlamafuSamplerInitGreedyDart>();
    _llamafuSamplerInitDist = _dylib
        .lookup<NativeFunction<LlamafuSamplerInitDistC>>('llamafu_sampler_init_dist')
        .asFunction<LlamafuSamplerInitDistDart>();
    _llamafuSamplerInitTopK = _dylib
        .lookup<NativeFunction<LlamafuSamplerInitTopKC>>('llamafu_sampler_init_top_k')
        .asFunction<LlamafuSamplerInitTopKDart>();
    _llamafuSamplerInitTopP = _dylib
        .lookup<NativeFunction<LlamafuSamplerInitTopPC>>('llamafu_sampler_init_top_p')
        .asFunction<LlamafuSamplerInitTopPDart>();
    _llamafuSamplerInitMinP = _dylib
        .lookup<NativeFunction<LlamafuSamplerInitMinPC>>('llamafu_sampler_init_min_p')
        .asFunction<LlamafuSamplerInitMinPDart>();
    _llamafuSamplerInitTemp = _dylib
        .lookup<NativeFunction<LlamafuSamplerInitTempC>>('llamafu_sampler_init_temp')
        .asFunction<LlamafuSamplerInitTempDart>();
    _llamafuSamplerSample = _dylib
        .lookup<NativeFunction<LlamafuSamplerSampleC>>('llamafu_sampler_sample')
        .asFunction<LlamafuSamplerSampleDart>();
    _llamafuSamplerAccept = _dylib
        .lookup<NativeFunction<LlamafuSamplerAcceptC>>('llamafu_sampler_accept')
        .asFunction<LlamafuSamplerAcceptDart>();
    _llamafuSamplerReset = _dylib
        .lookup<NativeFunction<LlamafuSamplerResetC>>('llamafu_sampler_reset')
        .asFunction<LlamafuSamplerResetDart>();

    // Batch
    _llamafuBatchInit = _dylib
        .lookup<NativeFunction<LlamafuBatchInitC>>('llamafu_batch_init')
        .asFunction<LlamafuBatchInitDart>();
    _llamafuBatchFree = _dylib
        .lookup<NativeFunction<LlamafuBatchFreeC>>('llamafu_batch_free')
        .asFunction<LlamafuBatchFreeDart>();
    _llamafuBatchClear = _dylib
        .lookup<NativeFunction<LlamafuBatchClearC>>('llamafu_batch_clear')
        .asFunction<LlamafuBatchClearDart>();
    _llamafuDecode = _dylib
        .lookup<NativeFunction<LlamafuDecodeC>>('llamafu_decode')
        .asFunction<LlamafuDecodeDart>();

    // Logits
    _llamafuGetLogits = _dylib
        .lookup<NativeFunction<LlamafuGetLogitsC>>('llamafu_get_logits')
        .asFunction<LlamafuGetLogitsDart>();
    _llamafuGetLogitsIth = _dylib
        .lookup<NativeFunction<LlamafuGetLogitsIthC>>('llamafu_get_logits_ith')
        .asFunction<LlamafuGetLogitsIthDart>();

    // Chat session
    _llamafuChatSessionCreate = _dylib
        .lookup<NativeFunction<LlamafuChatSessionCreateC>>('llamafu_chat_session_create')
        .asFunction<LlamafuChatSessionCreateDart>();
    _llamafuChatSessionComplete = _dylib
        .lookup<NativeFunction<LlamafuChatSessionCompleteC>>('llamafu_chat_session_complete')
        .asFunction<LlamafuChatSessionCompleteDart>();
    _llamafuChatSessionGetHistory = _dylib
        .lookup<NativeFunction<LlamafuChatSessionGetHistoryC>>('llamafu_chat_session_get_history')
        .asFunction<LlamafuChatSessionGetHistoryDart>();
    _llamafuChatSessionFree = _dylib
        .lookup<NativeFunction<LlamafuChatSessionFreeC>>('llamafu_chat_session_free')
        .asFunction<LlamafuChatSessionFreeDart>();

    // Text analysis
    _llamafuDetectLanguage = _dylib
        .lookup<NativeFunction<LlamafuDetectLanguageC>>('llamafu_detect_language')
        .asFunction<LlamafuDetectLanguageDart>();
    _llamafuAnalyzeSentiment = _dylib
        .lookup<NativeFunction<LlamafuAnalyzeSentimentC>>('llamafu_analyze_sentiment')
        .asFunction<LlamafuAnalyzeSentimentDart>();
    _llamafuExtractKeywords = _dylib
        .lookup<NativeFunction<LlamafuExtractKeywordsC>>('llamafu_extract_keywords')
        .asFunction<LlamafuExtractKeywordsDart>();
    _llamafuTextSummarize = _dylib
        .lookup<NativeFunction<LlamafuTextSummarizeC>>('llamafu_text_summarize')
        .asFunction<LlamafuTextSummarizeDart>();

    // Structured output
    _llamafuGenerateStructured = _dylib
        .lookup<NativeFunction<LlamafuGenerateStructuredC>>('llamafu_generate_structured')
        .asFunction<LlamafuGenerateStructuredDart>();
    _llamafuValidateJsonSchema = _dylib
        .lookup<NativeFunction<LlamafuValidateJsonSchemaC>>('llamafu_validate_json_schema')
        .asFunction<LlamafuValidateJsonSchemaDart>();
    _llamafuChatApplyTemplate = _dylib
        .lookup<NativeFunction<LlamafuChatApplyTemplateC>>('llamafu_chat_apply_template')
        .asFunction<LlamafuChatApplyTemplateDart>();

    // Image processing
    _llamafuImageValidate = _dylib
        .lookup<NativeFunction<LlamafuImageValidateC>>('llamafu_image_validate')
        .asFunction<LlamafuImageValidateDart>();
    _llamafuImageProcess = _dylib
        .lookup<NativeFunction<LlamafuImageProcessC>>('llamafu_image_process')
        .asFunction<LlamafuImageProcessDart>();
    _llamafuImageResize = _dylib
        .lookup<NativeFunction<LlamafuImageResizeC>>('llamafu_image_resize')
        .asFunction<LlamafuImageResizeDart>();
    _llamafuImageToBase64 = _dylib
        .lookup<NativeFunction<LlamafuImageToBase64C>>('llamafu_image_to_base64')
        .asFunction<LlamafuImageToBase64Dart>();

    // Audio processing
    _llamafuAudioProcess = _dylib
        .lookup<NativeFunction<LlamafuAudioProcessC>>('llamafu_audio_process')
        .asFunction<LlamafuAudioProcessDart>();
    _llamafuAudioResample = _dylib
        .lookup<NativeFunction<LlamafuAudioResampleC>>('llamafu_audio_resample')
        .asFunction<LlamafuAudioResampleDart>();

    // Enhanced LoRA
    _llamafuGetLoraAdapterInfo = _dylib
        .lookup<NativeFunction<LlamafuGetLoraAdapterInfoC>>('llamafu_get_lora_adapter_info')
        .asFunction<LlamafuGetLoraAdapterInfoDart>();
    _llamafuListLoraAdapters = _dylib
        .lookup<NativeFunction<LlamafuListLoraAdaptersC>>('llamafu_list_lora_adapters')
        .asFunction<LlamafuListLoraAdaptersDart>();
    _llamafuValidateLoraCompatibility = _dylib
        .lookup<NativeFunction<LlamafuValidateLoraCompatibilityC>>('llamafu_validate_lora_compatibility')
        .asFunction<LlamafuValidateLoraCompatibilityDart>();

    // Utility
    _llamafuFreeString = _dylib
        .lookup<NativeFunction<LlamafuFreeStringC>>('llamafu_free_string')
        .asFunction<LlamafuFreeStringDart>();
    _llamafuFreeTokens = _dylib
        .lookup<NativeFunction<LlamafuFreeTokensC>>('llamafu_free_tokens')
        .asFunction<LlamafuFreeTokensDart>();
    _llamafuFreeEmbeddings = _dylib
        .lookup<NativeFunction<LlamafuFreeEmbeddingsC>>('llamafu_free_embeddings')
        .asFunction<LlamafuFreeEmbeddingsDart>();
    _llamafuPrintSystemInfo = _dylib
        .lookup<NativeFunction<LlamafuPrintSystemInfoC>>('llamafu_print_system_info')
        .asFunction<LlamafuPrintSystemInfoDart>();
  }

  static Future<LlamafuBindings> init() async {
    final dylib = Platform.isAndroid
        ? DynamicLibrary.open('libllamafu.so')
        : DynamicLibrary.process();
    return LlamafuBindings._(dylib);
  }

  int llamafuInit(Pointer<LlamafuModelParams> params, Pointer<Llamafu> out_llamafu) {
    return _llamafuInit(params, out_llamafu);
  }

  int llamafuComplete(
      Llamafu llamafu, Pointer<LlamafuInferParams> params, Pointer<Pointer<Utf8>> out_result) {
    return _llamafuComplete(llamafu, params, out_result);
  }

  int llamafuCompleteWithGrammar(
      Llamafu llamafu, 
      Pointer<LlamafuInferParams> params, 
      Pointer<LlamafuGrammarParams> grammar_params, 
      Pointer<Pointer<Utf8>> out_result) {
    return _llamafuCompleteWithGrammar(llamafu, params, grammar_params, out_result);
  }

  int llamafuCompleteStream(
      Llamafu llamafu,
      Pointer<LlamafuInferParams> params,
      Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
      Pointer<Void> user_data) {
    return _llamafuCompleteStream(llamafu, params, callback, user_data);
  }

  int llamafuCompleteWithGrammarStream(
      Llamafu llamafu,
      Pointer<LlamafuInferParams> params,
      Pointer<LlamafuGrammarParams> grammar_params,
      Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
      Pointer<Void> user_data) {
    return _llamafuCompleteWithGrammarStream(llamafu, params, grammar_params, callback, user_data);
  }

  int llamafuMultimodalComplete(
      Llamafu llamafu, Pointer<LlamafuMultimodalInferParams> params, Pointer<Pointer<Utf8>> out_result) {
    return _llamafuMultimodalComplete(llamafu, params, out_result);
  }

  int llamafuMultimodalCompleteStream(
      Llamafu llamafu,
      Pointer<LlamafuMultimodalInferParams> params,
      Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
      Pointer<Void> user_data) {
    return _llamafuMultimodalCompleteStream(llamafu, params, callback, user_data);
  }

  int llamafuLoraAdapterInit(
      Llamafu llamafu, Pointer<Utf8> lora_path, Pointer<LlamafuLoraAdapter> out_adapter) {
    return _llamafuLoraAdapterInit(llamafu, lora_path, out_adapter);
  }

  int llamafuLoraAdapterApply(Llamafu llamafu, LlamafuLoraAdapter adapter, double scale) {
    return _llamafuLoraAdapterApply(llamafu, adapter, scale);
  }

  int llamafuLoraAdapterRemove(Llamafu llamafu, LlamafuLoraAdapter adapter) {
    return _llamafuLoraAdapterRemove(llamafu, adapter);
  }

  int llamafuLoraAdapterClearAll(Llamafu llamafu) {
    return _llamafuLoraAdapterClearAll(llamafu);
  }

  void llamafuLoraAdapterFree(LlamafuLoraAdapter adapter) {
    _llamafuLoraAdapterFree(adapter);
  }

  int llamafuGrammarSamplerInit(
      Llamafu llamafu, Pointer<Utf8> grammar_str, Pointer<Utf8> grammar_root, Pointer<LlamafuGrammarSampler> out_sampler) {
    return _llamafuGrammarSamplerInit(llamafu, grammar_str, grammar_root, out_sampler);
  }

  void llamafuGrammarSamplerFree(LlamafuGrammarSampler sampler) {
    _llamafuGrammarSamplerFree(sampler);
  }

  void llamafuFree(Llamafu llamafu) {
    _llamafuFree(llamafu);
  }

  // Tokenization
  int llamafuTokenize(Llamafu llamafu, Pointer<Utf8> text, int textLen,
          Pointer<Pointer<Int32>> outTokens, Pointer<Int32> outNTokens,
          bool addSpecial, bool parseSpecial) =>
      _llamafuTokenize(llamafu, text, textLen, outTokens, outNTokens, addSpecial, parseSpecial);

  int llamafuDetokenize(Llamafu llamafu, Pointer<Int32> tokens, int nTokens,
          Pointer<Pointer<Utf8>> outText, bool removeSpecial, bool unparseSpecial) =>
      _llamafuDetokenize(llamafu, tokens, nTokens, outText, removeSpecial, unparseSpecial);

  int llamafuTokenToPiece(Llamafu llamafu, int token, Pointer<Pointer<Utf8>> outPiece) =>
      _llamafuTokenToPiece(llamafu, token, outPiece);

  int llamafuTokenBos(Llamafu llamafu) => _llamafuTokenBos(llamafu);
  int llamafuTokenEos(Llamafu llamafu) => _llamafuTokenEos(llamafu);

  // Model info
  int llamafuGetModelInfo(Llamafu llamafu, Pointer<LlamafuModelInfoStruct> outInfo) =>
      _llamafuGetModelInfo(llamafu, outInfo);

  // Embeddings
  int llamafuGetEmbeddings(Llamafu llamafu, Pointer<Utf8> text,
          Pointer<Pointer<Float>> outEmbeddings, Pointer<Int32> outNEmbd) =>
      _llamafuGetEmbeddings(llamafu, text, outEmbeddings, outNEmbd);

  // KV cache
  void llamafuKvCacheClear(Llamafu llamafu) => _llamafuKvCacheClear(llamafu);
  void llamafuKvCacheSeqRm(Llamafu llamafu, int seqId, int p0, int p1) =>
      _llamafuKvCacheSeqRm(llamafu, seqId, p0, p1);
  void llamafuKvCacheSeqCp(Llamafu llamafu, int seqIdSrc, int seqIdDst, int p0, int p1) =>
      _llamafuKvCacheSeqCp(llamafu, seqIdSrc, seqIdDst, p0, p1);
  void llamafuKvCacheSeqKeep(Llamafu llamafu, int seqId) => _llamafuKvCacheSeqKeep(llamafu, seqId);

  // State management
  int llamafuStateGetSize(Llamafu llamafu) => _llamafuStateGetSize(llamafu);
  int llamafuStateSaveFile(Llamafu llamafu, Pointer<Utf8> path) => _llamafuStateSaveFile(llamafu, path);
  int llamafuStateLoadFile(Llamafu llamafu, Pointer<Utf8> path) => _llamafuStateLoadFile(llamafu, path);

  // Performance
  int llamafuGetPerfStats(Llamafu llamafu, Pointer<LlamafuPerfStatsStruct> outStats) =>
      _llamafuGetPerfStats(llamafu, outStats);
  int llamafuGetTimings(Llamafu llamafu, Pointer<LlamafuTimingsStruct> outTimings) =>
      _llamafuGetTimings(llamafu, outTimings);
  void llamafuResetTimings(Llamafu llamafu) => _llamafuResetTimings(llamafu);
  int llamafuGetMemoryUsage(Llamafu llamafu, Pointer<LlamafuMemoryUsageStruct> outUsage) =>
      _llamafuGetMemoryUsage(llamafu, outUsage);
  int llamafuBenchModel(Llamafu llamafu, int nThreads, int nPredict,
          Pointer<LlamafuBenchResultStruct> outResult) =>
      _llamafuBenchModel(llamafu, nThreads, nPredict, outResult);
  int llamafuSetNThreads(Llamafu llamafu, int nThreads, int nThreadsBatch) =>
      _llamafuSetNThreads(llamafu, nThreads, nThreadsBatch);
  int llamafuWarmup(Llamafu llamafu) => _llamafuWarmup(llamafu);

  // Samplers
  LlamafuSamplerHandle llamafuSamplerChainInit() => _llamafuSamplerChainInit();
  void llamafuSamplerChainAdd(LlamafuSamplerHandle chain, LlamafuSamplerHandle sampler) =>
      _llamafuSamplerChainAdd(chain, sampler);
  void llamafuSamplerFree(LlamafuSamplerHandle sampler) => _llamafuSamplerFree(sampler);
  LlamafuSamplerHandle llamafuSamplerInitGreedy() => _llamafuSamplerInitGreedy();
  LlamafuSamplerHandle llamafuSamplerInitDist(int seed) => _llamafuSamplerInitDist(seed);
  LlamafuSamplerHandle llamafuSamplerInitTopK(int k) => _llamafuSamplerInitTopK(k);
  LlamafuSamplerHandle llamafuSamplerInitTopP(double p, int minKeep) => _llamafuSamplerInitTopP(p, minKeep);
  LlamafuSamplerHandle llamafuSamplerInitMinP(double p, int minKeep) => _llamafuSamplerInitMinP(p, minKeep);
  LlamafuSamplerHandle llamafuSamplerInitTemp(double temp) => _llamafuSamplerInitTemp(temp);
  int llamafuSamplerSample(LlamafuSamplerHandle sampler, Llamafu llamafu, int idx) =>
      _llamafuSamplerSample(sampler, llamafu, idx);
  void llamafuSamplerAccept(LlamafuSamplerHandle sampler, int token) => _llamafuSamplerAccept(sampler, token);
  void llamafuSamplerReset(LlamafuSamplerHandle sampler) => _llamafuSamplerReset(sampler);

  // Batch
  LlamafuBatchHandle llamafuBatchInit(int nTokensMax, int embd, int nSeqMax) =>
      _llamafuBatchInit(nTokensMax, embd, nSeqMax);
  void llamafuBatchFree(LlamafuBatchHandle batch) => _llamafuBatchFree(batch);
  void llamafuBatchClear(LlamafuBatchHandle batch) => _llamafuBatchClear(batch);
  int llamafuDecode(Llamafu llamafu, LlamafuBatchHandle batch) => _llamafuDecode(llamafu, batch);

  // Logits
  Pointer<Float> llamafuGetLogits(Llamafu llamafu) => _llamafuGetLogits(llamafu);
  Pointer<Float> llamafuGetLogitsIth(Llamafu llamafu, int i) => _llamafuGetLogitsIth(llamafu, i);

  // Chat session
  int llamafuChatSessionCreate(Llamafu llamafu, Pointer<Utf8> systemPrompt,
          Pointer<LlamafuChatSession> outSession) =>
      _llamafuChatSessionCreate(llamafu, systemPrompt, outSession);
  int llamafuChatSessionComplete(LlamafuChatSession session, Pointer<Utf8> userMessage,
          Pointer<LlamafuMediaInput> mediaInputs, int nMediaInputs,
          Pointer<Pointer<Utf8>> outResponse) =>
      _llamafuChatSessionComplete(session, userMessage, mediaInputs, nMediaInputs, outResponse);
  int llamafuChatSessionGetHistory(LlamafuChatSession session, Pointer<Pointer<Utf8>> outHistoryJson) =>
      _llamafuChatSessionGetHistory(session, outHistoryJson);
  void llamafuChatSessionFree(LlamafuChatSession session) => _llamafuChatSessionFree(session);

  // Text analysis
  int llamafuDetectLanguage(Llamafu llamafu, Pointer<Utf8> text,
          Pointer<Pointer<Utf8>> outLanguageCode, Pointer<Float> outConfidence) =>
      _llamafuDetectLanguage(llamafu, text, outLanguageCode, outConfidence);
  int llamafuAnalyzeSentiment(Llamafu llamafu, Pointer<Utf8> text,
          Pointer<Float> outPositive, Pointer<Float> outNegative, Pointer<Float> outNeutral) =>
      _llamafuAnalyzeSentiment(llamafu, text, outPositive, outNegative, outNeutral);
  int llamafuExtractKeywords(Llamafu llamafu, Pointer<Utf8> text, int maxKeywords,
          Pointer<Pointer<Utf8>> outKeywordsJson) =>
      _llamafuExtractKeywords(llamafu, text, maxKeywords, outKeywordsJson);
  int llamafuTextSummarize(Llamafu llamafu, Pointer<Utf8> text, int maxLength,
          Pointer<Utf8> style, Pointer<Pointer<Utf8>> outSummary) =>
      _llamafuTextSummarize(llamafu, text, maxLength, style, outSummary);

  // Structured output
  int llamafuGenerateStructured(Llamafu llamafu, Pointer<Utf8> prompt,
          Pointer<LlamafuStructuredOutputStruct> outputConfig, Pointer<Pointer<Utf8>> outResult) =>
      _llamafuGenerateStructured(llamafu, prompt, outputConfig, outResult);
  int llamafuValidateJsonSchema(Pointer<Utf8> jsonString, Pointer<Utf8> schema,
          Pointer<Bool> outIsValid, Pointer<Pointer<Utf8>> outErrorMessage) =>
      _llamafuValidateJsonSchema(jsonString, schema, outIsValid, outErrorMessage);
  int llamafuChatApplyTemplate(Llamafu llamafu, Pointer<Utf8> tmpl, Pointer<Pointer<Utf8>> messages,
          int nMessages, bool addAss, Pointer<Pointer<Utf8>> outFormatted) =>
      _llamafuChatApplyTemplate(llamafu, tmpl, messages, nMessages, addAss, outFormatted);

  // Image processing
  int llamafuImageValidate(Pointer<LlamafuMediaInput> input,
          Pointer<LlamafuImageValidationStruct> outValidation) =>
      _llamafuImageValidate(input, outValidation);
  int llamafuImageProcess(Llamafu llamafu, Pointer<LlamafuMediaInput> input,
          Pointer<LlamafuImageProcessResultStruct> outResult) =>
      _llamafuImageProcess(llamafu, input, outResult);
  int llamafuImageResize(Pointer<LlamafuMediaInput> input, int targetWidth, int targetHeight,
          bool maintainAspectRatio, Pointer<LlamafuMediaInput> outResized) =>
      _llamafuImageResize(input, targetWidth, targetHeight, maintainAspectRatio, outResized);
  int llamafuImageToBase64(Pointer<LlamafuMediaInput> input, int format, Pointer<Pointer<Utf8>> outBase64) =>
      _llamafuImageToBase64(input, format, outBase64);

  // Audio processing
  int llamafuAudioProcess(Llamafu llamafu, Pointer<LlamafuMediaInput> input,
          Pointer<LlamafuAudioProcessResultStruct> outResult) =>
      _llamafuAudioProcess(llamafu, input, outResult);
  int llamafuAudioResample(Pointer<Float> inputSamples, int nInputSamples, int inputRate, int targetRate,
          Pointer<Pointer<Float>> outSamples, Pointer<IntPtr> outNSamples) =>
      _llamafuAudioResample(inputSamples, nInputSamples, inputRate, targetRate, outSamples, outNSamples);

  // Enhanced LoRA
  int llamafuGetLoraAdapterInfo(Llamafu llamafu, LlamafuLoraAdapter adapter,
          Pointer<LlamafuLoraAdapterInfoStruct> outInfo) =>
      _llamafuGetLoraAdapterInfo(llamafu, adapter, outInfo);
  int llamafuListLoraAdapters(Llamafu llamafu, Pointer<Pointer<LlamafuLoraAdapterInfoStruct>> outAdapters,
          Pointer<IntPtr> outNAdapters) =>
      _llamafuListLoraAdapters(llamafu, outAdapters, outNAdapters);
  int llamafuValidateLoraCompatibility(Llamafu llamafu, Pointer<Utf8> loraPath,
          Pointer<Bool> outIsCompatible, Pointer<Pointer<Utf8>> outErrorMessage) =>
      _llamafuValidateLoraCompatibility(llamafu, loraPath, outIsCompatible, outErrorMessage);

  // Utility
  void llamafuFreeString(Pointer<Utf8> str) => _llamafuFreeString(str);
  void llamafuFreeTokens(Pointer<Int32> tokens) => _llamafuFreeTokens(tokens);
  void llamafuFreeEmbeddings(Pointer<Float> embeddings) => _llamafuFreeEmbeddings(embeddings);
  Pointer<Utf8> llamafuPrintSystemInfo() => _llamafuPrintSystemInfo();
}