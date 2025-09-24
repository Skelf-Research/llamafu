import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamafu/llamafu.dart';
import '../fixtures/test_data.dart';

class TestHelpers {
  static late Directory _tempDir;
  static late File _mockModelFile;
  static late File _mockMmprojFile;

  /// Sets up test environment with mock files
  static Future<void> setUpTestEnvironment() async {
    _tempDir = await Directory.systemTemp.createTemp('llamafu_test_');

    // Create mock model files
    _mockModelFile = File('${_tempDir.path}/test_model.gguf');
    await _mockModelFile.writeAsBytes(TestFixtures.createMockGGUFModel(sizeMB: 10));

    _mockMmprojFile = File('${_tempDir.path}/test_mmproj.gguf');
    await _mockMmprojFile.writeAsBytes(TestFixtures.createMockGGUFModel(sizeMB: 5));

    // Create mock LoRA files
    for (int i = 0; i < 3; i++) {
      final loraFile = File('${_tempDir.path}/test_lora_$i.bin');
      await loraFile.writeAsBytes(TestFixtures.createMockLoRAAdapter());
    }

    // Create test images
    final pngFile = File('${_tempDir.path}/test_image.png');
    await pngFile.writeAsBytes(TestFixtures.createMockPNGImage(width: 512, height: 512));

    // Create test audio
    final wavFile = File('${_tempDir.path}/test_audio.wav');
    await wavFile.writeAsBytes(TestFixtures.createMockWAVAudio(durationSeconds: 5.0));
  }

  /// Cleans up test environment
  static Future<void> tearDownTestEnvironment() async {
    if (_tempDir.existsSync()) {
      await _tempDir.delete(recursive: true);
    }
  }

  /// Gets the mock model file path
  static String get mockModelPath => _mockModelFile.path;

  /// Gets the mock multimodal projection file path
  static String get mockMmprojPath => _mockMmprojFile.path;

  /// Gets the temporary directory path
  static String get tempDirPath => _tempDir.path;

  /// Creates a test Llamafu instance with default parameters
  static Future<Llamafu> createTestLlamafu({
    int contextSize = 1024,
    int threads = 2,
    bool useGpu = false,
    bool multimodal = false,
  }) async {
    final llamafu = Llamafu();

    try {
      await llamafu.init(
        modelPath: mockModelPath,
        mmprojPath: multimodal ? mockMmprojPath : null,
        contextSize: contextSize,
        threads: threads,
        useGpu: useGpu,
      );
    } catch (e) {
      // Expected with mock model files
      print('Mock model initialization (expected): $e');
    }

    return llamafu;
  }

