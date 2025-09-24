# API Reference

This document provides comprehensive reference documentation for the Llamafu Flutter package API.

## Core Classes

### Llamafu

The main class for interacting with language models.

```dart
class Llamafu {
  static Future<Llamafu> init({
    required String modelPath,
    String? mmprojPath,
    int threads = 4,
    int contextSize = 2048,
    bool useGpu = false,
  });

  Future<String> complete({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.7,
    int? topK,
    double? topP,
    double? repeatPenalty,
    int? seed,
  });

  Future<String> completeWithGrammar({
    required String prompt,
    required String grammarStr,
    required String grammarRoot,
    int maxTokens = 128,
    double temperature = 0.7,
    int? topK,
    double? topP,
    double? repeatPenalty,
    int? seed,
  });

  Future<String> multimodalComplete({
    required String prompt,
    required List<MediaInput> mediaInputs,
    int maxTokens = 128,
    double temperature = 0.7,
  });

  Future<LoraAdapter> loadLoraAdapter(String path);
  Future<void> applyLoraAdapter(LoraAdapter adapter, {double scale = 1.0});
  Future<void> removeLoraAdapter(LoraAdapter adapter);
  Future<void> clearAllLoraAdapters();

  Future<List<int>> tokenize(String text);
  Future<String> detokenize(List<int> tokens);
  Future<ModelInfo> getModelInfo();
  Future<List<double>> getEmbeddings(String text);

  void close();
}
```

## Data Classes

### ModelInfo

Contains information about the loaded model.

```dart
class ModelInfo {
  final int vocabularySize;
  final int contextLength;
  final int embeddingDimensions;
  final int layerCount;
  final String architecture;
}
```

### MediaInput

Represents media input for multi-modal processing.

```dart
class MediaInput {
  final MediaType type;
  final String data; // Path to file or base64 encoded data
  final int? size;

  const MediaInput({
    required this.type,
    required this.data,
    this.size,
  });
}
```

### MediaType

Enumeration of supported media types.

```dart
enum MediaType {
  text,
  image,
  audio,
}
```

### LoraAdapter

Handle for LoRA adapters.

```dart
abstract class LoraAdapter {
  String get path;
  bool get isLoaded;
  void dispose();
}
```

## Exceptions

### LlamafuException

Base exception class for all Llamafu-related errors.

```dart
class LlamafuException implements Exception {
  final String message;
  final LlamafuErrorCode code;
  final dynamic cause;

  const LlamafuException(this.message, this.code, [this.cause]);
}
```

### LlamafuErrorCode

Error codes for different types of failures.

```dart
enum LlamafuErrorCode {
  unknown,
  invalidParam,
  modelLoadFailed,
  outOfMemory,
  multimodalNotSupported,
  loraLoadFailed,
  loraNotFound,
  grammarInitFailed,
}
```

## Initialization Parameters

### Model Loading

- **modelPath** (required): Path to the GGUF model file
- **mmprojPath** (optional): Path to multi-modal projector file for vision/audio models
- **threads**: Number of CPU threads to use (default: 4)
- **contextSize**: Maximum context length in tokens (default: 2048)
- **useGpu**: Enable GPU acceleration for multi-modal processing (default: false)

### Text Generation Parameters

- **prompt** (required): Input text prompt
- **maxTokens**: Maximum number of tokens to generate (default: 128)
- **temperature**: Sampling temperature, 0.0-2.0 (default: 0.7)
- **topK**: Top-K sampling, limits to K most likely tokens (optional)
- **topP**: Top-P (nucleus) sampling, 0.0-1.0 (optional)
- **repeatPenalty**: Repetition penalty, 1.0+ (optional)
- **seed**: Random seed for reproducible generation (optional)

### Grammar Parameters

- **grammarStr** (required): GBNF grammar definition
- **grammarRoot** (required): Root symbol name in grammar
- All text generation parameters also apply

### Multi-modal Parameters

- **mediaInputs** (required): List of MediaInput objects
- All basic text generation parameters apply

## Method Details

### Static Methods

#### `Llamafu.init()`

Initializes a new Llamafu instance with the specified model.

**Parameters:**
- `modelPath`: Path to GGUF model file
- `mmprojPath`: Optional path to multi-modal projector
- `threads`: CPU thread count (1-16)
- `contextSize`: Context window size in tokens (1-32768)
- `useGpu`: Enable GPU acceleration

**Returns:** `Future<Llamafu>`

**Throws:** `LlamafuException` if model loading fails

**Example:**
```dart
final llamafu = await Llamafu.init(
  modelPath: '/storage/models/llama-7b.gguf',
  threads: 6,
  contextSize: 4096,
);
```

### Instance Methods

#### `complete()`

Generates text completion for the given prompt.

