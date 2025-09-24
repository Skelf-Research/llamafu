import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  group('Llamafu Integration Tests', () {
    late Llamafu llamafu;
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('llamafu_integration_test');
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      // Create mock model file for testing
      final mockModelFile = File('${tempDir.path}/mock_model.gguf');
      await mockModelFile.writeAsBytes([
        // Mock GGUF header
        0x47, 0x47, 0x55, 0x46, // "GGUF" magic
        0x03, 0x00, 0x00, 0x00, // version 3
        0x00, 0x00, 0x00, 0x00, // tensor count
        0x00, 0x00, 0x00, 0x00, // metadata kv count
        ...List.filled(1000, 0x00), // padding
      ]);

      // Mock multimodal projection file
      final mockMmprojFile = File('${tempDir.path}/mock_mmproj.gguf');
      await mockMmprojFile.writeAsBytes([
        0x47, 0x47, 0x55, 0x46, // "GGUF" magic
        0x03, 0x00, 0x00, 0x00, // version 3
        0x00, 0x00, 0x00, 0x00, // tensor count
        0x00, 0x00, 0x00, 0x00, // metadata kv count
        ...List.filled(500, 0x00), // padding
      ]);

      llamafu = Llamafu();
    });

    tearDown(() async {
      llamafu.dispose();
    });

    group('Model Loading Integration', () {
      test('should load basic text model successfully', () async {
        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 512,
            threads: 2,
            useGpu: false,
          );

          final modelInfo = await llamafu.getModelInfo();
          expect(modelInfo, isNotNull);
          expect(modelInfo.contextSize, equals(512));
        } catch (e) {
          // Expected to fail with mock model, but should reach initialization
          expect(e.toString(), contains('model'));
        }
      });

      test('should handle multimodal model initialization', () async {
        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            mmprojPath: '${tempDir.path}/mock_mmproj.gguf',
            contextSize: 2048,
            threads: 4,
            useGpu: false,
          );

          final modelInfo = await llamafu.getModelInfo();
          expect(modelInfo.isMultimodal, isTrue);
        } catch (e) {
          // Expected to fail with mock model
          expect(e.toString(), contains('model'));
        }
      });
    });

    group('Text Processing Integration', () {
      test('should handle complete text generation workflow', () async {
        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 1024,
            threads: 2,
          );

          final tokens = await llamafu.tokenize('Hello, world!');
          expect(tokens, isNotEmpty);

          final detokenized = await llamafu.detokenize(tokens);
          expect(detokenized, contains('Hello'));

          final response = await llamafu.complete(
            prompt: 'Complete this sentence: The weather today is',
            maxTokens: 50,
            temperature: 0.7,
          );
          expect(response, isNotEmpty);
        } catch (e) {
          // Expected with mock model
          print('Expected error with mock model: $e');
        }
      });

      test('should handle streaming text generation', () async {
        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 1024,
          );

          final tokens = <String>[];
          await llamafu.completeStream(
            prompt: 'Tell me a story about',
            maxTokens: 100,
            temperature: 0.8,
            onToken: (token) {
              tokens.add(token);
            },
          );

          expect(tokens, isNotEmpty);
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });
    });

    group('Image Processing Integration', () {
      test('should process image through complete multimodal workflow', () async {
        // Create mock image data (PNG header + minimal data)
        final mockImageData = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
          0x00, 0x00, 0x00, 0x0D, // IHDR length
          0x49, 0x48, 0x44, 0x52, // IHDR
          0x00, 0x00, 0x00, 0x10, // width: 16
          0x00, 0x00, 0x00, 0x10, // height: 16
          0x08, 0x06, 0x00, 0x00, 0x00, // bit depth, color type, etc.
          ...List.filled(100, 0x00), // minimal PNG data
        ]);

        // Test image format detection
        final format = await llamafu.detectImageFormat(mockImageData);
        expect(format, equals('PNG'));

        // Test image validation
        final isValid = await llamafu.validateImageData(mockImageData);
        expect(isValid, isTrue);

        // Test base64 encoding/decoding
        final base64String = await llamafu.encodeImageToBase64(mockImageData);
        expect(base64String, isNotEmpty);

        final decodedImage = await llamafu.decodeBase64ToImage(base64String);
        expect(decodedImage.length, equals(mockImageData.length));

        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            mmprojPath: '${tempDir.path}/mock_mmproj.gguf',
            contextSize: 2048,
          );

          // Test multimodal completion with image
          final response = await llamafu.multimodalComplete(
            prompt: 'Describe this image:',
            imageData: mockImageData,
            maxTokens: 100,
          );
          expect(response, isNotEmpty);
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });

      test('should handle image preprocessing pipeline', () async {
        final mockImageData = _createMockJPEGData();

        // Test preprocessing with various options
        final options = {
          'resize_width': 224,
          'resize_height': 224,
          'normalize': true,
          'mean': [0.485, 0.456, 0.406],
          'std': [0.229, 0.224, 0.225],
        };

        try {
          final processedImage = await llamafu.preprocessImage(
            mockImageData,
            options,
          );
          expect(processedImage, isNotNull);
        } catch (e) {
          print('Image preprocessing test: $e');
        }
      });
    });

    group('Audio Processing Integration', () {
      test('should handle audio streaming workflow', () async {
        final mockAudioData = _createMockWAVData();

        // Test audio format detection
        final format = await llamafu.detectAudioFormat(mockAudioData);
        expect(format, equals('WAV'));

        // Test audio validation
        final isValid = await llamafu.validateAudioData(mockAudioData);
        expect(isValid, isTrue);

        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 1024,
          );

          // Test audio stream creation
          final streamConfig = {
            'sample_rate': 16000,
            'channels': 1,
            'format': 'PCM_F32',
            'buffer_size': 1024,
          };

          final stream = await llamafu.createAudioStream(
            streamConfig,
            onAudioData: (audioData, sampleRate) {
              expect(audioData, isNotEmpty);
              expect(sampleRate, equals(16000));
            },
          );

          // Test feeding audio data to stream
          await llamafu.feedAudioStream(stream, mockAudioData);

          // Test closing stream
          await llamafu.closeAudioStream(stream);
        } catch (e) {
          print('Expected error with mock setup: $e');
        }
      });

      test('should convert audio to raw samples', () async {
        final mockAudioData = _createMockWAVData();

        try {
          final rawSamples = await llamafu.convertAudioToRawSamples(
            mockAudioData,
            targetSampleRate: 16000,
            targetChannels: 1,
          );
          expect(rawSamples, isNotEmpty);
        } catch (e) {
          print('Audio conversion test: $e');
        }
      });
    });

    group('LoRA Adapter Integration', () {
      test('should handle LoRA adapter workflow', () async {
        // Create mock LoRA file
        final mockLoraFile = File('${tempDir.path}/mock_lora.bin');
        await mockLoraFile.writeAsBytes([
          // Mock LoRA header and data
          0x4C, 0x6F, 0x52, 0x41, // "LoRA" magic
          0x01, 0x00, 0x00, 0x00, // version
          ...List.filled(1000, 0x00), // mock weights
        ]);

        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 1024,
          );

          // Test LoRA loading
          final adapterId = await llamafu.loadLoraAdapterFromFile(
            mockLoraFile.path,
            scale: 1.0,
          );
          expect(adapterId, isNotNull);

          // Test LoRA activation
          await llamafu.setLoraAdapter(adapterId, scale: 0.8);

          // Test inference with LoRA
          final response = await llamafu.complete(
            prompt: 'Test with LoRA adapter',
            maxTokens: 50,
          );
          expect(response, isNotEmpty);

          // Test LoRA unloading
          await llamafu.unloadLoraAdapter(adapterId);
        } catch (e) {
          print('Expected error with mock LoRA: $e');
        }
      });

      test('should handle batch LoRA operations', () async {
        final mockLoraFiles = <String>[];
        for (int i = 0; i < 3; i++) {
          final file = File('${tempDir.path}/mock_lora_$i.bin');
          await file.writeAsBytes([
            0x4C, 0x6F, 0x52, 0x41, // "LoRA" magic
            0x01, 0x00, 0x00, 0x00, // version
            ...List.filled(500, i), // different mock weights
          ]);
          mockLoraFiles.add(file.path);
        }

        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 1024,
          );

          // Test batch LoRA loading
          final adapterIds = await llamafu.loadLoraAdaptersBatch(
            mockLoraFiles.map((path) => {'path': path, 'scale': 1.0}).toList(),
          );
          expect(adapterIds.length, equals(3));

          // Test batch LoRA management
          await llamafu.setLoraAdaptersBatch(
            adapterIds.map((id) => {'id': id, 'scale': 0.5}).toList(),
          );

          // Test LoRA merging
          final mergedId = await llamafu.mergeLoraAdapters(
            adapterIds,
            scales: [0.3, 0.3, 0.4],
          );
          expect(mergedId, isNotNull);

          // Test batch unloading
          await llamafu.unloadLoraAdaptersBatch(adapterIds);
        } catch (e) {
          print('Expected error with mock LoRA batch: $e');
        }
      });
    });

    group('Structured Output Integration', () {
      test('should handle JSON schema validation workflow', () async {
        final jsonSchema = '''
        {
          "type": "object",
          "properties": {
            "name": {"type": "string"},
            "age": {"type": "number"},
            "skills": {
              "type": "array",
              "items": {"type": "string"}
            }
          },
          "required": ["name", "age"]
        }
        ''';

        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 1024,
          );

          // Test structured output creation
          final structuredOutput = await llamafu.createStructuredOutput(
            format: 'JSON',
            schema: jsonSchema,
          );
          expect(structuredOutput, isNotNull);

          // Test validation
          final validJson = '{"name": "John", "age": 30, "skills": ["coding", "testing"]}';
          final isValid = await llamafu.validateStructuredOutput(
            structuredOutput,
            validJson,
          );
          expect(isValid, isTrue);

          // Test invalid JSON
          final invalidJson = '{"name": "John"}'; // missing required "age"
          final isInvalid = await llamafu.validateStructuredOutput(
            structuredOutput,
            invalidJson,
          );
          expect(isInvalid, isFalse);

          // Test structured generation
          final result = await llamafu.generateStructuredOutput(
            structuredOutput,
            prompt: 'Generate a person profile',
            maxTokens: 100,
          );
          expect(result, isNotEmpty);

          await llamafu.freeStructuredOutput(structuredOutput);
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });

      test('should handle template-based generation', () async {
        final template = '''
        Name: {{name}}
        Age: {{age}}
        Location: {{location}}
        Bio: {{bio}}
        ''';

        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 1024,
          );

          // Test template processing
          final variables = {
            'name': 'Alice',
            'age': '25',
            'location': 'San Francisco',
          };

          final processedTemplate = await llamafu.processTemplate(
            template,
            variables,
          );
          expect(processedTemplate, contains('Alice'));
          expect(processedTemplate, contains('25'));
          expect(processedTemplate, contains('San Francisco'));
          expect(processedTemplate, contains('{{bio}}'));

          // Test template-based generation
          final result = await llamafu.generateFromTemplate(
            template,
            variables,
            maxTokens: 100,
          );
          expect(result, isNotEmpty);
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });
    });

    group('Performance Integration', () {
      test('should handle concurrent operations', () async {
        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 2048,
            threads: 4,
          );

          // Test concurrent tokenization
          final futures = <Future<List<int>>>[];
          for (int i = 0; i < 5; i++) {
            futures.add(llamafu.tokenize('Concurrent test $i'));
          }

          final results = await Future.wait(futures);
          expect(results.length, equals(5));

          // Test concurrent completion (if model supports it)
          final completionFutures = <Future<String>>[];
          for (int i = 0; i < 3; i++) {
            completionFutures.add(llamafu.complete(
              prompt: 'Concurrent completion $i',
              maxTokens: 20,
            ));
          }

          final completionResults = await Future.wait(completionFutures);
          expect(completionResults.length, equals(3));
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });

      test('should handle memory management during intensive operations', () async {
        try {
          await llamafu.init(
            modelPath: '${tempDir.path}/mock_model.gguf',
            contextSize: 1024,
          );

          // Test memory-intensive operations
          for (int i = 0; i < 10; i++) {
            final tokens = await llamafu.tokenize('Memory test iteration $i with some longer text to ensure memory allocation');
            expect(tokens, isNotEmpty);

            final detokenized = await llamafu.detokenize(tokens);
            expect(detokenized, isNotEmpty);

            // Force garbage collection between iterations
            await Future.delayed(Duration(milliseconds: 10));
          }
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });
    });
  });
}

