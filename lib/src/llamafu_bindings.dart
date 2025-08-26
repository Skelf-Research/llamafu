import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Define the native types
typedef Llamafu = Pointer<Void>;
typedef LlamafuError = Int32;

// Error codes
const int LLAMAFU_SUCCESS = 0;
const int LLAMAFU_ERROR_UNKNOWN = -1;
const int LLAMAFU_ERROR_INVALID_PARAM = -2;
const int LLAMAFU_ERROR_MODEL_LOAD_FAILED = -3;
const int LLAMAFU_ERROR_OUT_OF_MEMORY = -4;

// Model parameters structure
class LlamafuModelParams extends Struct {
  external Pointer<Utf8> model_path;
  external Int32 n_threads;
  external Int32 n_ctx;
}

// Inference parameters structure
class LlamafuInferParams extends Struct {
  external Pointer<Utf8> prompt;
  external Int32 max_tokens;
  external Float temperature;
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

typedef LlamafuFreeC = Void Function(Llamafu llamafu);
typedef LlamafuFreeDart = void Function(Llamafu llamafu);

class LlamafuBindings {
  final DynamicLibrary _dylib;
  late final LlamafuInitDart _llamafuInit;
  late final LlamafuCompleteDart _llamafuComplete;
  late final LlamafuCompleteStreamDart _llamafuCompleteStream;
  late final LlamafuFreeDart _llamafuFree;

  LlamafuBindings._(this._dylib) {
    _llamafuInit = _dylib
        .lookup<NativeFunction<LlamafuInitC>>('llamafu_init')
        .asFunction<LlamafuInitDart>();
    _llamafuComplete = _dylib
        .lookup<NativeFunction<LlamafuCompleteC>>('llamafu_complete')
        .asFunction<LlamafuCompleteDart>();
    _llamafuCompleteStream = _dylib
        .lookup<NativeFunction<LlamafuCompleteStreamC>>('llamafu_complete_stream')
        .asFunction<LlamafuCompleteStreamDart>();
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

  int llamafuCompleteStream(
      Llamafu llamafu,
      Pointer<LlamafuInferParams> params,
      Pointer<NativeFunction<LlamafuStreamCallbackC>> callback,
      Pointer<Void> user_data) {
    return _llamafuCompleteStream(llamafu, params, callback, user_data);
  }

  void llamafuFree(Llamafu llamafu) {
    _llamafuFree(llamafu);
  }
}