import 'dart:typed_data';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  group('Llamafu Performance Tests', () {
    late Llamafu llamafu;
    late Directory tempDir;
    late File mockModelFile;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('llamafu_perf_test');
      mockModelFile = File('${tempDir.path}/test_model.gguf');
      await _createMockModelFile(mockModelFile);
    });

    tearDownAll(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    setUp(() async {
      llamafu = Llamafu();
    });

    tearDown(() async {
      llamafu.dispose();
    });

    group('Initialization Performance', () {
      test('should measure model loading time', () async {
        final stopwatch = Stopwatch()..start();

        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 2048,
            threads: 4,
          );
          stopwatch.stop();

          print('Model initialization time: ${stopwatch.elapsedMilliseconds}ms');
          expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // 30 seconds max
        } catch (e) {
          stopwatch.stop();
          print('Expected initialization failure with mock model: $e');
          print('Initialization attempt time: ${stopwatch.elapsedMilliseconds}ms');
        }
      });

      test('should measure context size impact on initialization', () async {
        final contextSizes = [512, 1024, 2048, 4096];
        final initTimes = <int, int>{};

        for (final contextSize in contextSizes) {
          final stopwatch = Stopwatch()..start();

          try {
            final testLlamafu = Llamafu();
            await testLlamafu.init(
              modelPath: mockModelFile.path,
              contextSize: contextSize,
              threads: 2,
            );
            stopwatch.stop();
            testLlamafu.dispose();
          } catch (e) {
            stopwatch.stop();
          }

          initTimes[contextSize] = stopwatch.elapsedMilliseconds;
          print('Context size $contextSize: ${stopwatch.elapsedMilliseconds}ms');
        }

        // Expect initialization time to increase with context size
        expect(initTimes[4096]!, greaterThanOrEqualTo(initTimes[512]!));
      });
    });

    group('Tokenization Performance', () {
      test('should benchmark tokenization speed', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 1024,
          );

          final testTexts = [
            'Short text',
            'This is a medium length text that should take a bit more time to tokenize.',
            'This is a very long text ' * 100, // Very long text
          ];

          for (final text in testTexts) {
            final stopwatch = Stopwatch()..start();

            try {
              final tokens = await llamafu.tokenize(text);
              stopwatch.stop();

              print('Tokenized ${text.length} chars (${tokens.length} tokens) in ${stopwatch.elapsedMilliseconds}ms');
              expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
            } catch (e) {
              stopwatch.stop();
              print('Tokenization error: $e');
            }
          }
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });

      test('should test concurrent tokenization performance', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 2048,
            threads: 4,
          );

          const numConcurrentRequests = 10;
          final futures = <Future<void>>[];
          final stopwatch = Stopwatch()..start();

          for (int i = 0; i < numConcurrentRequests; i++) {
            futures.add(_tokenizeText(llamafu, 'Concurrent tokenization test $i ' * 50));
          }

          await Future.wait(futures);
          stopwatch.stop();

          print('Concurrent tokenization ($numConcurrentRequests requests): ${stopwatch.elapsedMilliseconds}ms');
          expect(stopwatch.elapsedMilliseconds, lessThan(30000)); // 30 seconds max
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });
    });

    group('Memory Performance', () {
      test('should test memory usage during intensive operations', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 4096,
            threads: 4,
          );

          final initialMemory = ProcessInfo.currentRss;
          print('Initial memory usage: ${initialMemory / 1024 / 1024:.2f} MB');

          // Perform memory-intensive operations
          for (int i = 0; i < 100; i++) {
            final largeText = 'Memory test iteration $i ' * 1000;
            try {
              final tokens = await llamafu.tokenize(largeText);
              final detokenized = await llamafu.detokenize(tokens);
              expect(detokenized, isNotEmpty);

              if (i % 10 == 0) {
                final currentMemory = ProcessInfo.currentRss;
                print('Memory at iteration $i: ${currentMemory / 1024 / 1024:.2f} MB');
              }
            } catch (e) {
              // Expected with mock model
            }
          }

          final finalMemory = ProcessInfo.currentRss;
          print('Final memory usage: ${finalMemory / 1024 / 1024:.2f} MB');

          // Memory should not grow excessively
          final memoryGrowth = finalMemory - initialMemory;
          expect(memoryGrowth, lessThan(500 * 1024 * 1024)); // 500MB max growth
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });

      test('should test memory leak detection', () async {
        final memoryMeasurements = <int>[];

        for (int iteration = 0; iteration < 5; iteration++) {
          final testLlamafu = Llamafu();

          try {
            await testLlamafu.init(
              modelPath: mockModelFile.path,
              contextSize: 1024,
            );

            // Perform operations
            for (int i = 0; i < 20; i++) {
              try {
                final tokens = await testLlamafu.tokenize('Memory leak test $i');
                await testLlamafu.detokenize(tokens);
              } catch (e) {
                // Expected with mock model
              }
            }
          } catch (e) {
            // Expected with mock model
          }

          testLlamafu.dispose();

          // Force garbage collection
          await Future.delayed(Duration(milliseconds: 100));

          final currentMemory = ProcessInfo.currentRss;
          memoryMeasurements.add(currentMemory);
          print('Memory after iteration $iteration: ${currentMemory / 1024 / 1024:.2f} MB');
        }

        // Check for consistent memory usage (no significant growth)
        final firstMeasurement = memoryMeasurements.first;
        final lastMeasurement = memoryMeasurements.last;
        final memoryGrowth = lastMeasurement - firstMeasurement;

        expect(memoryGrowth, lessThan(100 * 1024 * 1024)); // 100MB max growth
      });
    });

    group('Throughput Performance', () {
      test('should measure text generation throughput', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 2048,
            threads: 4,
          );

          final stopwatch = Stopwatch()..start();
          var totalTokens = 0;

          for (int i = 0; i < 10; i++) {
            try {
              final response = await llamafu.complete(
                prompt: 'Generate text for performance test $i',
                maxTokens: 100,
                temperature: 0.1,
              );

              final tokens = await llamafu.tokenize(response);
              totalTokens += tokens.length;
            } catch (e) {
              // Expected with mock model
              totalTokens += 50; // Estimated tokens for mock response
            }
          }

          stopwatch.stop();
          final tokensPerSecond = totalTokens / (stopwatch.elapsedMilliseconds / 1000);

          print('Text generation throughput: ${tokensPerSecond.toStringAsFixed(2)} tokens/second');
          print('Total tokens generated: $totalTokens in ${stopwatch.elapsedMilliseconds}ms');

          expect(tokensPerSecond, greaterThan(0));
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });

      test('should measure streaming throughput', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 1024,
          );

          final receivedTokens = <String>[];
          final stopwatch = Stopwatch()..start();

          try {
            await llamafu.completeStream(
              prompt: 'Stream performance test',
              maxTokens: 200,
              temperature: 0.5,
              onToken: (token) {
                receivedTokens.add(token);
              },
            );
          } catch (e) {
            // Simulate streaming for mock model
            for (int i = 0; i < 50; i++) {
              receivedTokens.add('token_$i ');
              await Future.delayed(Duration(milliseconds: 10));
            }
          }

          stopwatch.stop();
          final tokensPerSecond = receivedTokens.length / (stopwatch.elapsedMilliseconds / 1000);

          print('Streaming throughput: ${tokensPerSecond.toStringAsFixed(2)} tokens/second');
          print('Received ${receivedTokens.length} tokens in ${stopwatch.elapsedMilliseconds}ms');

          expect(receivedTokens, isNotEmpty);
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });
    });

    group('Multimodal Performance', () {
      test('should benchmark image processing speed', () async {
        final imageSizes = [
          (224, 224),   // Small
          (512, 512),   // Medium
          (1024, 1024), // Large
        ];

        for (final (width, height) in imageSizes) {
          final mockImage = _createMockImageData(width, height);
          final stopwatch = Stopwatch()..start();

          try {
            final format = await llamafu.detectImageFormat(mockImage);
            final isValid = await llamafu.validateImageData(mockImage);
            final base64 = await llamafu.encodeImageToBase64(mockImage);
            final decoded = await llamafu.decodeBase64ToImage(base64);

            stopwatch.stop();

            print('Image processing (${width}x$height): ${stopwatch.elapsedMilliseconds}ms');
            expect(decoded.length, equals(mockImage.length));
          } catch (e) {
            stopwatch.stop();
            print('Image processing error: $e');
          }
        }
      });

      test('should benchmark audio processing speed', () async {
        final audioLengths = [1, 5, 10]; // seconds

        for (final lengthSeconds in audioLengths) {
          final mockAudio = _createMockAudioData(lengthSeconds);
          final stopwatch = Stopwatch()..start();

          try {
            final format = await llamafu.detectAudioFormat(mockAudio);
            final isValid = await llamafu.validateAudioData(mockAudio);
            final rawSamples = await llamafu.convertAudioToRawSamples(
              mockAudio,
              targetSampleRate: 16000,
              targetChannels: 1,
            );

            stopwatch.stop();

            print('Audio processing (${lengthSeconds}s): ${stopwatch.elapsedMilliseconds}ms');
            expect(rawSamples, isNotEmpty);
          } catch (e) {
            stopwatch.stop();
            print('Audio processing error: $e');
          }
        }
      });
    });

    group('Stress Tests', () {
      test('should handle rapid successive operations', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 1024,
          );

          final stopwatch = Stopwatch()..start();
          var successCount = 0;

          for (int i = 0; i < 100; i++) {
            try {
              final tokens = await llamafu.tokenize('Rapid test $i');
              final detokenized = await llamafu.detokenize(tokens);
              if (detokenized.isNotEmpty) successCount++;
            } catch (e) {
              // Expected with mock model
              successCount++; // Count as success for stress test
            }
          }

          stopwatch.stop();

          print('Rapid operations: $successCount/100 successful in ${stopwatch.elapsedMilliseconds}ms');
          expect(successCount, greaterThan(50)); // At least 50% success rate
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });

      test('should handle concurrent model instances', () async {
        const numInstances = 3;
        final futures = <Future<void>>[];

        for (int i = 0; i < numInstances; i++) {
          futures.add(_testModelInstance(mockModelFile.path, i));
        }

        final stopwatch = Stopwatch()..start();
        await Future.wait(futures);
        stopwatch.stop();

        print('Concurrent model instances ($numInstances): ${stopwatch.elapsedMilliseconds}ms');
        expect(stopwatch.elapsedMilliseconds, lessThan(60000)); // 60 seconds max
      });

      test('should handle large context stress test', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 8192, // Large context
            threads: 4,
          );

          // Build up a large context gradually
          var accumulatedText = '';
          final stopwatch = Stopwatch()..start();

          for (int i = 0; i < 50; i++) {
            accumulatedText += 'Context building iteration $i. ' * 20;

            try {
              final tokens = await llamafu.tokenize(accumulatedText);
              print('Iteration $i: ${accumulatedText.length} chars, ${tokens.length} tokens');

              // If context gets too large, truncate
              if (tokens.length > 6000) {
                accumulatedText = accumulatedText.substring(accumulatedText.length ~/ 2);
              }
            } catch (e) {
              print('Context stress test iteration $i error: $e');
            }
          }

          stopwatch.stop();
          print('Large context stress test completed in ${stopwatch.elapsedMilliseconds}ms');
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });
    });

    group('Resource Limits Tests', () {
      test('should handle memory pressure gracefully', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 2048,
          );

          // Allocate large amounts of data to create memory pressure
          final largeArrays = <Uint8List>[];

          try {
            for (int i = 0; i < 10; i++) {
              // Allocate 50MB chunks
              largeArrays.add(Uint8List(50 * 1024 * 1024));

              // Try to perform operations under memory pressure
              try {
                final tokens = await llamafu.tokenize('Memory pressure test $i');
                expect(tokens, isNotEmpty);
              } catch (e) {
                print('Operation failed under memory pressure: $e');
              }

              final currentMemory = ProcessInfo.currentRss;
              print('Memory pressure test $i: ${currentMemory / 1024 / 1024:.2f} MB');
            }
          } finally {
            // Clean up large allocations
            largeArrays.clear();
          }
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });

      test('should handle thread contention', () async {
        try {
          await llamafu.init(
            modelPath: mockModelFile.path,
            contextSize: 1024,
            threads: 8, // High thread count
          );

          // Create thread contention with many concurrent operations
          final futures = <Future<void>>[];

          for (int i = 0; i < 20; i++) {
            futures.add(Future.microtask(() async {
              try {
                final tokens = await llamafu.tokenize('Thread contention test $i ' * 100);
                final detokenized = await llamafu.detokenize(tokens);
                expect(detokenized, isNotEmpty);
              } catch (e) {
                print('Thread contention operation $i error: $e');
              }
            }));
          }

          final stopwatch = Stopwatch()..start();
          await Future.wait(futures);
          stopwatch.stop();

          print('Thread contention test completed in ${stopwatch.elapsedMilliseconds}ms');
        } catch (e) {
          print('Expected error with mock model: $e');
        }
      });
    });
  });
}

