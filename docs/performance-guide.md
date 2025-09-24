# Performance Guide

This guide covers optimization techniques, benchmarking, and best practices for achieving optimal performance with Llamafu on mobile devices.

## Performance Fundamentals

### Hardware Considerations

**CPU Architecture Impact**
```dart
class DeviceCapabilityDetector {
  static Future<DeviceCapabilities> detect() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return DeviceCapabilities.fromAndroid(androidInfo);
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return DeviceCapabilities.fromIOS(iosInfo);
    }

    throw UnsupportedError('Unsupported platform');
  }
}

class DeviceCapabilities {
  final int estimatedCores;
  final int estimatedRamGB;
  final ProcessorArchitecture architecture;
  final PerformanceTier tier;

  const DeviceCapabilities({
    required this.estimatedCores,
    required this.estimatedRamGB,
    required this.architecture,
    required this.tier,
  });

  factory DeviceCapabilities.fromAndroid(AndroidDeviceInfo info) {
    // Device-specific optimization based on model
    final model = info.model.toLowerCase();
    final brand = info.brand.toLowerCase();

    int cores = Platform.numberOfProcessors;
    int ramGB = 4; // Default assumption

    // Device-specific configurations
    if (brand.contains('samsung')) {
      if (model.contains('s24') || model.contains('s23')) {
        ramGB = 8;
        cores = 8;
      } else if (model.contains('galaxy')) {
        ramGB = 6;
      }
    } else if (brand.contains('google')) {
      if (model.contains('pixel')) {
        ramGB = model.contains('pro') ? 12 : 8;
      }
    }

    final architecture = _detectArchitecture(info.supportedAbis);
    final tier = _calculateTier(cores, ramGB, architecture);

    return DeviceCapabilities(
      estimatedCores: cores,
      estimatedRamGB: ramGB,
      architecture: architecture,
      tier: tier,
    );
  }

  factory DeviceCapabilities.fromIOS(IosDeviceInfo info) {
    final model = info.utsname.machine;
    int cores = Platform.numberOfProcessors;
    int ramGB;

    // iOS device RAM estimation based on model
    if (model.startsWith('iPhone15')) {
      ramGB = model.contains('Pro') ? 8 : 6;
    } else if (model.startsWith('iPhone14')) {
      ramGB = model.contains('Pro') ? 6 : 4;
    } else if (model.startsWith('iPad')) {
      ramGB = model.contains('Pro') ? 16 : 8;
    } else {
      ramGB = 4; // Conservative estimate
    }

    return DeviceCapabilities(
      estimatedCores: cores,
      estimatedRamGB: ramGB,
      architecture: ProcessorArchitecture.arm64,
      tier: _calculateTier(cores, ramGB, ProcessorArchitecture.arm64),
    );
  }

  static ProcessorArchitecture _detectArchitecture(List<String> abis) {
    if (abis.contains('arm64-v8a')) return ProcessorArchitecture.arm64;
    if (abis.contains('armeabi-v7a')) return ProcessorArchitecture.arm32;
    if (abis.contains('x86_64')) return ProcessorArchitecture.x64;
    return ProcessorArchitecture.unknown;
  }

  static PerformanceTier _calculateTier(
    int cores,
    int ramGB,
    ProcessorArchitecture arch
  ) {
    final score = cores * 10 + ramGB * 5 + (arch == ProcessorArchitecture.arm64 ? 10 : 0);

    if (score >= 100) return PerformanceTier.high;
    if (score >= 60) return PerformanceTier.medium;
    return PerformanceTier.low;
  }
}

enum ProcessorArchitecture { arm64, arm32, x64, unknown }
enum PerformanceTier { low, medium, high }
```

### Optimal Configuration Selection

