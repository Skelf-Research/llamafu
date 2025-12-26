# Llamafu Class

The main class for interacting with LLM models.

## Constructor

### `Llamafu.init()`

Creates and initializes a new Llamafu instance.

```dart
static Future<Llamafu> init({
  required String modelPath,
  String? mmprojPath,
  int contextSize = 2048,
  int threads = 0,
  int threadsBatch = 0,
  int gpuLayers = 0,
  bool useMmap = true,
  bool useMlock = false,
  int seed = 0,
})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `modelPath` | `String` | required | Path to the GGUF model file |
| `mmprojPath` | `String?` | null | Path to multimodal projector (for vision/audio) |
| `contextSize` | `int` | 2048 | Maximum context window size |
| `threads` | `int` | 0 | CPU threads for inference (0 = auto) |
| `threadsBatch` | `int` | 0 | CPU threads for batch processing (0 = auto) |
| `gpuLayers` | `int` | 0 | Number of layers to offload to GPU |
| `useMmap` | `bool` | true | Use memory mapping for model file |
| `useMlock` | `bool` | false | Lock model in RAM (prevents swapping) |
| `seed` | `int` | 0 | Random seed (0 = random) |

#### Example

```dart
final llamafu = await Llamafu.init(
  modelPath: 'models/llama-3.2-1b.gguf',
  contextSize: 4096,
  threads: 4,
);
```

## Properties

### Model Information

```dart
String get modelName           // Model name from metadata
int get vocabSize              // Vocabulary size
int get contextSize            // Current context size
int get embeddingSize          // Embedding dimension
int get layerCount             // Number of layers
bool get isMultimodal          // Whether model supports multimodal
int get bosToken               // Beginning of sequence token
int get eosToken               // End of sequence token
```

### State Information

```dart
int get kVCacheTokenCount      // Tokens in KV cache
int get gpuLayerCount          // Layers on GPU
bool get isLoaded              // Whether model is loaded
```

## Text Generation

### `complete()`

Generate text completion.

```dart
Future<String> complete(
  String prompt, {
  int maxTokens = 256,
  double temperature = 0.7,
  int topK = 40,
  double topP = 0.9,
  double repeatPenalty = 1.1,
  int seed = 0,
  List<String>? stopSequences,
})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | `String` | required | Input prompt |
| `maxTokens` | `int` | 256 | Maximum tokens to generate |
| `temperature` | `double` | 0.7 | Sampling temperature (0.0-2.0) |
| `topK` | `int` | 40 | Top-K sampling parameter |
| `topP` | `double` | 0.9 | Nucleus sampling threshold |
| `repeatPenalty` | `double` | 1.1 | Repetition penalty |
| `seed` | `int` | 0 | Random seed (0 = random) |
| `stopSequences` | `List<String>?` | null | Stop generation on these sequences |

### `completeStream()`

Stream tokens as they are generated.

```dart
Stream<String> completeStream(
  String prompt, {
  int maxTokens = 256,
  double temperature = 0.7,
  int topK = 40,
  double topP = 0.9,
  double repeatPenalty = 1.1,
  int seed = 0,
})
```

#### Example

```dart
await for (final token in llamafu.completeStream('Hello')) {
  print(token);
}
```

### `completeWithGrammar()`

Generate with grammar constraints.

```dart
Future<String> completeWithGrammar(
  String prompt, {
  required String grammar,
  int maxTokens = 256,
  double temperature = 0.7,
})
```

### `completeWithSampler()`

Generate using a custom sampler chain.

```dart
Future<String> completeWithSampler(
  String prompt, {
  required SamplerChain sampler,
  int maxTokens = 256,
})
```

## Tokenization

### `tokenize()`

Convert text to tokens.

```dart
List<int> tokenize(String text)
```

### `detokenize()`

Convert tokens to text.

```dart
String detokenize(List<int> tokens)
```

### `tokenToPiece()`

Get text representation of a single token.

```dart
String tokenToPiece(int token)
```

## Chat

### `applyChatTemplate()`

Apply chat template to messages.

```dart
String applyChatTemplate(
  String template,      // Empty string for model default
  List<String> messages,
  {bool addAssistant = true}
)
```

### `createChatSession()`

Create a managed chat session.

```dart
ChatSession createChatSession({
  String? systemPrompt,
  List<ChatMessage>? history,
})
```

## Embeddings

### `getEmbeddings()`

Get text embeddings.

```dart
List<double> getEmbeddings(String text)
```

## Memory Management

### `getMemoryUsage()`

Get current memory usage.

```dart
MemoryInfo getMemoryUsage()

class MemoryInfo {
  int modelSize;
  int contextSize;
  int scratchSize;
  int totalSize;
}
```

### `clearKvCache()`

Clear the KV cache.

```dart
void clearKvCache()
```

### `defragmentKvCache()`

Defragment KV cache for better performance.

```dart
void defragmentKvCache()
```

## LoRA Adapters

### `loadLoraAdapter()`

Load a LoRA adapter.

```dart
Future<LoraAdapter> loadLoraAdapter(
  String path, {
  double scale = 1.0,
})
```

### `unloadLoraAdapter()`

Unload a LoRA adapter.

```dart
void unloadLoraAdapter(int adapterId)
```

### `setLoraScale()`

Adjust adapter scale at runtime.

```dart
void setLoraScale(int adapterId, double scale)
```

### `getLoadedAdapters()`

List loaded adapters.

```dart
List<LoraAdapter> getLoadedAdapters()
```

### `clearLoraAdapters()`

Unload all adapters.

```dart
void clearLoraAdapters()
```

## Performance

### `warmup()`

Warm up model caches.

```dart
Future<void> warmup()
```

### `benchmark()`

Run benchmark.

```dart
BenchmarkStats benchmark({
  int promptTokens = 128,
  int generatedTokens = 128,
})
```

### `getPerformanceStats()`

Get performance statistics.

```dart
PerformanceStats getPerformanceStats()
```

### `setThreadCount()`

Update thread configuration.

```dart
void setThreadCount({int? threads, int? threadsBatch})
```

## Abort Control

### `setAbortCallback()`

Set callback to check for abort.

```dart
void setAbortCallback(bool Function() callback)
```

#### Example

```dart
bool shouldAbort = false;

llamafu.setAbortCallback(() => shouldAbort);

// Later, to abort:
shouldAbort = true;
```

## State Management

### `saveState()`

Save model state to file.

```dart
Future<void> saveState(String path)
```

### `loadState()`

Load model state from file.

```dart
Future<void> loadState(String path)
```

## Disposal

### `dispose()`

Release all resources.

```dart
void dispose()
```

!!! warning "Important"
    Always call `dispose()` when done to prevent memory leaks.

## Static Methods

### `getSystemInfo()`

Get system information string.

```dart
static String getSystemInfo()
```

## Error Handling

All methods may throw `LlamafuError` or its subclasses:

- `LlamafuModelLoadError` - Model loading failed
- `LlamafuInferenceError` - Inference failed
- `LlamafuMultimodalError` - Multimodal operation failed
- `LlamafuLoraError` - LoRA operation failed

```dart
try {
  await llamafu.complete(prompt);
} on LlamafuError catch (e) {
  print('Error: ${e.message}, Code: ${e.code}');
}
```
