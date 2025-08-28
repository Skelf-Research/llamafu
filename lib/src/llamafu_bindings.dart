import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

/// Opaque handle to the Llamafu instance.
typedef Llamafu = Pointer<Void>;

/// Opaque handle to the LoRA adapter.
typedef LlamafuLoraAdapter = Pointer<Void>;

/// Opaque handle to the grammar sampler.
typedef LlamafuGrammarSampler = Pointer<Void>;

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

final class LlamafuBindings {
  final DynamicLibrary _dylib;
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
}