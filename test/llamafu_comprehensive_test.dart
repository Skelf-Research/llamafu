import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:test/test.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  group('Llamafu Comprehensive Test Suite', () {

    // =========================================================================
    // CORE FUNCTIONALITY TESTS
    // =========================================================================

    group('Core API Tests', () {
      test('Library initialization and basic properties', () {
        expect(Llamafu, isNotNull);
        expect(MediaType.values.length, greaterThan(2));
        expect(ErrorCode.values.length, greaterThan(10));
      });

      test('Model parameter validation', () {
        expect(
          () => Llamafu.init(modelPath: ''),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => Llamafu.init(modelPath: 'valid.gguf', threads: -1),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => Llamafu.init(modelPath: 'valid.gguf', threads: 1000),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('Context size validation', () {
        expect(
          () => Llamafu.init(modelPath: 'valid.gguf', contextSize: 0),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => Llamafu.init(modelPath: 'valid.gguf', contextSize: 1000000),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // =========================================================================
    // IMAGE PROCESSING TESTS
    // =========================================================================

    group('Image Processing Tests', () {
      test('MediaInput creation for images', () {
        final imageInput = MediaInput(
          type: MediaType.image,
          data: '/path/to/image.jpg',
          format: ImageFormat.jpeg,
          width: 1920,
          height: 1080,
        );

        expect(imageInput.type, equals(MediaType.image));
        expect(imageInput.data, equals('/path/to/image.jpg'));
        expect(imageInput.format, equals(ImageFormat.jpeg));
        expect(imageInput.width, equals(1920));
        expect(imageInput.height, equals(1080));
      });

      test('Image format detection', () {
        expect(ImageFormat.auto.toString(), contains('auto'));
        expect(ImageFormat.jpeg.toString(), contains('jpeg'));
        expect(ImageFormat.png.toString(), contains('png'));
        expect(ImageFormat.webp.toString(), contains('webp'));
      });

      test('Base64 image input validation', () {
        final base64Input = MediaInput(
          type: MediaType.image,
          data: 'data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEA...',
          sourceType: DataSource.base64,
          format: ImageFormat.jpeg,
        );

        expect(base64Input.sourceType, equals(DataSource.base64));
        expect(base64Input.data, startsWith('data:image/jpeg'));
      });

      test('Image validation parameters', () {
        final validationConfig = ImageValidation(
          maxWidth: 4096,
          maxHeight: 4096,
          allowedFormats: [ImageFormat.jpeg, ImageFormat.png],
          maxFileSizeBytes: 10 * 1024 * 1024, // 10MB
        );

        expect(validationConfig.maxWidth, equals(4096));
        expect(validationConfig.allowedFormats.length, equals(2));
        expect(validationConfig.maxFileSizeBytes, equals(10 * 1024 * 1024));
      });

      test('Image processing options', () {
        final processingOptions = ImageProcessingOptions(
          resizeToModel: true,
          maintainAspectRatio: true,
          padToSquare: false,
          qualityHint: 0.8,
        );

        expect(processingOptions.resizeToModel, isTrue);
        expect(processingOptions.maintainAspectRatio, isTrue);
        expect(processingOptions.padToSquare, isFalse);
        expect(processingOptions.qualityHint, equals(0.8));
      });
    });

    // =========================================================================
    // AUDIO PROCESSING TESTS
    // =========================================================================

    group('Audio Processing Tests', () {
      test('MediaInput creation for audio', () {
        final audioInput = MediaInput(
          type: MediaType.audio,
          data: '/path/to/audio.wav',
          audioFormat: AudioFormat.wav,
          sampleRate: 44100,
          channels: 2,
          durationMs: 30000,
        );

        expect(audioInput.type, equals(MediaType.audio));
        expect(audioInput.audioFormat, equals(AudioFormat.wav));
        expect(audioInput.sampleRate, equals(44100));
        expect(audioInput.channels, equals(2));
        expect(audioInput.durationMs, equals(30000));
      });

      test('Audio format support', () {
        expect(AudioFormat.wav.toString(), contains('wav'));
        expect(AudioFormat.mp3.toString(), contains('mp3'));
        expect(AudioFormat.flac.toString(), contains('flac'));
        expect(AudioFormat.pcm16.toString(), contains('pcm16'));
      });

      test('Audio streaming configuration', () {
        final streamConfig = AudioStreamConfig(
          bufferSizeMs: 100,
          chunkSizeMs: 20,
          enableRealTime: true,
          targetSampleRate: 16000,
        );

        expect(streamConfig.bufferSizeMs, equals(100));
        expect(streamConfig.chunkSizeMs, equals(20));
        expect(streamConfig.enableRealTime, isTrue);
        expect(streamConfig.targetSampleRate, equals(16000));
      });

      test('Raw audio samples input', () {
        final samples = Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5]);
        final audioInput = MediaInput.fromAudioSamples(
          samples: samples,
          sampleRate: 16000,
          channels: 1,
        );

        expect(audioInput.type, equals(MediaType.audio));
        expect(audioInput.sourceType, equals(DataSource.rawSamples));
        expect(audioInput.sampleRate, equals(16000));
        expect(audioInput.channels, equals(1));
      });
    });

    // =========================================================================
    // STRUCTURED OUTPUT TESTS
    // =========================================================================

    group('Structured Output Tests', () {
      test('JSON output configuration', () {
        final jsonConfig = StructuredOutput(
          format: OutputFormat.json,
          schema: '{"type": "object", "properties": {"name": {"type": "string"}}}',
          strictValidation: true,
          prettyPrint: true,
        );

        expect(jsonConfig.format, equals(OutputFormat.json));
        expect(jsonConfig.schema, contains('type'));
        expect(jsonConfig.strictValidation, isTrue);
        expect(jsonConfig.prettyPrint, isTrue);
      });

      test('Template processing configuration', () {
        final templateConfig = TextTemplate(
          templateString: 'Hello {{name}}, today is {{date}}',
          variables: {
            'name': 'Alice',
            'date': '2024-01-01',
          },
          escapeHtml: false,
          preserveWhitespace: true,
        );

        expect(templateConfig.templateString, contains('{{name}}'));
        expect(templateConfig.variables['name'], equals('Alice'));
        expect(templateConfig.escapeHtml, isFalse);
        expect(templateConfig.preserveWhitespace, isTrue);
      });

      test('Output format validation', () {
        expect(OutputFormat.values.length, greaterThan(5));
        expect(OutputFormat.json.toString(), contains('json'));
        expect(OutputFormat.yaml.toString(), contains('yaml'));
        expect(OutputFormat.csv.toString(), contains('csv'));
        expect(OutputFormat.markdown.toString(), contains('markdown'));
      });

      test('Schema validation configuration', () {
        final validationConfig = SchemaValidation(
          enableValidation: true,
          maxDepth: 10,
          allowAdditionalProperties: false,
          strictTypeChecking: true,
        );

        expect(validationConfig.enableValidation, isTrue);
        expect(validationConfig.maxDepth, equals(10));
        expect(validationConfig.allowAdditionalProperties, isFalse);
        expect(validationConfig.strictTypeChecking, isTrue);
      });
    });

    // =========================================================================
    // LORA ADAPTER TESTS
    // =========================================================================

    group('LoRA Adapter Tests', () {
      test('LoRA adapter information structure', () {
        final adapterInfo = LoraAdapterInfo(
          name: 'test-adapter',
          filePath: '/path/to/adapter.safetensors',
          scale: 0.8,
          isActive: true,
          description: 'Test LoRA adapter for unit testing',
          targetModules: ['q_proj', 'v_proj', 'k_proj'],
        );

        expect(adapterInfo.name, equals('test-adapter'));
        expect(adapterInfo.scale, equals(0.8));
        expect(adapterInfo.isActive, isTrue);
        expect(adapterInfo.targetModules.length, equals(3));
      });

      test('LoRA batch configuration', () {
        final batchConfig = LoraBatch(
          adapters: ['adapter1', 'adapter2', 'adapter3'],
          scales: [0.8, 0.6, 1.0],
          mergeStrategy: MergeStrategy.weighted,
          enableBatching: true,
        );

        expect(batchConfig.adapters.length, equals(3));
        expect(batchConfig.scales.length, equals(3));
        expect(batchConfig.mergeStrategy, equals(MergeStrategy.weighted));
        expect(batchConfig.enableBatching, isTrue);
      });

      test('LoRA management operations', () {
        final management = LoraManagement(
          autoLoadConfig: true,
          configPath: '/path/to/lora_config.json',
          enableCaching: true,
          maxCachedAdapters: 5,
        );

        expect(management.autoLoadConfig, isTrue);
        expect(management.enableCaching, isTrue);
        expect(management.maxCachedAdapters, equals(5));
      });
    });

    // =========================================================================
    // STREAMING TESTS
    // =========================================================================

    group('Streaming Tests', () {
      test('Universal streaming configuration', () {
        final streamConfig = StreamConfig(
          streamType: StreamType.textTokens,
          bufferSize: 1024,
          chunkSize: 128,
          enableRealTime: true,
          maxLatencyMs: 50,
        );

        expect(streamConfig.streamType, equals(StreamType.textTokens));
        expect(streamConfig.bufferSize, equals(1024));
        expect(streamConfig.chunkSize, equals(128));
        expect(streamConfig.enableRealTime, isTrue);
        expect(streamConfig.maxLatencyMs, equals(50));
      });

      test('Streaming callback configuration', () {
        final callbackConfig = StreamCallbackConfig(
          onTextToken: (token) => print('Token: $token'),
          onAudioSamples: (samples) => print('Audio: ${samples.length} samples'),
          onStructuredChunk: (json) => print('JSON: $json'),
          onError: (error) => print('Error: $error'),
        );

        expect(callbackConfig.onTextToken, isNotNull);
        expect(callbackConfig.onAudioSamples, isNotNull);
        expect(callbackConfig.onStructuredChunk, isNotNull);
        expect(callbackConfig.onError, isNotNull);
      });

      test('Stream event structure', () {
        final textEvent = StreamEvent.text(
          token: 'Hello',
          isFinalToken: false,
          confidence: 0.95,
        );

        expect(textEvent.type, equals(StreamType.textTokens));
        expect(textEvent.token, equals('Hello'));
        expect(textEvent.isFinalToken, isFalse);
        expect(textEvent.confidence, equals(0.95));

        final audioEvent = StreamEvent.audio(
          samples: Float32List.fromList([0.1, 0.2, 0.3]),
          sampleRate: 16000,
          isFinalChunk: true,
        );

        expect(audioEvent.type, equals(StreamType.audioSamples));
        expect(audioEvent.samples!.length, equals(3));
        expect(audioEvent.sampleRate, equals(16000));
        expect(audioEvent.isFinalChunk, isTrue);
      });
    });

    // =========================================================================
    // TEXT PROCESSING TESTS
    // =========================================================================

    group('Advanced Text Processing Tests', () {
      test('Text preprocessing configuration', () {
        final preprocessConfig = TextPreprocessing(
          normalizeWhitespace: true,
          removeMarkdown: false,
          escapeSpecialChars: true,
          maxLength: 10000,
        );

        expect(preprocessConfig.normalizeWhitespace, isTrue);
        expect(preprocessConfig.removeMarkdown, isFalse);
        expect(preprocessConfig.escapeSpecialChars, isTrue);
        expect(preprocessConfig.maxLength, equals(10000));
      });

      test('Chat session configuration', () {
        final chatConfig = ChatSessionConfig(
          systemPrompt: 'You are a helpful assistant',
          maxHistoryLength: 50,
          enableMemory: true,
          memoryStrategy: MemoryStrategy.sliding,
        );

        expect(chatConfig.systemPrompt, contains('helpful assistant'));
        expect(chatConfig.maxHistoryLength, equals(50));
        expect(chatConfig.enableMemory, isTrue);
        expect(chatConfig.memoryStrategy, equals(MemoryStrategy.sliding));
      });

      test('Content analysis configuration', () {
        final analysisConfig = ContentAnalysis(
          enableSentiment: true,
          enableEntityExtraction: true,
          enableKeywordExtraction: true,
          enableLanguageDetection: true,
          maxKeywords: 10,
        );

        expect(analysisConfig.enableSentiment, isTrue);
        expect(analysisConfig.enableEntityExtraction, isTrue);
        expect(analysisConfig.enableKeywordExtraction, isTrue);
        expect(analysisConfig.enableLanguageDetection, isTrue);
        expect(analysisConfig.maxKeywords, equals(10));
      });

      test('Translation configuration', () {
        final translationConfig = TranslationConfig(
          sourceLanguage: 'en',
          targetLanguage: 'es',
          enableAutoDetect: true,
          preserveFormatting: true,
        );

        expect(translationConfig.sourceLanguage, equals('en'));
        expect(translationConfig.targetLanguage, equals('es'));
        expect(translationConfig.enableAutoDetect, isTrue);
        expect(translationConfig.preserveFormatting, isTrue);
      });
    });

    // =========================================================================
    // MULTIMODAL INTEGRATION TESTS
    // =========================================================================

    group('Multimodal Integration Tests', () {
      test('Multimodal inference parameters', () {
        final multimodalParams = MultimodalInferParams(
          prompt: 'Describe this image and audio',
          mediaInputs: [
            MediaInput(type: MediaType.image, data: 'image.jpg'),
            MediaInput(type: MediaType.audio, data: 'audio.wav'),
          ],
          maxTokens: 512,
          temperature: 0.7,
          includeImageTokens: true,
          preserveImageOrder: true,
          visionThreads: 4,
          useVisionCache: true,
        );

        expect(multimodalParams.prompt, contains('Describe'));
        expect(multimodalParams.mediaInputs.length, equals(2));
        expect(multimodalParams.maxTokens, equals(512));
        expect(multimodalParams.temperature, equals(0.7));
        expect(multimodalParams.includeImageTokens, isTrue);
        expect(multimodalParams.visionThreads, equals(4));
      });

      test('Media batch processing configuration', () {
        final batchConfig = MediaBatch(
          inputs: [
            MediaInput(type: MediaType.image, data: 'image1.jpg'),
            MediaInput(type: MediaType.image, data: 'image2.png'),
            MediaInput(type: MediaType.audio, data: 'audio.wav'),
          ],
          processParallel: true,
          maxBatchSize: 8,
          enableCaching: true,
        );

        expect(batchConfig.inputs.length, equals(3));
        expect(batchConfig.processParallel, isTrue);
        expect(batchConfig.maxBatchSize, equals(8));
        expect(batchConfig.enableCaching, isTrue);
      });

      test('Complex multimodal workflow configuration', () {
        final workflowConfig = MultimodalWorkflow(
          stages: [
            WorkflowStage.imagePreprocessing,
            WorkflowStage.audioPreprocessing,
            WorkflowStage.featureExtraction,
            WorkflowStage.multimodalFusion,
            WorkflowStage.textGeneration,
          ],
          enablePipeline: true,
          parallelStages: [WorkflowStage.imagePreprocessing, WorkflowStage.audioPreprocessing],
          outputFormat: OutputFormat.json,
        );

        expect(workflowConfig.stages.length, equals(5));
        expect(workflowConfig.enablePipeline, isTrue);
        expect(workflowConfig.parallelStages.length, equals(2));
        expect(workflowConfig.outputFormat, equals(OutputFormat.json));
      });
    });

    // =========================================================================
    // ERROR HANDLING TESTS
    // =========================================================================

    group('Error Handling Tests', () {
      test('Error code definitions', () {
        expect(ErrorCode.success.value, equals(0));
        expect(ErrorCode.invalidParam.value, lessThan(0));
        expect(ErrorCode.modelLoadFailed.value, lessThan(0));
        expect(ErrorCode.outOfMemory.value, lessThan(0));
        expect(ErrorCode.multimodalNotSupported.value, lessThan(0));
      });

      test('Multimodal-specific error codes', () {
        expect(ErrorCode.imageLoadFailed.value, lessThan(0));
        expect(ErrorCode.imageFormatUnsupported.value, lessThan(0));
        expect(ErrorCode.base64DecodeFailed.value, lessThan(0));
        expect(ErrorCode.visionInitFailed.value, lessThan(0));
        expect(ErrorCode.audioProcessFailed.value, lessThan(0));
      });

      test('Exception handling configuration', () {
        final errorConfig = ErrorHandling(
          enableDetailedErrors: true,
          includeStackTrace: false,
          maxErrorMessageLength: 512,
          enableErrorLogging: true,
        );

        expect(errorConfig.enableDetailedErrors, isTrue);
        expect(errorConfig.includeStackTrace, isFalse);
        expect(errorConfig.maxErrorMessageLength, equals(512));
        expect(errorConfig.enableErrorLogging, isTrue);
      });
    });

    // =========================================================================
    // PERFORMANCE AND MEMORY TESTS
    // =========================================================================

    group('Performance Tests', () {
      test('Performance monitoring configuration', () {
        final perfConfig = PerformanceConfig(
          enableProfiling: true,
          trackMemoryUsage: true,
          trackProcessingTime: true,
          enableBenchmarking: true,
          maxProfilingHistory: 100,
        );

        expect(perfConfig.enableProfiling, isTrue);
        expect(perfConfig.trackMemoryUsage, isTrue);
        expect(perfConfig.trackProcessingTime, isTrue);
        expect(perfConfig.enableBenchmarking, isTrue);
        expect(perfConfig.maxProfilingHistory, equals(100));
      });

      test('Memory management configuration', () {
        final memoryConfig = MemoryConfig(
          enableCaching: true,
          maxCacheSize: 256 * 1024 * 1024, // 256MB
          enableGarbageCollection: true,
          gcThreshold: 0.8,
        );

        expect(memoryConfig.enableCaching, isTrue);
        expect(memoryConfig.maxCacheSize, equals(256 * 1024 * 1024));
        expect(memoryConfig.enableGarbageCollection, isTrue);
        expect(memoryConfig.gcThreshold, equals(0.8));
      });

      test('Threading configuration', () {
        final threadConfig = ThreadingConfig(
          textThreads: 8,
          visionThreads: 4,
          audioThreads: 2,
          enableParallelProcessing: true,
          maxConcurrentOperations: 16,
        );

        expect(threadConfig.textThreads, equals(8));
        expect(threadConfig.visionThreads, equals(4));
        expect(threadConfig.audioThreads, equals(2));
        expect(threadConfig.enableParallelProcessing, isTrue);
        expect(threadConfig.maxConcurrentOperations, equals(16));
      });
    });

    // =========================================================================
    // VALIDATION AND SECURITY TESTS
    // =========================================================================

    group('Validation and Security Tests', () {
      test('Input sanitization', () {
        // Test various malicious inputs
        final maliciousInputs = [
          'Hello\0World',           // Null byte injection
          'A' * 1000000,            // Buffer overflow attempt
          '../../../etc/passwd',    // Path traversal
          '<script>alert(1)</script>', // XSS attempt
          '\x01\x02\x03',          // Control characters
        ];

        for (final input in maliciousInputs) {
          expect(
            () => _validateInput(input),
            throwsA(isA<ArgumentError>()),
            reason: 'Failed to reject malicious input: $input',
          );
        }
      });

      test('File path validation', () {
        final invalidPaths = [
          '',
          '/etc/shadow',
          '../../../sensitive_file',
          'con',        // Windows reserved name
          'null\0byte', // Null byte in path
          'A' * 10000,  // Excessively long path
        ];

        for (final path in invalidPaths) {
          expect(
            () => _validateFilePath(path),
            throwsA(isA<ArgumentError>()),
            reason: 'Failed to reject invalid path: $path',
          );
        }
      });

      test('Parameter bounds validation', () {
        // Temperature validation
        expect(() => _validateTemperature(-1.0), throwsA(isA<ArgumentError>()));
        expect(() => _validateTemperature(10.0), throwsA(isA<ArgumentError>()));
        expect(() => _validateTemperature(double.nan), throwsA(isA<ArgumentError>()));
        expect(() => _validateTemperature(double.infinity), throwsA(isA<ArgumentError>()));

        // Thread count validation
        expect(() => _validateThreadCount(-1), throwsA(isA<ArgumentError>()));
        expect(() => _validateThreadCount(0), throwsA(isA<ArgumentError>()));
        expect(() => _validateThreadCount(1000), throwsA(isA<ArgumentError>()));

        // Context size validation
        expect(() => _validateContextSize(0), throwsA(isA<ArgumentError>()));
        expect(() => _validateContextSize(-1), throwsA(isA<ArgumentError>()));
        expect(() => _validateContextSize(10000000), throwsA(isA<ArgumentError>()));
      });
    });
  });
}

// =============================================================================
// HELPER FUNCTIONS FOR VALIDATION TESTING
// =============================================================================

void _validateInput(String input) {
  if (input.contains('\0')) {
    throw ArgumentError('Input contains null bytes');
  }
  if (input.length > 100000) {
    throw ArgumentError('Input too long');
  }
  for (int i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    if (code < 32 && code != 9 && code != 10 && code != 13) {
      throw ArgumentError('Input contains control characters');
    }
  }
}

void _validateFilePath(String path) {
  if (path.isEmpty) {
    throw ArgumentError('Empty file path');
  }
  if (path.length > 4096) {
    throw ArgumentError('File path too long');
  }
  if (path.contains('\0')) {
    throw ArgumentError('File path contains null bytes');
  }
  if (path.contains('..')) {
    throw ArgumentError('File path contains traversal attempt');
  }
  if (path.startsWith('/etc/') || path.startsWith('/proc/') || path.startsWith('/sys/')) {
    throw ArgumentError('Access to system directories not allowed');
  }
}

void _validateTemperature(double temperature) {
  if (!temperature.isFinite || temperature < 0.0 || temperature > 2.0) {
    throw ArgumentError('Invalid temperature: $temperature');
  }
}

void _validateThreadCount(int threads) {
  if (threads <= 0 || threads > 128) {
    throw ArgumentError('Invalid thread count: $threads');
  }
}

void _validateContextSize(int contextSize) {
  if (contextSize <= 0 || contextSize > 1048576) {
    throw ArgumentError('Invalid context size: $contextSize');
  }
}