```dart
class PerformanceOptimizer {
  static LlamafuConfig optimizeForDevice(DeviceCapabilities device) {
    switch (device.tier) {
      case PerformanceTier.high:
        return _highEndConfig(device);
      case PerformanceTier.medium:
        return _midRangeConfig(device);
      case PerformanceTier.low:
        return _budgetConfig(device);
    }
  }

  static LlamafuConfig _highEndConfig(DeviceCapabilities device) {
    return LlamafuConfig(
      recommendedModelSize: ModelSize.large, // 13B parameters
      contextSize: 8192,
      threads: min(8, device.estimatedCores),
      quantization: Quantization.q4KM,
      batchSize: 64,
      enableGpu: true,
    );
  }

  static LlamafuConfig _midRangeConfig(DeviceCapabilities device) {
    return LlamafuConfig(
      recommendedModelSize: ModelSize.medium, // 7B parameters
      contextSize: 4096,
      threads: min(6, device.estimatedCores - 1),
      quantization: Quantization.q4KM,
      batchSize: 32,
      enableGpu: false,
    );
  }

  static LlamafuConfig _budgetConfig(DeviceCapabilities device) {
    return LlamafuConfig(
      recommendedModelSize: ModelSize.small, // 3B parameters
      contextSize: 2048,
      threads: min(4, device.estimatedCores),
      quantization: Quantization.q2K,
      batchSize: 16,
      enableGpu: false,
    );
  }
}

class LlamafuConfig {
  final ModelSize recommendedModelSize;
  final int contextSize;
  final int threads;
  final Quantization quantization;
  final int batchSize;
  final bool enableGpu;

  const LlamafuConfig({
    required this.recommendedModelSize,
    required this.contextSize,
    required this.threads,
    required this.quantization,
    required this.batchSize,
    required this.enableGpu,
  });
}

enum ModelSize { small, medium, large }
enum Quantization { fp16, q8_0, q4KM, q2K }
```

## Memory Optimization

### Memory Pool Management

```dart
class MemoryManager {
  static const int _maxHeapSize = 2 * 1024 * 1024 * 1024; // 2GB limit
  static const int _reservedMemory = 512 * 1024 * 1024; // 512MB for system

  static Future<bool> canLoadModel(String modelPath) async {
    final file = File(modelPath);
    final modelSize = await file.length();

    // Estimate runtime memory usage (model size + context + working memory)
    final estimatedUsage = modelSize + (64 * 1024 * 1024); // 64MB buffer

    return estimatedUsage < (_maxHeapSize - _reservedMemory);
  }

  static Future<void> optimizeMemoryBeforeLoad() async {
    // Force garbage collection
    for (int i = 0; i < 3; i++) {
      final List<int> temp = List.generate(1000000, (index) => index);
      temp.clear();
      await Future.delayed(Duration(milliseconds: 100));
    }
  }

  static void monitorMemoryUsage() {
    Timer.periodic(Duration(seconds: 30), (timer) {
      final info = ProcessInfo.currentRss;
      if (info > _maxHeapSize * 0.8) {
        print('WARNING: High memory usage detected: ${info ~/ (1024 * 1024)}MB');
        _triggerMemoryCleanup();
      }
    });
  }

  static void _triggerMemoryCleanup() {
    // Implement memory pressure relief
    // This could include context truncation, model unloading, etc.
  }
}
```

### Context Window Optimization

```dart
class SmartContextManager {
  final Llamafu llamafu;
  final int maxContext;
  final int preserveTokens;

  final Queue<ContextEntry> _context = Queue();
  int _currentTokens = 0;

  SmartContextManager({
    required this.llamafu,
    required this.maxContext,
    this.preserveTokens = 512, // Always preserve recent context
  });

  Future<String> processWithContext(String prompt) async {
    await _addToContext(prompt, ContextType.user);
    await _manageContextSize();

    final contextPrompt = await _buildContextPrompt();
    final response = await llamafu.complete(prompt: contextPrompt);

    await _addToContext(response, ContextType.assistant);
    return response;
  }

  Future<void> _addToContext(String content, ContextType type) async {
    final tokens = await llamafu.tokenize(content);
    final entry = ContextEntry(
      content: content,
      tokens: tokens.length,
      type: type,
      timestamp: DateTime.now(),
    );

    _context.addLast(entry);
    _currentTokens += entry.tokens;
  }

  Future<void> _manageContextSize() async {
    if (_currentTokens <= maxContext) return;

    final targetSize = maxContext - preserveTokens;

    // Remove oldest non-system entries
    while (_currentTokens > targetSize && _context.length > 1) {
      final removed = _context.removeFirst();
      if (removed.type != ContextType.system) {
        _currentTokens -= removed.tokens;
      } else {
        // Don't remove system messages, put it back
        _context.addFirst(removed);
        break;
      }
    }
  }

  Future<String> _buildContextPrompt() async {
    return _context.map((e) => e.content).join('\n');
  }
}

class ContextEntry {
  final String content;
  final int tokens;
  final ContextType type;
  final DateTime timestamp;

  ContextEntry({
    required this.content,
    required this.tokens,
    required this.type,
    required this.timestamp,
  });
}

enum ContextType { system, user, assistant }
```

