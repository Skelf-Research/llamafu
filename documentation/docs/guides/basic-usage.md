# Basic Usage

This guide covers the fundamental concepts and patterns for using Llamafu.

## Model Lifecycle

### Initialization

Always initialize the model before use:

```dart
final llamafu = await Llamafu.init(
  modelPath: 'path/to/model.gguf',
  contextSize: 2048,        // Context window size
  threads: 4,               // CPU threads (0 = auto)
  gpuLayers: 0,             // Layers to offload to GPU
  useMmap: true,            // Memory-map model file
  useMlock: false,          // Lock model in RAM
);
```

### Disposal

Always dispose when done to free resources:

```dart
llamafu.dispose();
```

!!! warning "Memory Leaks"
    Failing to call `dispose()` will leak native memory. Use try/finally or Flutter's dispose pattern.

## Model Information

Query model properties after initialization:

```dart
print('Model: ${llamafu.modelName}');
print('Vocab size: ${llamafu.vocabSize}');
print('Context size: ${llamafu.contextSize}');
print('Embedding size: ${llamafu.embeddingSize}');
print('Is multimodal: ${llamafu.isMultimodal}');
```

## Text Completion

### Basic Completion

```dart
final response = await llamafu.complete(
  'The quick brown fox',
  maxTokens: 50,
);
```

### With Parameters

```dart
final response = await llamafu.complete(
  'Write a poem about nature:',
  maxTokens: 200,
  temperature: 0.8,      // Creativity (0.0 - 2.0)
  topK: 40,              // Top-K sampling
  topP: 0.9,             // Nucleus sampling
  repeatPenalty: 1.1,    // Repetition penalty
  seed: 42,              // Reproducible output
);
```

### Streaming

For real-time output:

```dart
final stream = llamafu.completeStream(
  'Once upon a time',
  maxTokens: 100,
);

await for (final token in stream) {
  print(token); // Each token as generated
}
```

## Tokenization

### Encode Text to Tokens

```dart
final tokens = llamafu.tokenize('Hello, world!');
print('Token count: ${tokens.length}');
print('Tokens: $tokens');
```

### Decode Tokens to Text

```dart
final text = llamafu.detokenize([1, 2, 3, 4]);
print('Text: $text');
```

### Token Information

```dart
// Get text representation of a single token
final piece = llamafu.tokenToPiece(1234);

// Special tokens
final bosToken = llamafu.bosToken;  // Beginning of sequence
final eosToken = llamafu.eosToken;  // End of sequence
```

## Memory Management

### Check Memory Usage

```dart
final memoryInfo = llamafu.getMemoryUsage();
print('Model size: ${memoryInfo.modelSize} bytes');
print('Context size: ${memoryInfo.contextSize} bytes');
print('Total: ${memoryInfo.totalSize} bytes');
```

### KV Cache Management

```dart
// Clear the key-value cache
llamafu.clearKvCache();

// Defragment cache for better performance
llamafu.defragmentKvCache();
```

## Error Handling

Llamafu throws typed exceptions for different error conditions:

```dart
try {
  final llamafu = await Llamafu.init(modelPath: 'model.gguf');
  final response = await llamafu.complete('Hello');
} on LlamafuModelLoadError catch (e) {
  print('Failed to load model: $e');
} on LlamafuInferenceError catch (e) {
  print('Inference failed: $e');
} on LlamafuError catch (e) {
  print('General error: $e');
}
```

## Thread Safety

!!! info "Single-Threaded Design"
    Llamafu instances are not thread-safe. Use a single instance per isolate, or use Dart isolates for parallel inference.

### Using Isolates

```dart
// In a separate isolate
void inferenceIsolate(SendPort sendPort) async {
  final llamafu = await Llamafu.init(modelPath: 'model.gguf');

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final prompt in receivePort) {
    final response = await llamafu.complete(prompt);
    sendPort.send(response);
  }
}
```

## Best Practices

### 1. Reuse Instances

```dart
// Good: Reuse the same instance
class ModelService {
  late final Llamafu _llamafu;

  Future<void> init() async {
    _llamafu = await Llamafu.init(modelPath: 'model.gguf');
  }

  Future<String> generate(String prompt) {
    return _llamafu.complete(prompt);
  }
}
```

### 2. Handle Cancellation

```dart
// Set up abort callback
llamafu.setAbortCallback(() {
  return _shouldCancel; // Return true to abort
});

// Trigger cancellation
_shouldCancel = true;
```

### 3. Warm Up the Model

```dart
// Run a small completion to warm up caches
await llamafu.warmup();
```

### 4. Use Appropriate Context Size

```dart
// Smaller context = less memory, faster inference
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  contextSize: 512,  // Use smallest size that fits your use case
);
```

## Next Steps

- [Text Generation](text-generation.md) - Advanced generation options
- [Chat Sessions](chat-sessions.md) - Conversational interfaces
- [Performance Tuning](performance.md) - Optimization strategies
