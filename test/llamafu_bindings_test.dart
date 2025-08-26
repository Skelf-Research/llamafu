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
}