## Threading and Concurrency

### Optimal Thread Configuration

```dart
class ThreadOptimizer {
  static int calculateOptimalThreads({
    required int availableCores,
    required ModelSize modelSize,
    required bool hasBackground,
    required PerformanceTier tier,
  }) {
    // Base thread calculation
    int baseThreads;
    switch (modelSize) {
      case ModelSize.small:
        baseThreads = min(4, availableCores);
        break;
      case ModelSize.medium:
        baseThreads = min(6, availableCores);
        break;
      case ModelSize.large:
        baseThreads = min(8, availableCores);
        break;
    }

    // Adjust for device tier
    switch (tier) {
      case PerformanceTier.low:
        baseThreads = min(baseThreads, 4);
        break;
      case PerformanceTier.medium:
        baseThreads = min(baseThreads, 6);
        break;
      case PerformanceTier.high:
        // Use calculated value
        break;
    }

    // Reserve cores for UI
    if (hasBackground) {
      baseThreads = max(1, baseThreads - 2);
    } else {
      baseThreads = max(1, baseThreads - 1);
    }

    return baseThreads;
  }
}
```

### Background Processing

```dart
class BackgroundInferenceManager {
  static const String _isolateName = 'llamafu_isolate';

  SendPort? _sendPort;
  Isolate? _isolate;
  final ReceivePort _receivePort = ReceivePort();

  Future<void> initialize(String modelPath) async {
    _isolate = await Isolate.spawn(
      _isolateEntryPoint,
      IsolateStartupData(
        sendPort: _receivePort.sendPort,
        modelPath: modelPath,
      ),
      debugName: _isolateName,
    );

    // Wait for isolate to be ready
    await for (final message in _receivePort) {
      if (message is SendPort) {
        _sendPort = message;
        break;
      }
    }
  }

  Future<String> generateInBackground({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.7,
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (_sendPort == null) {
      throw StateError('Background inference not initialized');
    }

    final responsePort = ReceivePort();
    final request = InferenceRequest(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
      responsePort: responsePort.sendPort,
    );

    _sendPort!.send(request);

    // Wait for response with timeout
    final response = await responsePort.first.timeout(timeout);

    if (response is InferenceError) {
      throw Exception(response.message);
    }

    return response as String;
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
  }

  static void _isolateEntryPoint(IsolateStartupData data) async {
    final port = ReceivePort();
    data.sendPort.send(port.sendPort);

    Llamafu? llamafu;

    try {
      llamafu = await Llamafu.init(
        modelPath: data.modelPath,
        threads: 2, // Conservative for background
      );

      await for (final message in port.cast<InferenceRequest>()) {
        try {
          final result = await llamafu.complete(
            prompt: message.prompt,
            maxTokens: message.maxTokens,
            temperature: message.temperature,
          );
          message.responsePort.send(result);
        } catch (e) {
          message.responsePort.send(InferenceError(e.toString()));
        }
      }
    } catch (e) {
      port.close();
    } finally {
      llamafu?.close();
    }
  }
}

class IsolateStartupData {
  final SendPort sendPort;
  final String modelPath;

  IsolateStartupData({required this.sendPort, required this.modelPath});
}

class InferenceRequest {
  final String prompt;
  final int maxTokens;
  final double temperature;
  final SendPort responsePort;

  InferenceRequest({
    required this.prompt,
    required this.maxTokens,
    required this.temperature,
    required this.responsePort,
  });
}

class InferenceError {
  final String message;
  InferenceError(this.message);
}
```

