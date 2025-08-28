import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'llamafu_bindings.dart';

/// A Flutter package for running language models on device with support for
/// completion, instruct mode, tool calling, streaming, constrained generation,
/// and LoRA.
class Llamafu {
  late final LlamafuBindings _bindings;
  late final Pointer<LlamafuModelParams> _modelParams;
  late final Pointer<Void> _llamafuInstance;
  final List<LoraAdapter> _loraAdapters = [];
  final List<GrammarSampler> _grammarSamplers = [];

  Llamafu._(this._bindings, this._modelParams, this._llamafuInstance);

  /// Initializes the Llamafu library with the specified model.
  ///
  /// [modelPath] is the path to the GGUF model file.
  /// [mmprojPath] is the optional path to the multi-modal projector file.
  /// [threads] is the number of threads to use for inference (default: 4).
  /// [contextSize] is the context size for the model (default: 512).
  /// [useGpu] whether to use GPU for multi-modal processing (default: false).
  ///
  /// Returns a [Llamafu] instance that can be used for text generation.
  ///
  /// Throws an exception if initialization fails.
  static Future<Llamafu> init({
    required String modelPath,
    String? mmprojPath,  // Multi-modal projector path (optional)
    int threads = 4,
    int contextSize = 512,
    bool useGpu = false,
  }) async {
    final bindings = await LlamafuBindings.init();

    // Allocate and initialize model parameters
    final modelParams = malloc<LlamafuModelParams>();
    modelParams.ref.model_path = modelPath.toNativeUtf8();
    modelParams.ref.mmproj_path = mmprojPath?.toNativeUtf8() ?? nullptr;
    modelParams.ref.n_threads = threads;
    modelParams.ref.n_ctx = contextSize;
    modelParams.ref.use_gpu = useGpu ? 1 : 0;

    // Initialize the native library
    final outLlamafu = malloc<Pointer<Void>>();
    final result = bindings.llamafuInit(modelParams, outLlamafu);

    if (result != 0) {
      malloc.free(modelParams);
      malloc.free(outLlamafu);
      throw Exception('Failed to initialize Llamafu: $result');
    }

    return Llamafu._(bindings, modelParams, outLlamafu.value);
  }

  /// Performs text completion with the loaded model.
  ///
  /// [prompt] is the input text to generate from.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns the generated text.
  ///
  /// Throws an exception if completion fails.
  Future<String> complete({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.8,
  }) async {
    // Allocate and initialize inference parameters
    final inferParams = malloc<LlamafuInferParams>();
    inferParams.ref.prompt = prompt.toNativeUtf8();
    inferParams.ref.max_tokens = maxTokens;
    inferParams.ref.temperature = temperature;

    // Allocate output result
    final outResult = malloc<Pointer<Utf8>>();

    // Perform completion
    final result = _bindings.llamafuComplete(_llamafuInstance, inferParams, outResult);

    // Free inference parameters
    malloc.free(inferParams);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to complete: $result');
    }

    // Convert result to Dart string
    final dartResult = outResult.value.toDartString();
    malloc.free(outResult.value);
    malloc.free(outResult);

