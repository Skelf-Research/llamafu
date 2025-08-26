import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'llamafu_bindings.dart';

class Llamafu {
  late final LlamafuBindings _bindings;
  late final Pointer<LlamafuModelParams> _modelParams;
  late final Pointer<Void> _llamafuInstance;

  Llamafu._(this._bindings, this._modelParams, this._llamafuInstance);

  static Future<Llamafu> init({
    required String modelPath,
    int threads = 4,
    int contextSize = 512,
  }) async {
    final bindings = await LlamafuBindings.init();

    // Allocate and initialize model parameters
    final modelParams = malloc<LlamafuModelParams>();
    modelParams.ref.model_path = modelPath.toNativeUtf8();
    modelParams.ref.n_threads = threads;
    modelParams.ref.n_ctx = contextSize;

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

  void close() {
    _bindings.llamafuFree(_llamafuInstance);
    malloc.free(_modelParams);
  }
}