**Parameters:**
- `prompt`: Input text prompt
- `maxTokens`: Maximum tokens to generate (1-2048)
- `temperature`: Sampling temperature (0.0-2.0)
- `topK`: Top-K sampling (1-100, optional)
- `topP`: Nucleus sampling threshold (0.0-1.0, optional)
- `repeatPenalty`: Repetition penalty (0.5-2.0, optional)
- `seed`: Random seed (optional)

**Returns:** `Future<String>`

**Example:**
```dart
final result = await llamafu.complete(
  prompt: 'Explain machine learning:',
  maxTokens: 200,
  temperature: 0.8,
  topK: 40,
  topP: 0.9,
);
```

#### `completeWithGrammar()`

Generates text following a GBNF grammar specification.

**Parameters:**
- `grammarStr`: GBNF grammar definition
- `grammarRoot`: Root symbol name
- All `complete()` parameters also apply

**Returns:** `Future<String>`

**Example:**
```dart
const grammar = '''
root ::= object
object ::= "{" ws (pair ("," ws pair)*)? "}" ws
pair ::= string ":" ws value
# ... rest of JSON grammar
''';

final result = await llamafu.completeWithGrammar(
  prompt: 'Generate user profile:',
  grammarStr: grammar,
  grammarRoot: 'root',
  maxTokens: 150,
);
```

#### `multimodalComplete()`

Processes multi-modal input (text + images/audio).

**Parameters:**
- `mediaInputs`: List of media files/data
- All basic generation parameters apply

**Returns:** `Future<String>`

**Example:**
```dart
final result = await llamafu.multimodalComplete(
  prompt: 'What do you see in this image?',
  mediaInputs: [
    MediaInput(type: MediaType.image, data: '/path/to/image.jpg'),
  ],
  maxTokens: 100,
);
```

#### LoRA Methods

##### `loadLoraAdapter()`

Loads a LoRA adapter from file.

**Parameters:**
- `path`: Path to LoRA GGUF file

**Returns:** `Future<LoraAdapter>`

##### `applyLoraAdapter()`

Applies a loaded LoRA adapter.

**Parameters:**
- `adapter`: LoRA adapter instance
- `scale`: Application scale (0.0-2.0, default: 1.0)

**Returns:** `Future<void>`

##### `removeLoraAdapter()`

Removes a specific LoRA adapter.

**Parameters:**
- `adapter`: LoRA adapter to remove

**Returns:** `Future<void>`

##### `clearAllLoraAdapters()`

Removes all active LoRA adapters.

**Returns:** `Future<void>`

#### Utility Methods

##### `tokenize()`

Converts text to token IDs.

**Parameters:**
- `text`: Input text

**Returns:** `Future<List<int>>`

##### `detokenize()`

Converts token IDs back to text.

**Parameters:**
- `tokens`: List of token IDs

**Returns:** `Future<String>`

##### `getModelInfo()`

Retrieves model metadata.

**Returns:** `Future<ModelInfo>`

##### `getEmbeddings()`

Generates text embeddings for semantic similarity.

**Parameters:**
- `text`: Input text

**Returns:** `Future<List<double>>`

##### `close()`

Releases model resources. Must be called when done.

**Returns:** `void`

## Error Handling

All async methods can throw `LlamafuException`. Handle errors appropriately:

```dart
try {
  final result = await llamafu.complete(prompt: 'Hello');
} on LlamafuException catch (e) {
  switch (e.code) {
    case LlamafuErrorCode.modelLoadFailed:
      // Handle model loading error
      break;
    case LlamafuErrorCode.outOfMemory:
      // Handle memory error
      break;
    case LlamafuErrorCode.invalidParam:
      // Handle invalid parameter
      break;
    default:
      // Handle other errors
      break;
  }
}
```

## Best Practices

### Resource Management

Always dispose of resources properly:

```dart
Llamafu? llamafu;
try {
  llamafu = await Llamafu.init(/* ... */);
  // Use llamafu...
} finally {
  llamafu?.close();
}
```

### Context Management

Monitor context usage to avoid truncation:

```dart
final modelInfo = await llamafu.getModelInfo();
final availableContext = modelInfo.contextLength - currentTokenCount;
final maxTokens = min(requestedTokens, availableContext);
```

### Performance Optimization

Configure thread count based on device capabilities:

```dart
final threads = Platform.numberOfProcessors - 1; // Leave one core free
final llamafu = await Llamafu.init(
  modelPath: modelPath,
  threads: threads.clamp(1, 8), // Cap at reasonable limit
);
```

### Memory Considerations

Choose appropriate context sizes:

```dart
// For chat applications
final contextSize = 4096;

// For long-form generation
final contextSize = 8192;

// For memory-constrained devices
final contextSize = 2048;
```