    return dartResult;
  }

  /// Performs text completion with grammar constraints.
  ///
  /// [prompt] is the input text to generate from.
  /// [grammarStr] is the GBNF grammar string to constrain generation.
  /// [grammarRoot] is the root symbol of the grammar.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns the generated text that conforms to the specified grammar.
  ///
  /// Throws an exception if completion fails.
  Future<String> completeWithGrammar({
    required String prompt,
    String? grammarStr,
    String? grammarRoot,
    int maxTokens = 128,
    double temperature = 0.8,
  }) async {
    // Allocate and initialize inference parameters
    final inferParams = malloc<LlamafuInferParams>();
    inferParams.ref.prompt = prompt.toNativeUtf8();
    inferParams.ref.max_tokens = maxTokens;
    inferParams.ref.temperature = temperature;

    // Allocate and initialize grammar parameters
    final grammarParams = malloc<LlamafuGrammarParams>();
    grammarParams.ref.grammar_str = grammarStr?.toNativeUtf8() ?? nullptr;
    grammarParams.ref.grammar_root = grammarRoot?.toNativeUtf8() ?? nullptr;

    // Allocate output result
    final outResult = malloc<Pointer<Utf8>>();

    // Perform completion with grammar constraints
    final result = _bindings.llamafuCompleteWithGrammar(_llamafuInstance, inferParams, grammarParams, outResult);

    // Free inference parameters
    malloc.free(inferParams);
    
    // Free grammar parameters
    if (grammarStr != null) malloc.free(grammarParams.ref.grammar_str);
    if (grammarRoot != null) malloc.free(grammarParams.ref.grammar_root);
    malloc.free(grammarParams);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to complete with grammar: $result');
    }

    // Convert result to Dart string
    final dartResult = outResult.value.toDartString();
    malloc.free(outResult.value);
    malloc.free(outResult);

    return dartResult;
  }

  /// Performs multi-modal completion with text and media inputs.
  ///
  /// [prompt] is the input text prompt that may contain media placeholders.
  /// [mediaInputs] is a list of [MediaInput] objects containing media data.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns the generated text based on both text and media inputs.
  ///
  /// Throws an exception if multi-modal completion fails.
  Future<String> multimodalComplete({
    required String prompt,
    List<MediaInput> mediaInputs = const [],
    int maxTokens = 128,
    double temperature = 0.8,
  }) async {
    // Allocate and initialize multi-modal inference parameters
    final multimodalParams = malloc<LlamafuMultimodalInferParams>();
    multimodalParams.ref.prompt = prompt.toNativeUtf8();
    multimodalParams.ref.n_media_inputs = mediaInputs.length;
    multimodalParams.ref.max_tokens = maxTokens;
    multimodalParams.ref.temperature = temperature;

    // Allocate media inputs array
    if (mediaInputs.isNotEmpty) {
      final mediaInputsArray = malloc<LlamafuMediaInput>(mediaInputs.length);
      for (int i = 0; i < mediaInputs.length; i++) {
        mediaInputsArray[i].type = mediaInputs[i].type.index;
        mediaInputsArray[i].data = mediaInputs[i].data.toNativeUtf8();
        mediaInputsArray[i].data_size = mediaInputs[i].data.length;
      }
      multimodalParams.ref.media_inputs = mediaInputsArray;
    } else {
      multimodalParams.ref.media_inputs = nullptr;
    }

    // Allocate output result
    final outResult = malloc<Pointer<Utf8>>();

    // Perform multi-modal completion
    final result = _bindings.llamafuMultimodalComplete(_llamafuInstance, multimodalParams, outResult);

    // Free media inputs array
    if (mediaInputs.isNotEmpty) {
      malloc.free(multimodalParams.ref.media_inputs);
    }

    // Free inference parameters
    malloc.free(multimodalParams);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to complete multi-modal inference: $result');
    }

    // Convert result to Dart string
    final dartResult = outResult.value.toDartString();
    malloc.free(outResult.value);
    malloc.free(outResult);

    return dartResult;
  }

  /// Loads a LoRA adapter from the specified file path.
  ///
  /// [loraPath] is the path to the LoRA adapter GGUF file.
  ///
  /// Returns a [LoraAdapter] instance that can be applied to the model.
  ///
  /// Throws an exception if the LoRA adapter fails to load.
  Future<LoraAdapter> loadLoraAdapter(String loraPath) async {
    final loraPathPtr = loraPath.toNativeUtf8();
    final outAdapter = malloc<Pointer<Void>>();

    final result = _bindings.llamafuLoraAdapterInit(_llamafuInstance, loraPathPtr, outAdapter);

    malloc.free(loraPathPtr);

    if (result != 0) {
      malloc.free(outAdapter);
      throw Exception('Failed to load LoRA adapter: $result');
    }

    final adapter = LoraAdapter._(_bindings, outAdapter.value);
    _loraAdapters.add(adapter);
    return adapter;
  }

  /// Applies a LoRA adapter to the model with the specified scale.
  ///
  /// [adapter] is the LoRA adapter to apply.
  /// [scale] is the scaling factor for the adapter (default: 1.0).
  ///
  /// Throws an exception if the LoRA adapter fails to apply.
  Future<void> applyLoraAdapter(LoraAdapter adapter, {double scale = 1.0}) async {
    final result = _bindings.llamafuLoraAdapterApply(_llamafuInstance, adapter._nativeAdapter, scale);
    if (result != 0) {
      throw Exception('Failed to apply LoRA adapter: $result');
    }
  }

  /// Removes a LoRA adapter from the model.
  ///
  /// [adapter] is the LoRA adapter to remove.
  ///
  /// Throws an exception if the LoRA adapter fails to remove.
  Future<void> removeLoraAdapter(LoraAdapter adapter) async {
    final result = _bindings.llamafuLoraAdapterRemove(_llamafuInstance, adapter._nativeAdapter);
    if (result != 0) {
      throw Exception('Failed to remove LoRA adapter: $result');
    }
  }

  /// Clears all LoRA adapters from the model.
  ///
  /// Throws an exception if clearing the adapters fails.
  Future<void> clearAllLoraAdapters() async {
    final result = _bindings.llamafuLoraAdapterClearAll(_llamafuInstance);
    if (result != 0) {
      throw Exception('Failed to clear LoRA adapters: $result');
    }
    
    // Free all adapter references
    for (final adapter in _loraAdapters) {
      _bindings.llamafuLoraAdapterFree(adapter._nativeAdapter);
    }
    _loraAdapters.clear();
  }

  /// Creates a grammar sampler for constrained generation.
  ///
  /// [grammarStr] is the GBNF grammar string to constrain generation.
  /// [grammarRoot] is the root symbol of the grammar.
  ///
  /// Returns a [GrammarSampler] instance that can be used for constrained generation.
  ///
  /// Throws an exception if the grammar sampler fails to initialize.
  Future<GrammarSampler> createGrammarSampler(String grammarStr, String grammarRoot) async {
    final grammarStrPtr = grammarStr.toNativeUtf8();
    final grammarRootPtr = grammarRoot.toNativeUtf8();
    final outSampler = malloc<Pointer<Void>>();

    final result = _bindings.llamafuGrammarSamplerInit(
        _llamafuInstance, grammarStrPtr, grammarRootPtr, outSampler);

    malloc.free(grammarStrPtr);
    malloc.free(grammarRootPtr);

    if (result != 0) {
      malloc.free(outSampler);
      throw Exception('Failed to create grammar sampler: $result');
    }

    final sampler = GrammarSampler._(_bindings, outSampler.value);
    _grammarSamplers.add(sampler);
    return sampler;
  }

  /// Cleans up resources and frees memory used by the Llamafu instance.
  ///
  /// This method should be called when the Llamafu instance is no longer needed
  /// to prevent memory leaks.
  void close() {
    // Free all LoRA adapters
    for (final adapter in _loraAdapters) {
      _bindings.llamafuLoraAdapterFree(adapter._nativeAdapter);
    }
    _loraAdapters.clear();
    
    // Free all grammar samplers
    for (final sampler in _grammarSamplers) {
      _bindings.llamafuGrammarSamplerFree(sampler._nativeSampler);
    }
    _grammarSamplers.clear();
    
    _bindings.llamafuFree(_llamafuInstance);
    malloc.free(_modelParams);
  }
}

/// Media input types for multi-modal inference.
enum MediaType {
  /// Text input type.
  text,
  
  /// Image input type.
  image,
  
  /// Audio input type.
  audio,
}

/// Represents a media input for multi-modal inference.
class MediaInput {
  /// The type of media input.
  final MediaType type;
  
  /// The data for the media input, either a file path or base64 encoded data.
  final String data;

  /// Creates a new media input.
  ///
  /// [type] is the type of media input.
  /// [data] is the data for the media input, either a file path or base64 encoded data.
  MediaInput({required this.type, required this.data});
}

/// Represents a LoRA adapter that can be applied to a Llamafu model.
class LoraAdapter {
  final LlamafuBindings _bindings;
  final Pointer<Void> _nativeAdapter;

  LoraAdapter._(this._bindings, this._nativeAdapter);
}

/// Represents a grammar sampler for constrained generation.
class GrammarSampler {
  final LlamafuBindings _bindings;
  final Pointer<Void> _nativeSampler;

  GrammarSampler._(this._bindings, this._nativeSampler);
}