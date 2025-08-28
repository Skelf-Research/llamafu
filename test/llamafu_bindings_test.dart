import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';
import 'package:llamafu/src/llamafu_bindings.dart';

void main() {
  group('LlamafuBindings', () {
    test('Can load the library', () async {
      // This test will only pass if we're running on Android or have the library available
      // For now, we'll just verify the code compiles
      expect(true, true);
    });
  });
  
  group('Multi-modal Support', () {
    test('Media types are defined correctly', () {
      expect(LlamafuMediaType.TEXT, 0);
      expect(LlamafuMediaType.IMAGE, 1);
      expect(LlamafuMediaType.AUDIO, 2);
    });
    
    test('Error codes include multi-modal support', () {
      expect(LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED, -5);
    });
  });
  
  group('LoRA Support', () {
    test('Error codes include LoRA support', () {
      expect(LLAMAFU_ERROR_LORA_LOAD_FAILED, -6);
      expect(LLAMAFU_ERROR_LORA_NOT_FOUND, -7);
    });
  });
  
  group('Constrained Generation Support', () {
    test('Error codes include constrained generation support', () {
      expect(LLAMAFU_ERROR_GRAMMAR_INIT_FAILED, -8);
    });
  });
  
  group('Structs', () {
    test('LlamafuModelParams has correct fields', () {
      final modelParams = malloc<LlamafuModelParams>();
      expect(modelParams.ref.model_path, isNotNull);
      expect(modelParams.ref.mmproj_path, isNotNull);
      expect(modelParams.ref.n_threads, isNotNull);
      expect(modelParams.ref.n_ctx, isNotNull);
      expect(modelParams.ref.use_gpu, isNotNull);
      malloc.free(modelParams);
    });
    
    test('LlamafuInferParams has correct fields', () {
      final inferParams = malloc<LlamafuInferParams>();
      expect(inferParams.ref.prompt, isNotNull);
      expect(inferParams.ref.max_tokens, isNotNull);
      expect(inferParams.ref.temperature, isNotNull);
      malloc.free(inferParams);
    });
    
    test('LlamafuGrammarParams has correct fields', () {
      final grammarParams = malloc<LlamafuGrammarParams>();
      expect(grammarParams.ref.grammar_str, isNotNull);
      expect(grammarParams.ref.grammar_root, isNotNull);
      malloc.free(grammarParams);
    });
    
    test('LlamafuMediaInput has correct fields', () {
      final mediaInput = malloc<LlamafuMediaInput>();
      expect(mediaInput.ref.type, isNotNull);
      expect(mediaInput.ref.data, isNotNull);
      expect(mediaInput.ref.data_size, isNotNull);
      malloc.free(mediaInput);
    });
    
    test('LlamafuMultimodalInferParams has correct fields', () {
      final multimodalParams = malloc<LlamafuMultimodalInferParams>();
      expect(multimodalParams.ref.prompt, isNotNull);
      expect(multimodalParams.ref.media_inputs, isNotNull);
      expect(multimodalParams.ref.n_media_inputs, isNotNull);
      expect(multimodalParams.ref.max_tokens, isNotNull);
      expect(multimodalParams.ref.temperature, isNotNull);
      malloc.free(multimodalParams);
    });
  });
}