  /// Asserts that an operation completes within a specified time
  static Future<T> assertTimedOperation<T>(
    Future<T> operation,
    Duration maxDuration, {
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();
    final result = await operation;
    stopwatch.stop();

    final elapsed = stopwatch.elapsed;
    final desc = description ?? 'Operation';

    print('$desc completed in ${elapsed.inMilliseconds}ms');
    expect(elapsed, lessThan(maxDuration),
        reason: '$desc took ${elapsed.inMilliseconds}ms, expected less than ${maxDuration.inMilliseconds}ms');

    return result;
  }

  /// Asserts that an operation throws a specific error
  static Future<void> assertThrowsLlamafuError(
    Future<dynamic> operation,
    String expectedError,
  ) async {
    try {
      await operation;
      fail('Expected operation to throw $expectedError but it succeeded');
    } catch (e) {
      expect(e.toString(), contains(expectedError),
          reason: 'Expected error containing "$expectedError", got: $e');
    }
  }

  /// Measures memory usage during an operation
  static Future<T> measureMemoryUsage<T>(
    Future<T> operation, {
    String? description,
  }) async {
    final initialMemory = ProcessInfo.currentRss;
    final result = await operation;
    final finalMemory = ProcessInfo.currentRss;

    final memoryDelta = finalMemory - initialMemory;
    final desc = description ?? 'Operation';

    print('$desc memory usage: ${memoryDelta / 1024 / 1024:.2f} MB delta');
    print('  Initial: ${initialMemory / 1024 / 1024:.2f} MB');
    print('  Final: ${finalMemory / 1024 / 1024:.2f} MB');

    return result;
  }

  /// Runs a performance benchmark for a given operation
  static Future<BenchmarkResult> benchmark(
    String name,
    Future<void> Function() operation, {
    int iterations = 10,
    Duration? maxDuration,
  }) async {
    final times = <Duration>[];
    final memoryUsages = <int>[];

    print('Running benchmark: $name ($iterations iterations)');

    for (int i = 0; i < iterations; i++) {
      final initialMemory = ProcessInfo.currentRss;
      final stopwatch = Stopwatch()..start();

      await operation();

      stopwatch.stop();
      final finalMemory = ProcessInfo.currentRss;

      times.add(stopwatch.elapsed);
      memoryUsages.add(finalMemory - initialMemory);

      if (maxDuration != null && stopwatch.elapsed > maxDuration) {
        fail('Iteration $i took ${stopwatch.elapsed.inMilliseconds}ms, exceeded limit of ${maxDuration.inMilliseconds}ms');
      }
    }

    return BenchmarkResult(name, times, memoryUsages);
  }

  /// Validates that a string is valid JSON
  static bool isValidJson(String jsonString) {
    try {
      // ignore: avoid_dynamic_calls
      // ignore: unused_local_variable
      final decoded = jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validates that a byte array has a valid image format
  static bool isValidImageFormat(Uint8List data) {
    if (data.length < 8) return false;

    // Check PNG signature
    if (data.length >= 8 &&
        data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47) {
      return true;
    }

    // Check JPEG signature
    if (data.length >= 2 && data[0] == 0xFF && data[1] == 0xD8) {
      return true;
    }

    // Check GIF signature
    if (data.length >= 6) {
      final gifSig1 = data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46;
      final gifSig2 = data[3] == 0x38 && (data[4] == 0x37 || data[4] == 0x39) && data[5] == 0x61;
      if (gifSig1 && gifSig2) return true;
    }

    // Check BMP signature
    if (data.length >= 2 && data[0] == 0x42 && data[1] == 0x4D) {
      return true;
    }

    return false;
  }

  /// Validates that a byte array has a valid audio format
  static bool isValidAudioFormat(Uint8List data) {
    if (data.length < 12) return false;

    // Check WAV signature
    if (data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x41 && data[10] == 0x56 && data[11] == 0x45) {
      return true;
    }

    // Check MP3 signature
    if (data.length >= 3) {
      // ID3v2 tag
      if (data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33) return true;
      // MPEG frame header
      if (data[0] == 0xFF && (data[1] & 0xE0) == 0xE0) return true;
    }

    // Check OGG signature
    if (data.length >= 4 &&
        data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53) {
      return true;
    }

    return false;
  }

  /// Creates a stress test that runs multiple operations concurrently
  static Future<List<T>> stressTest<T>(
    String name,
    Future<T> Function() operation,
    int concurrentCount, {
    Duration? timeout,
  }) async {
    print('Running stress test: $name (${concurrentCount} concurrent operations)');

    final futures = List.generate(concurrentCount, (i) async {
      try {
        return await operation();
      } catch (e) {
        print('Stress test operation $i failed: $e');
        rethrow;
      }
    });

    final stopwatch = Stopwatch()..start();

    final results = timeout != null
        ? await Future.wait(futures).timeout(timeout)
        : await Future.wait(futures);

    stopwatch.stop();

    print('Stress test completed: ${results.length}/${concurrentCount} successful in ${stopwatch.elapsedMilliseconds}ms');

    return results;
  }

  /// Validates that a LoRA adapter file has the correct format
  static bool isValidLoRAFormat(Uint8List data) {
    if (data.length < 16) return false;

    // Check for mock LoRA signature
    return data[0] == 0x4C && data[1] == 0x6F && data[2] == 0x52 && data[3] == 0x41;
  }

  /// Generates test data for various scenarios
  static Map<String, dynamic> generateTestScenario(String scenarioType) {
    final random = Random(42);

    switch (scenarioType) {
      case 'text_generation':
        return {
          'prompt': TestFixtures.testPrompts[random.nextInt(TestFixtures.testPrompts.length)],
          'max_tokens': [50, 100, 200, 500][random.nextInt(4)],
          'temperature': [0.1, 0.3, 0.5, 0.7, 0.9][random.nextInt(5)],
          'top_p': [0.3, 0.5, 0.7, 0.9, 1.0][random.nextInt(5)],
          'top_k': [10, 20, 40, 80, 100][random.nextInt(5)],
        };

      case 'multimodal':
        return {
          'prompt': TestFixtures.multimodalPrompts[random.nextInt(TestFixtures.multimodalPrompts.length)],
          'image_data': TestFixtures.createMockPNGImage(
            width: [224, 512, 1024][random.nextInt(3)],
            height: [224, 512, 1024][random.nextInt(3)],
          ),
          'max_tokens': [100, 200, 300][random.nextInt(3)],
        };

      case 'structured_output':
        final schemaKeys = TestFixtures.jsonSchemas.keys.toList();
        final schemaKey = schemaKeys[random.nextInt(schemaKeys.length)];
        return {
          'format': 'JSON',
          'schema': TestFixtures.jsonSchemas[schemaKey]!,
          'prompt': 'Generate a valid $schemaKey object',
          'max_tokens': [100, 200, 300][random.nextInt(3)],
        };

      case 'performance':
        return {
          'context_size': [512, 1024, 2048, 4096][random.nextInt(4)],
          'threads': [1, 2, 4, 8][random.nextInt(4)],
          'batch_size': [1, 4, 8, 16][random.nextInt(4)],
          'iterations': [10, 50, 100][random.nextInt(3)],
        };

      default:
        throw ArgumentError('Unknown scenario type: $scenarioType');
    }
  }

  /// Validates test results against expected criteria
  static void validateTestResult(Map<String, dynamic> result, Map<String, dynamic> criteria) {
    for (final entry in criteria.entries) {
      final key = entry.key;
      final expectedValue = entry.value;

      expect(result, contains(key), reason: 'Result missing key: $key');

      if (expectedValue is num) {
        expect(result[key], isA<num>(), reason: 'Expected $key to be numeric');
        if (expectedValue > 0) {
          expect(result[key], greaterThan(0), reason: 'Expected $key to be positive');
        }
      } else if (expectedValue is String) {
        expect(result[key], isA<String>(), reason: 'Expected $key to be string');
        if (expectedValue.isNotEmpty) {
          expect(result[key], isNotEmpty, reason: 'Expected $key to be non-empty');
        }
      } else if (expectedValue is bool) {
        expect(result[key], isA<bool>(), reason: 'Expected $key to be boolean');
      } else if (expectedValue is List) {
        expect(result[key], isA<List>(), reason: 'Expected $key to be list');
        if (expectedValue.isNotEmpty) {
          expect(result[key], isNotEmpty, reason: 'Expected $key to be non-empty list');
        }
      }
    }
  }

  /// Creates a temporary file with specified content
  static Future<File> createTempFile(String filename, Uint8List content) async {
    final file = File('${_tempDir.path}/$filename');
    await file.writeAsBytes(content);
    return file;
  }

  /// Reads a file and returns its content as bytes
  static Future<Uint8List> readFileBytes(String path) async {
    final file = File(path);
    return await file.readAsBytes();
  }

  /// Compares two byte arrays for equality
  static bool bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Generates a unique test identifier
  static String generateTestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return 'test_${timestamp}_$random';
  }
}

class BenchmarkResult {
  final String name;
  final List<Duration> times;
  final List<int> memoryUsages;

  BenchmarkResult(this.name, this.times, this.memoryUsages);

  Duration get averageTime {
    final totalMs = times.fold(0, (sum, time) => sum + time.inMicroseconds);
    return Duration(microseconds: totalMs ~/ times.length);
  }

  Duration get minTime => times.reduce((a, b) => a < b ? a : b);
  Duration get maxTime => times.reduce((a, b) => a > b ? a : b);

  double get averageMemoryUsage {
    final totalBytes = memoryUsages.fold(0, (sum, usage) => sum + usage);
    return totalBytes / memoryUsages.length;
  }

  int get minMemoryUsage => memoryUsages.reduce((a, b) => a < b ? a : b);
  int get maxMemoryUsage => memoryUsages.reduce((a, b) => a > b ? a : b);

  void printSummary() {
    print('Benchmark Results for: $name');
    print('  Iterations: ${times.length}');
    print('  Average time: ${averageTime.inMilliseconds}ms');
    print('  Min time: ${minTime.inMilliseconds}ms');
    print('  Max time: ${maxTime.inMilliseconds}ms');
    print('  Average memory: ${averageMemoryUsage / 1024 / 1024:.2f} MB');
    print('  Min memory: ${minMemoryUsage / 1024 / 1024:.2f} MB');
    print('  Max memory: ${maxMemoryUsage / 1024 / 1024:.2f} MB');
  }
}

/// Import required for JSON decoding
// ignore: depend_on_referenced_packages
import 'dart:convert' show jsonDecode;
import 'dart:math' show Random;