## Benchmarking and Profiling

### Performance Measurement

```dart
class PerformanceBenchmark {
  final List<BenchmarkResult> _results = [];

  Future<BenchmarkSuite> runBenchmark(Llamafu llamafu) async {
    final results = <String, BenchmarkResult>{};

    // Test 1: Short generation
    results['short_generation'] = await _benchmarkGeneration(
      llamafu,
      'The quick brown fox',
      maxTokens: 20,
      iterations: 10,
    );

    // Test 2: Medium generation
    results['medium_generation'] = await _benchmarkGeneration(
      llamafu,
      'Write a paragraph about machine learning',
      maxTokens: 100,
      iterations: 5,
    );

    // Test 3: Long generation
    results['long_generation'] = await _benchmarkGeneration(
      llamafu,
      'Write a detailed essay about artificial intelligence',
      maxTokens: 500,
      iterations: 2,
    );

    // Test 4: Tokenization speed
    results['tokenization'] = await _benchmarkTokenization(llamafu);

    return BenchmarkSuite(results);
  }

  Future<BenchmarkResult> _benchmarkGeneration(
    Llamafu llamafu,
    String prompt, {
    required int maxTokens,
    required int iterations,
  }) async {
    final times = <Duration>[];
    final tokensPerSecond = <double>[];

    for (int i = 0; i < iterations; i++) {
      final stopwatch = Stopwatch()..start();

      final result = await llamafu.complete(
        prompt: prompt,
        maxTokens: maxTokens,
      );

      stopwatch.stop();
      times.add(stopwatch.elapsed);

      final tokens = await llamafu.tokenize(result);
      final tps = tokens.length / stopwatch.elapsed.inMilliseconds * 1000;
      tokensPerSecond.add(tps);
    }

    return BenchmarkResult(
      averageTime: _calculateAverage(times),
      minTime: times.reduce((a, b) => a < b ? a : b),
      maxTime: times.reduce((a, b) => a > b ? a : b),
      averageTokensPerSecond: _calculateAverageDouble(tokensPerSecond),
      iterations: iterations,
    );
  }

  Future<BenchmarkResult> _benchmarkTokenization(Llamafu llamafu) async {
    const testText = '''
    This is a long text used for tokenization benchmarking.
    It contains multiple sentences and various punctuation marks.
    The goal is to measure how quickly we can tokenize text.
    ''';

    final times = <Duration>[];

    for (int i = 0; i < 50; i++) {
      final stopwatch = Stopwatch()..start();
      await llamafu.tokenize(testText);
      stopwatch.stop();
      times.add(stopwatch.elapsed);
    }

    return BenchmarkResult(
      averageTime: _calculateAverage(times),
      minTime: times.reduce((a, b) => a < b ? a : b),
      maxTime: times.reduce((a, b) => a > b ? a : b),
      averageTokensPerSecond: 0, // Not applicable for tokenization
      iterations: 50,
    );
  }

  Duration _calculateAverage(List<Duration> durations) {
    final totalMs = durations.fold(0, (sum, d) => sum + d.inMilliseconds);
    return Duration(milliseconds: totalMs ~/ durations.length);
  }

  double _calculateAverageDouble(List<double> values) {
    return values.fold(0.0, (sum, v) => sum + v) / values.length;
  }
}

class BenchmarkSuite {
  final Map<String, BenchmarkResult> results;

  BenchmarkSuite(this.results);

  void printReport() {
    print('=== Llamafu Performance Benchmark Report ===');

    for (final entry in results.entries) {
      final result = entry.value;
      print('\n${entry.key.toUpperCase()}:');
      print('  Average time: ${result.averageTime.inMilliseconds}ms');
      print('  Min time: ${result.minTime.inMilliseconds}ms');
      print('  Max time: ${result.maxTime.inMilliseconds}ms');
      if (result.averageTokensPerSecond > 0) {
        print('  Average tokens/sec: ${result.averageTokensPerSecond.toStringAsFixed(2)}');
      }
      print('  Iterations: ${result.iterations}');
    }
  }

  Map<String, dynamic> toJson() {
    return results.map((key, value) => MapEntry(key, value.toJson()));
  }
}

class BenchmarkResult {
  final Duration averageTime;
  final Duration minTime;
  final Duration maxTime;
  final double averageTokensPerSecond;
  final int iterations;

  BenchmarkResult({
    required this.averageTime,
    required this.minTime,
    required this.maxTime,
    required this.averageTokensPerSecond,
    required this.iterations,
  });

  Map<String, dynamic> toJson() {
    return {
      'average_time_ms': averageTime.inMilliseconds,
      'min_time_ms': minTime.inMilliseconds,
      'max_time_ms': maxTime.inMilliseconds,
      'average_tokens_per_second': averageTokensPerSecond,
      'iterations': iterations,
    };
  }
}
```

