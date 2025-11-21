# Llamafu

A Flutter FFI plugin for running large language models on-device using llama.cpp. Provides high-performance inference with support for text generation, multimodal inputs, LoRA adapters, and structured output.

## Features

- On-device inference without network dependency
- Cross-platform support for Android and iOS
- Multimodal processing (images, audio)
- Dynamic LoRA adapter loading
- Tool calling (function calling) support
- Structured JSON output generation
- Grammar-constrained generation
- Streaming token generation
- Embeddings generation
- Advanced sampling controls

## Requirements

- Flutter 3.10.0+
- Dart SDK 3.1.0+
- Android: API 21+ (Android 5.0), NDK 21+
- iOS: 12.0+, Xcode 14+
- GGUF format models

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  llamafu: ^0.0.1
```

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:llamafu/llamafu.dart';

// Initialize with model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/model.gguf',
  threads: 4,
  contextSize: 2048,
);

// Generate text
final result = await llamafu.complete(
  prompt: 'Explain quantum computing:',
  maxTokens: 256,
  temperature: 0.7,
);

print(result);

// Clean up
llamafu.close();
```

## Documentation

- [Getting Started](docs/getting-started.md) - Installation and setup
- [High-Level APIs](docs/high-level-apis.md) - Chat, LoRA, and Multimodal APIs
- [Tool Calling](docs/tool-calling.md) - Tool calling and JSON output
- [API Reference](docs/api-reference.md) - Complete API documentation
- [Architecture](docs/architecture.md) - Technical design and internals
- [Building](docs/building.md) - Build from source
- [Model Guide](docs/model-guide.md) - Model selection and formats
- [Performance Guide](docs/performance-guide.md) - Optimization techniques
- [Contributing](docs/contributing.md) - Development guidelines

## Usage Examples

### Text Generation

```dart
final result = await llamafu.complete(
  prompt: 'Write a function to sort an array:',
  maxTokens: 300,
  temperature: 0.7,
  topK: 40,
  topP: 0.9,
  repeatPenalty: 1.1,
);
```

### Multimodal (Vision)

```dart
// Load vision model with projection
final llamafu = await Llamafu.init(
  modelPath: '/path/to/llava-model.gguf',
  mmprojPath: '/path/to/mmproj.gguf',
);

final result = await llamafu.multimodalComplete(
  prompt: 'Describe this image:',
  mediaInputs: [
    MediaInput(type: MediaType.image, data: '/path/to/image.jpg'),
  ],
  maxTokens: 200,
);
```

### LoRA Adapters

```dart
// Load and apply adapter
final adapter = await llamafu.loadLoraAdapter('/path/to/adapter.gguf');
await llamafu.applyLoraAdapter(adapter, scale: 0.8);

// Generate with adapter
final result = await llamafu.complete(
  prompt: 'Translate to French: Hello',
  maxTokens: 50,
);

// Remove adapter
await llamafu.removeLoraAdapter(adapter);
```

### Structured Output

```dart
const jsonGrammar = '''
root ::= object
object ::= "{" ws string ":" ws value "}" ws
string ::= "\\"" [a-zA-Z]+ "\\""
value ::= string | number
number ::= [0-9]+
ws ::= [ ]*
''';

final result = await llamafu.completeWithGrammar(
  prompt: 'Generate user data:',
  grammarStr: jsonGrammar,
  grammarRoot: 'root',
  maxTokens: 100,
);
```

### Tool Calling

```dart
// Define tools
final weatherTool = Tool(
  name: 'get_weather',
  description: 'Get weather for a location',
  parameters: {
    'type': 'object',
    'properties': {
      'location': {'type': 'string'},
    },
    'required': ['location'],
  },
);

// Generate tool call
final toolCall = await llamafu.generateToolCall(
  prompt: "What's the weather in Paris?",
  tools: [weatherTool],
);

print(toolCall.name);       // "get_weather"
print(toolCall.arguments);  // {"location": "Paris"}
```

### JSON Output

```dart
// Generate JSON matching a schema
final result = await llamafu.generateJson(
  prompt: 'Extract: John is 25 years old',
  schema: {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'age': {'type': 'integer'},
    },
    'required': ['name', 'age'],
  },
);

print(result);  // {"name": "John", "age": 25}
```

### Tokenization

```dart
// Tokenize
final tokens = await llamafu.tokenize('Hello world');
print('Token count: ${tokens.length}');

// Detokenize
final text = await llamafu.detokenize(tokens);

// Model info
final info = await llamafu.getModelInfo();
print('Vocab: ${info.vocabularySize}');
print('Context: ${info.contextLength}');
```

## Supported Models

Text models:
- LLaMA 2, LLaMA 3
- Mistral, Mixtral
- Phi-2, Phi-3
- Qwen, Qwen2
- Code LLaMA

Vision models:
- LLaVA
- Qwen2-VL
- Moondream

All models must be in GGUF format. Quantized models (Q4_K_M, Q8_0) are recommended for mobile.

## Building from Source

```bash
# Clone with submodules
git clone --recursive https://github.com/dipankar/llamafu.git
cd llamafu

# Setup environment
make setup

# Build native libraries
make build

# Run tests
make test
```

Platform-specific builds:

```bash
# Android
make build-android

# iOS
make build-ios

# Local development with GPU
make build-local
```

## Project Structure

```
llamafu/
├── lib/src/
│   ├── llamafu_base.dart       # High-level Dart API
│   └── llamafu_bindings.dart   # FFI bindings
├── android/src/main/cpp/
│   ├── llamafu.h               # C API header
│   └── llamafu.cpp             # Native implementation
├── ios/Classes/                # iOS native code
├── llama.cpp/                  # llama.cpp submodule
├── test/                       # Test suite
├── example/                    # Example app
└── docs/                       # Documentation
```

## Performance Tips

- Use quantized models (Q4_K_M) for mobile deployment
- Set context size based on available memory
- Use `threads: Platform.numberOfProcessors - 1`
- Enable GPU offloading where available
- Implement proper resource cleanup with `close()`

## Error Handling

```dart
try {
  final result = await llamafu.complete(
    prompt: input,
    maxTokens: 200,
  );
} on LlamafuException catch (e) {
  switch (e.code) {
    case LlamafuErrorCode.modelLoadFailed:
      // Handle model loading error
      break;
    case LlamafuErrorCode.outOfMemory:
      // Handle memory error
      break;
    default:
      // Handle other errors
  }
}
```

## License

MIT License. See [LICENSE](LICENSE) for details.

llama.cpp is licensed under the MIT License.

## Contributing

See [docs/contributing.md](docs/contributing.md) for development guidelines.

## Support

- Issues: https://github.com/dipankar/llamafu/issues
- Documentation: [docs/](docs/)

## Acknowledgments

- [llama.cpp](https://github.com/ggerganov/llama.cpp) - Inference engine
- [ggml](https://github.com/ggerganov/ggml) - Tensor library