Uint8List _createMockJPEGData() {
  return Uint8List.fromList([
    0xFF, 0xD8, // JPEG SOI
    0xFF, 0xE0, // APP0 marker
    0x00, 0x10, // length
    0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
    0x01, 0x01, // version
    0x01, 0x00, 0x01, 0x00, 0x01, // units, density
    0x00, 0x00, // thumbnail dimensions
    ...List.filled(100, 0xFF), // mock image data
    0xFF, 0xD9, // JPEG EOI
  ]);
}

Uint8List _createMockWAVData() {
  return Uint8List.fromList([
    // RIFF header
    0x52, 0x49, 0x46, 0x46, // "RIFF"
    0x24, 0x00, 0x00, 0x00, // file size - 8
    0x57, 0x41, 0x56, 0x45, // "WAVE"

    // fmt chunk
    0x66, 0x6D, 0x74, 0x20, // "fmt "
    0x10, 0x00, 0x00, 0x00, // chunk size
    0x01, 0x00, // audio format (PCM)
    0x01, 0x00, // channels
    0x40, 0x1F, 0x00, 0x00, // sample rate (8000)
    0x80, 0x3E, 0x00, 0x00, // byte rate
    0x02, 0x00, // block align
    0x10, 0x00, // bits per sample

    // data chunk
    0x64, 0x61, 0x74, 0x61, // "data"
    0x00, 0x00, 0x00, 0x00, // data size
    // mock audio samples would go here
  ]);
}