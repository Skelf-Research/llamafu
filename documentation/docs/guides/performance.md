# Performance Tuning

Optimize Llamafu for speed and memory efficiency.

## Benchmarking

### Quick Benchmark

```dart
await llamafu.warmup();  // Warm up caches

final stats = llamafu.benchmark(
  promptTokens: 128,
  generatedTokens: 128,
);

print('Prompt eval: ${stats.promptTokensPerSecond} tok/s');
print('Generation: ${stats.generationTokensPerSecond} tok/s');
print('Total time: ${stats.totalTimeMs}ms');
```

### Detailed Performance Stats

```dart
final response = await llamafu.complete(prompt);
final perfStats = llamafu.getPerformanceStats();

print('Time to first token: ${perfStats.timeToFirstTokenMs}ms');
print('Prompt tokens: ${perfStats.promptTokens}');
print('Generated tokens: ${perfStats.generatedTokens}');
print('Memory peak: ${perfStats.memoryPeakMb}MB');
```

## Memory Optimization

### Model Quantization

Choose appropriate quantization for your device:

| Quantization | Size vs F16 | Quality | Use Case |
|--------------|-------------|---------|----------|
| Q2_K | ~15% | Lower | Extreme memory constraints |
| Q4_0 | ~25% | Good | Mobile/embedded |
| Q4_K_M | ~30% | Better | Balanced mobile |
| Q5_K_M | ~35% | Great | Desktop |
| Q8_0 | ~50% | Excellent | High-end desktop |
| F16 | 100% | Best | GPU with VRAM |

### Context Size

Smaller context = less memory:

```dart
// Minimum for short interactions
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  contextSize: 512,  // ~100 words
);

// Standard for chat
contextSize: 2048  // ~400 words

// Long document processing
contextSize: 8192  // ~1600 words
```

### Memory Mapping

Enable mmap to reduce RAM usage:

```dart
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  useMmap: true,   // Memory-map model file
  useMlock: false, // Don't lock in RAM
);
```

### Check Memory Usage

```dart
final mem = llamafu.getMemoryUsage();
print('Model: ${(mem.modelSize / 1e6).toStringAsFixed(1)}MB');
print('Context: ${(mem.contextSize / 1e6).toStringAsFixed(1)}MB');
print('Scratch: ${(mem.scratchSize / 1e6).toStringAsFixed(1)}MB');
print('Total: ${(mem.totalSize / 1e6).toStringAsFixed(1)}MB');
```

## CPU Optimization

### Thread Configuration

```dart
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  threads: 4,       // Inference threads
  threadsBatch: 4,  // Batch processing threads
);
```

Recommended thread counts:

| Device | Threads |
|--------|---------|
| Mobile (4 core) | 2-3 |
| Mobile (8 core) | 4-6 |
| Desktop (8 core) | 6-8 |
| Desktop (16+ core) | 8-12 |

!!! note
    More threads isn't always faster. Test to find the optimal value.

### Runtime Thread Adjustment

```dart
llamafu.setThreadCount(threads: 4, threadsBatch: 2);
```

## GPU Acceleration

### Metal (macOS/iOS)

GPU is automatically used on Apple Silicon:

```dart
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  gpuLayers: 99,  // Offload all layers to GPU
);
```

### Check GPU Usage

```dart
print('GPU layers: ${llamafu.gpuLayerCount}');
print('GPU memory: ${llamafu.gpuMemoryUsage}MB');
```

### Partial GPU Offload

For limited VRAM:

```dart
// Offload only some layers
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  gpuLayers: 20,  // First 20 layers on GPU
);
```

## Batch Processing

### Batch Inference

Process multiple prompts efficiently:

```dart
// Less efficient: sequential
for (final prompt in prompts) {
  await llamafu.complete(prompt);
}

// More efficient: batch
final responses = await llamafu.completeBatch(prompts);
```

### Optimal Batch Size

```dart
// Test different batch sizes
for (final batchSize in [1, 4, 8, 16]) {
  final start = DateTime.now();
  await llamafu.completeBatch(prompts.take(batchSize).toList());
  final elapsed = DateTime.now().difference(start);
  print('Batch $batchSize: ${elapsed.inMilliseconds}ms');
}
```

## KV Cache Optimization

### Defragmentation

```dart
// Defragment after many generations
llamafu.defragmentKvCache();
```

### Clear Cache

```dart
// Clear cache when switching contexts
llamafu.clearKvCache();
```

### Sequence Management

```dart
// Remove specific sequence from cache
llamafu.removeSequence(sequenceId: 0);

// Keep cache for continuation
final cachedTokens = llamafu.kVCacheTokenCount;
```

## Startup Optimization

### Warm-up

```dart
// Warm up before critical operations
await llamafu.warmup();
```

### Preload Model

```dart
class ModelService {
  static Llamafu? _instance;

  static Future<Llamafu> get() async {
    _instance ??= await Llamafu.init(modelPath: 'model.gguf');
    return _instance!;
  }
}

// Preload during app startup
void main() async {
  ModelService.get();  // Start loading immediately
  runApp(MyApp());
}
```

## Mobile-Specific Tips

### Android

```dart
// Reduce memory pressure
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  contextSize: 1024,  // Smaller context
  useMmap: true,      // Memory mapping
  threads: 4,         // Don't use all cores
);
```

### iOS

```dart
// Leverage Metal GPU
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  gpuLayers: 99,  // Full GPU offload
);
```

### Background Processing

```dart
// Use isolates for inference
final isolate = await Isolate.spawn(inferenceWorker, modelPath);
```

## Profiling

### Token-level Timing

```dart
final stopwatch = Stopwatch()..start();
int tokenCount = 0;

await for (final token in llamafu.completeStream(prompt)) {
  tokenCount++;
  if (tokenCount % 10 == 0) {
    print('$tokenCount tokens in ${stopwatch.elapsedMilliseconds}ms');
  }
}
```

### Memory Profiling

```dart
// Before inference
final memBefore = llamafu.getMemoryUsage().totalSize;

await llamafu.complete(longPrompt);

// After inference
final memAfter = llamafu.getMemoryUsage().totalSize;
print('Memory delta: ${(memAfter - memBefore) / 1e6}MB');
```

## Performance Checklist

- [ ] Use quantized models (Q4_K_M recommended)
- [ ] Set appropriate context size
- [ ] Enable memory mapping
- [ ] Configure optimal thread count
- [ ] Warm up before benchmarking
- [ ] Use GPU when available
- [ ] Batch similar operations
- [ ] Defragment KV cache periodically
- [ ] Profile before optimizing

## Next Steps

- [Building from Source](building.md) - Custom builds
- [Platform Notes](platforms.md) - Platform-specific optimizations
- [API Reference](../api/llamafu.md)
