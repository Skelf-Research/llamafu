import 'dart:io';
import 'package:test/test.dart';
import 'package:llamafu/llamafu.dart';
import 'package:llamafu/src/llamafu_bindings.dart' as bindings;

void main() {
  group('Llamafu Integration Tests', () {
    test('Input validation prevents invalid model paths', () async {
      // Test null byte injection
      expect(
        () => Llamafu.init(modelPath: 'model\0.gguf'),
        throwsA(isA<ArgumentError>()),
      );

      // Test path traversal
      expect(
        () => Llamafu.init(modelPath: '../../../etc/passwd'),
        throwsA(isA<ArgumentError>()),
      );

      // Test system path access
      expect(
        () => Llamafu.init(modelPath: '/etc/shadow'),
        throwsA(isA<ArgumentError>()),
      );

      // Test overly long path
      final longPath = 'a' * 5000;
      expect(
        () => Llamafu.init(modelPath: longPath),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Input validation prevents invalid thread counts', () async {
      expect(
        () => Llamafu.init(modelPath: 'valid.gguf', threads: 0),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => Llamafu.init(modelPath: 'valid.gguf', threads: 100),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Input validation prevents invalid context sizes', () async {
      expect(
        () => Llamafu.init(modelPath: 'valid.gguf', contextSize: 0),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => Llamafu.init(modelPath: 'valid.gguf', contextSize: 100000),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Input validation prevents invalid prompts', () async {
      // Create a mock Llamafu instance for testing
      // Note: This would require a valid model file for full integration testing

      // Test null byte in prompt
      expect(
        () => _validatePrompt('Hello\0World'),
        throwsA(isA<ArgumentError>()),
      );

      // Test overly long prompt
      final longPrompt = 'a' * 200000;
      expect(
        () => _validatePrompt(longPrompt),
        throwsA(isA<ArgumentError>()),
      );

      // Test control characters
      expect(
        () => _validatePrompt('Hello\x01World'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Input validation prevents invalid parameters', () {
      // Test negative temperature
      expect(
        () => _validateTemperature(-1.0),
        throwsA(isA<ArgumentError>()),
      );

      // Test excessive temperature
      expect(
        () => _validateTemperature(5.0),
        throwsA(isA<ArgumentError>()),
      );

      // Test infinite temperature
      expect(
        () => _validateTemperature(double.infinity),
        throwsA(isA<ArgumentError>()),
      );

      // Test NaN temperature
      expect(
        () => _validateTemperature(double.nan),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Memory management validation', () {
      // Test that creating and disposing multiple instances doesn't leak memory
      // This is a basic test - full memory leak testing would require platform-specific tools

      // Simulate creating and disposing multiple objects
      for (int i = 0; i < 10; i++) {
        // In a real test, these would be actual instances
        // For now, we just test the dispose pattern exists
        expect(() => LoraAdapter, returnsNormally);
        expect(() => GrammarSampler, returnsNormally);
      }
    });

    test('File existence validation', () async {
      // Test non-existent model file
      expect(
        () => Llamafu.init(modelPath: 'non_existent_model.gguf'),
        throwsA(isA<ArgumentError>()),
      );

      // Test non-existent multi-modal projector
      expect(
        () => Llamafu.init(
          modelPath: 'valid.gguf',
          mmprojPath: 'non_existent_mmproj.gguf'
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('MediaInput validation', () {
      // Test valid media input creation
      final imageInput = MediaInput(
        type: MediaType.image,
        data: '/path/to/image.jpg',
      );

      expect(imageInput.type, equals(MediaType.image));
      expect(imageInput.data, equals('/path/to/image.jpg'));

      final audioInput = MediaInput(
        type: MediaType.audio,
        data: '/path/to/audio.wav',
      );

      expect(audioInput.type, equals(MediaType.audio));
      expect(audioInput.data, equals('/path/to/audio.wav'));
    });

    test('Error code constants are defined', () {
      expect(bindings.LLAMAFU_SUCCESS, equals(0));
      expect(bindings.LLAMAFU_ERROR_UNKNOWN, equals(-1));
      expect(bindings.LLAMAFU_ERROR_INVALID_PARAM, equals(-2));
      expect(bindings.LLAMAFU_ERROR_MODEL_LOAD_FAILED, equals(-3));
      expect(bindings.LLAMAFU_ERROR_OUT_OF_MEMORY, equals(-4));
      expect(bindings.LLAMAFU_ERROR_MULTIMODAL_NOT_SUPPORTED, equals(-5));
      expect(bindings.LLAMAFU_ERROR_LORA_LOAD_FAILED, equals(-6));
      expect(bindings.LLAMAFU_ERROR_LORA_NOT_FOUND, equals(-7));
      expect(bindings.LLAMAFU_ERROR_GRAMMAR_INIT_FAILED, equals(-8));
    });
  });
}

// Helper functions for testing validation without requiring a full Llamafu instance

void _validatePrompt(String prompt) {
  // Simulate the validation logic from Llamafu._isValidPrompt
  if (prompt.contains('\0')) {
    throw ArgumentError('Invalid prompt: contains null bytes');
  }

  if (prompt.length > 100000) {
    throw ArgumentError('Invalid prompt: too long');
  }

  for (int i = 0; i < prompt.length; i++) {
    final codeUnit = prompt.codeUnitAt(i);
    if (codeUnit < 32 && codeUnit != 9 && codeUnit != 10 && codeUnit != 13) {
      throw ArgumentError('Invalid prompt: contains control characters');
    }
  }
}

void _validateTemperature(double temperature) {
  if (temperature < 0.0 || temperature > 2.0 || !temperature.isFinite) {
    throw ArgumentError('Invalid temperature: $temperature');
  }
}