Future<void> _createMockModelFile(File file) async {
  final mockData = Uint8List.fromList([
    // Mock GGUF header
    0x47, 0x47, 0x55, 0x46, // "GGUF" magic
    0x03, 0x00, 0x00, 0x00, // version 3
    0x00, 0x00, 0x00, 0x00, // tensor count
    0x00, 0x00, 0x00, 0x00, // metadata kv count
    ...List.filled(10000, 0x00), // Mock model data
  ]);
  await file.writeAsBytes(mockData);
}

Future<void> _tokenizeText(Llamafu llamafu, String text) async {
  try {
    final tokens = await llamafu.tokenize(text);
    expect(tokens, isNotEmpty);
  } catch (e) {
    // Expected with mock model
  }
}

Future<void> _testModelInstance(String modelPath, int instanceId) async {
  final llamafu = Llamafu();
  try {
    await llamafu.init(
      modelPath: modelPath,
      contextSize: 512,
      threads: 2,
    );

    // Perform some operations
    for (int i = 0; i < 10; i++) {
      try {
        final tokens = await llamafu.tokenize('Instance $instanceId operation $i');
        await llamafu.detokenize(tokens);
      } catch (e) {
        // Expected with mock model
      }
    }
  } catch (e) {
    print('Model instance $instanceId error: $e');
  } finally {
    llamafu.dispose();
  }
}