### Real-time Performance Monitoring

```dart
class PerformanceMonitor {
  final Map<String, List<Duration>> _operationTimes = {};
  final Map<String, int> _operationCounts = {};
  Timer? _reportTimer;

  void startMonitoring({Duration reportInterval = const Duration(minutes: 5)}) {
    _reportTimer = Timer.periodic(reportInterval, (_) => _generateReport());
  }

  void recordOperation(String operation, Duration duration) {
    _operationTimes.putIfAbsent(operation, () => <Duration>[]);
    _operationCounts.putIfAbsent(operation, () => 0);

    _operationTimes[operation]!.add(duration);
    _operationCounts[operation] = _operationCounts[operation]! + 1;

    // Keep only recent measurements (last 100)
    if (_operationTimes[operation]!.length > 100) {
      _operationTimes[operation]!.removeAt(0);
    }
  }

  Future<T> measureOperation<T>(String operation, Future<T> Function() function) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await function();
      stopwatch.stop();
      recordOperation(operation, stopwatch.elapsed);
      return result;
    } catch (e) {
      stopwatch.stop();
      recordOperation('${operation}_error', stopwatch.elapsed);
      rethrow;
    }
  }

  void _generateReport() {
    print('\n=== Performance Report ===');

    for (final operation in _operationTimes.keys) {
      final times = _operationTimes[operation]!;
      if (times.isEmpty) continue;

      final averageMs = times.fold(0, (sum, t) => sum + t.inMilliseconds) / times.length;
      final minMs = times.map((t) => t.inMilliseconds).reduce(min);
      final maxMs = times.map((t) => t.inMilliseconds).reduce(max);
      final count = _operationCounts[operation]!;

      print('$operation:');
      print('  Count: $count');
      print('  Average: ${averageMs.toStringAsFixed(1)}ms');
      print('  Min: ${minMs}ms');
      print('  Max: ${maxMs}ms');
    }
  }

  void stopMonitoring() {
    _reportTimer?.cancel();
    _reportTimer = null;
  }

  void reset() {
    _operationTimes.clear();
    _operationCounts.clear();
  }
}
```

## Caching and Preloading

### Model Caching Strategy

```dart
class ModelCache {
  static final Map<String, Llamafu> _cache = {};
  static const int maxCacheSize = 3;

  static Future<Llamafu> getModel(String modelPath) async {
    if (_cache.containsKey(modelPath)) {
      return _cache[modelPath]!;
    }

    // If cache is full, remove least recently used
    if (_cache.length >= maxCacheSize) {
      final oldestKey = _cache.keys.first;
      final oldModel = _cache.remove(oldestKey);
      oldModel?.close();
    }

    final model = await Llamafu.init(modelPath: modelPath);
    _cache[modelPath] = model;
    return model;
  }

  static void preloadModel(String modelPath) async {
    if (!_cache.containsKey(modelPath)) {
      try {
        await getModel(modelPath);
      } catch (e) {
        print('Failed to preload model $modelPath: $e');
      }
    }
  }

  static void clearCache() {
    for (final model in _cache.values) {
      model.close();
    }
    _cache.clear();
  }
}
```

### Response Caching

```dart
class ResponseCache {
  final Map<String, CachedResponse> _cache = {};
  final int maxSize;
  final Duration ttl;

  ResponseCache({
    this.maxSize = 1000,
    this.ttl = const Duration(hours: 1),
  });

  String? get(String prompt) {
    final cached = _cache[prompt];
    if (cached == null) return null;

    if (DateTime.now().isAfter(cached.expiresAt)) {
      _cache.remove(prompt);
      return null;
    }

    return cached.response;
  }

  void put(String prompt, String response) {
    if (_cache.length >= maxSize) {
      // Remove oldest entry
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }

    _cache[prompt] = CachedResponse(
      response: response,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void clear() => _cache.clear();
}

class CachedResponse {
  final String response;
  final DateTime expiresAt;

  CachedResponse({required this.response, required this.expiresAt});
}
```

## Advanced Optimizations

### Adaptive Batching

```dart
class AdaptiveBatcher {
  final Llamafu llamafu;
  final Queue<BatchItem> _queue = Queue();
  final int maxBatchSize;
  final Duration maxWaitTime;

  Timer? _batchTimer;
  bool _processing = false;

  AdaptiveBatcher({
    required this.llamafu,
    this.maxBatchSize = 8,
    this.maxWaitTime = const Duration(milliseconds: 100),
  });

  Future<String> process(String prompt) async {
    final completer = Completer<String>();
    final item = BatchItem(prompt, completer);

    _queue.add(item);
    _scheduleBatch();

    return completer.future;
  }

  void _scheduleBatch() {
    if (_processing) return;

    if (_queue.length >= maxBatchSize) {
      _processBatch();
    } else if (_batchTimer == null) {
      _batchTimer = Timer(maxWaitTime, _processBatch);
    }
  }

  void _processBatch() async {
    if (_processing || _queue.isEmpty) return;

    _processing = true;
    _batchTimer?.cancel();
    _batchTimer = null;

    final batch = <BatchItem>[];
    while (_queue.isNotEmpty && batch.length < maxBatchSize) {
      batch.add(_queue.removeFirst());
    }

    // Process batch items sequentially (parallel processing would need multiple contexts)
    for (final item in batch) {
      try {
        final result = await llamafu.complete(prompt: item.prompt);
        item.completer.complete(result);
      } catch (e) {
        item.completer.completeError(e);
      }
    }

    _processing = false;

    // Check if there are more items to process
    if (_queue.isNotEmpty) {
      _scheduleBatch();
    }
  }
}

class BatchItem {
  final String prompt;
  final Completer<String> completer;

  BatchItem(this.prompt, this.completer);
}
```

### Temperature Scaling

```dart
class AdaptiveTemperatureScaler {
  final double baseTemperature;
  final List<double> _recentScores = [];
  final int historySize;

  AdaptiveTemperatureScaler({
    this.baseTemperature = 0.7,
    this.historySize = 10,
  });

  double getScaledTemperature({double? qualityScore}) {
    if (qualityScore != null) {
      _recentScores.add(qualityScore);
      if (_recentScores.length > historySize) {
        _recentScores.removeAt(0);
      }
    }

    if (_recentScores.isEmpty) return baseTemperature;

    // Calculate average quality
    final averageQuality = _recentScores.reduce((a, b) => a + b) / _recentScores.length;

    // Scale temperature inversely with quality
    // Higher quality = lower temperature for consistency
    // Lower quality = higher temperature for creativity
    final scaleFactor = 1.0 - (averageQuality - 0.5) * 0.4;

    return (baseTemperature * scaleFactor).clamp(0.1, 1.5);
  }
}
```

## Performance Testing Framework