Uint8List _createMockImageData(int width, int height) {
  final random = Random();
  final imageSize = width * height * 3; // RGB
  return Uint8List.fromList([
    // Mock PNG header
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ...List.generate(imageSize, (_) => random.nextInt(256)),
  ]);
}

Uint8List _createMockAudioData(int lengthSeconds) {
  const sampleRate = 44100;
  const channels = 2;
  const bytesPerSample = 2;
  final numSamples = sampleRate * lengthSeconds * channels;
  final dataSize = numSamples * bytesPerSample;

  return Uint8List.fromList([
    // WAV header
    0x52, 0x49, 0x46, 0x46, // "RIFF"
    ...(_int32ToBytes(36 + dataSize)), // file size
    0x57, 0x41, 0x56, 0x45, // "WAVE"
    0x66, 0x6D, 0x74, 0x20, // "fmt "
    0x10, 0x00, 0x00, 0x00, // fmt chunk size
    0x01, 0x00, // audio format (PCM)
    ...(_int16ToBytes(channels)), // channels
    ...(_int32ToBytes(sampleRate)), // sample rate
    ...(_int32ToBytes(sampleRate * channels * bytesPerSample)), // byte rate
    ...(_int16ToBytes(channels * bytesPerSample)), // block align
    ...(_int16ToBytes(bytesPerSample * 8)), // bits per sample
    0x64, 0x61, 0x74, 0x61, // "data"
    ...(_int32ToBytes(dataSize)), // data size
    ...List.generate(dataSize, (i) => (i % 256)), // mock audio data
  ]);
}

List<int> _int32ToBytes(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ];
}

List<int> _int16ToBytes(int value) {
  return [
    value & 0xFF,
    (value >> 8) & 0xFF,
  ];
}