```dart
class PerformanceTestSuite {
  final Llamafu llamafu;
  final PerformanceMonitor monitor = PerformanceMonitor();

  PerformanceTestSuite(this.llamafu);

  Future<TestResults> runFullSuite() async {
    monitor.startMonitoring();

    final results = TestResults();

    // Latency tests
    results.latencyTest = await _testLatency();

    // Throughput tests
    results.throughputTest = await _testThroughput();

    // Memory tests
    results.memoryTest = await _testMemoryUsage();

    // Stability tests
    results.stabilityTest = await _testStability();

    monitor.stopMonitoring();
    return results;
  }

  Future<LatencyTestResult> _testLatency() async {
    const prompts = [
      'Hello',
      'What is AI?',
      'Explain quantum computing',
    ];

    final results = <Duration>[];

    for (final prompt in prompts) {
      for (int i = 0; i < 10; i++) {
        final result = await monitor.measureOperation(
          'latency_test',
          () => llamafu.complete(prompt: prompt, maxTokens: 1),
        );
        // Store timing from monitor
      }
    }

    return LatencyTestResult(/* results */);
  }

  Future<ThroughputTestResult> _testThroughput() async {
    const duration = Duration(minutes: 1);
    final startTime = DateTime.now();
    int completedRequests = 0;
    int totalTokens = 0;

    while (DateTime.now().difference(startTime) < duration) {
      try {
        final result = await llamafu.complete(
          prompt: 'Generate text: ${completedRequests}',
          maxTokens: 50,
        );

        final tokens = await llamafu.tokenize(result);
        totalTokens += tokens.length;
        completedRequests++;
      } catch (e) {
        // Handle errors
      }
    }

    final actualDuration = DateTime.now().difference(startTime);
    return ThroughputTestResult(
      requestsPerSecond: completedRequests / actualDuration.inSeconds,
      tokensPerSecond: totalTokens / actualDuration.inSeconds,
    );
  }

  Future<MemoryTestResult> _testMemoryUsage() async {
    // Implementation for memory usage testing
    final initialMemory = ProcessInfo.currentRss;

    // Perform memory-intensive operations
    for (int i = 0; i < 100; i++) {
      await llamafu.complete(
        prompt: 'Generate a long text about topic $i',
        maxTokens: 200,
      );
    }

    final finalMemory = ProcessInfo.currentRss;
    final memoryIncrease = finalMemory - initialMemory;

    return MemoryTestResult(
      initialMemory: initialMemory,
      finalMemory: finalMemory,
      memoryIncrease: memoryIncrease,
    );
  }

  Future<StabilityTestResult> _testStability() async {
    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    for (int i = 0; i < 1000; i++) {
      try {
        await llamafu.complete(
          prompt: 'Test prompt $i',
          maxTokens: 20,
        );
        successCount++;
      } catch (e) {
        errorCount++;
        errors.add(e.toString());
      }
    }

    return StabilityTestResult(
      successCount: successCount,
      errorCount: errorCount,
      successRate: successCount / (successCount + errorCount),
      errors: errors,
    );
  }
}

// Result classes
class TestResults {
  late LatencyTestResult latencyTest;
  late ThroughputTestResult throughputTest;
  late MemoryTestResult memoryTest;
  late StabilityTestResult stabilityTest;
}

class LatencyTestResult {
  final Duration averageLatency;
  final Duration p95Latency;
  final Duration p99Latency;

  LatencyTestResult({
    required this.averageLatency,
    required this.p95Latency,
    required this.p99Latency,
  });
}

class ThroughputTestResult {
  final double requestsPerSecond;
  final double tokensPerSecond;

  ThroughputTestResult({
    required this.requestsPerSecond,
    required this.tokensPerSecond,
  });
}

class MemoryTestResult {
  final int initialMemory;
  final int finalMemory;
  final int memoryIncrease;

  MemoryTestResult({
    required this.initialMemory,
    required this.finalMemory,
    required this.memoryIncrease,
  });
}

class StabilityTestResult {
  final int successCount;
  final int errorCount;
  final double successRate;
  final List<String> errors;

  StabilityTestResult({
    required this.successCount,
    required this.errorCount,
    required this.successRate,
    required this.errors,
  });
}
```