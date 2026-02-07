# Llamafu

[![pub package](https://img.shields.io/pub/v/llamafu.svg)](https://pub.dev/packages/llamafu)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-android%20%7C%20ios-lightgrey.svg)](https://flutter.dev)
[![Dart 3](https://img.shields.io/badge/Dart-3.1+-00B4AB.svg)](https://dart.dev)
[![Flutter 3](https://img.shields.io/badge/Flutter-3.10+-02569B.svg)](https://flutter.dev)
[![llama.cpp](https://img.shields.io/badge/powered%20by-llama.cpp-orange.svg)](https://github.com/ggerganov/llama.cpp)

**Run AI models directly on mobile devices. No cloud. No latency. Complete privacy.**

Llamafu is a Flutter FFI plugin that brings the power of large language models to your mobile apps. Built on [llama.cpp](https://github.com/ggerganov/llama.cpp), it delivers high-performance inference with support for text generation, vision, tool calling, and more—all running locally on the device.

## Why Llamafu?

| Feature | Benefit |
|---------|---------|
| **100% On-Device** | No API keys, no network calls, works offline |
| **Privacy First** | Data never leaves the device |
| **Low Latency** | No round-trip to cloud servers |
| **Cost Effective** | No per-token API charges |

## Features

**Core Capabilities**
- Text generation with streaming support
- Chat completions with conversation history
- Embeddings generation for semantic search

**Advanced AI**
- Vision/multimodal (images, audio) with LLaVA, Qwen2-VL
- Tool calling / function calling
- Structured JSON output with schema validation
- Grammar-constrained generation (GBNF)

**Customization**
- LoRA adapter loading and hot-swapping
- Fine-grained sampling controls (temperature, top-k, top-p, penalties)
- Configurable context size and threading

**Platform Support**
- Android (API 21+) and iOS (12.0+)
- Optimized native code via FFI
- GPU acceleration where available

## Requirements

| Platform | Minimum Version |
|----------|-----------------|
| Flutter | 3.10.0+ |
| Dart SDK | 3.1.0+ |
| Android | API 21+ (Android 5.0), NDK 21+ |
| iOS | 12.0+, Xcode 14+ |

Models must be in [GGUF format](https://github.com/ggerganov/ggml/blob/master/docs/gguf.md). Quantized versions (Q4_K_M, Q8_0) recommended for mobile.

## Installation

```bash
flutter pub add llamafu
```

Or add manually to `pubspec.yaml`:

```yaml
dependencies:
  llamafu: ^0.1.0
```

## Quick Start

```dart
import 'package:llamafu/llamafu.dart';

void main() async {
  // Load a GGUF model
  final llamafu = await Llamafu.init(
    modelPath: '/path/to/model.gguf',
    threads: 4,
    contextSize: 2048,
  );

  // Generate text
  final result = await llamafu.complete(
    prompt: 'Explain quantum computing in simple terms:',
    maxTokens: 256,
    temperature: 0.7,
  );

  print(result);

  // Always clean up resources
  llamafu.close();
}
```

That's it! The model runs entirely on the device—no internet required.

## Documentation

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | Installation and first steps |
| [Model Guide](docs/model-guide.md) | Choosing and obtaining models |
| [High-Level APIs](docs/high-level-apis.md) | Chat, LoRA, and multimodal |
| [Tool Calling](docs/tool-calling.md) | Function calling and JSON output |
| [Performance Guide](docs/performance-guide.md) | Memory and speed optimization |
| [API Reference](docs/api-reference.md) | Complete API documentation |
| [Architecture](docs/architecture.md) | Technical design (for contributors) |
| [Building](docs/building.md) | Build from source |
| [Contributing](docs/contributing.md) | Development guidelines |

---

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

Works with any GGUF-format model. Popular choices for mobile:

| Category | Models |
|----------|--------|
| **General** | LLaMA 3, Mistral, Phi-3, Qwen2, Gemma 2 |
| **Code** | Code LLaMA, DeepSeek Coder, StarCoder2 |
| **Vision** | LLaVA, Qwen2-VL, Moondream |
| **Small/Fast** | Phi-3 Mini, TinyLlama, Gemma 2B |

**Recommended quantizations for mobile:** Q4_K_M (best quality/size), Q4_0 (fastest), Q8_0 (highest quality)

Find models at [Hugging Face](https://huggingface.co/models?library=gguf) or convert your own with [llama.cpp](https://github.com/ggerganov/llama.cpp).

---

## For Developers

### Building from Source

```bash
# Clone with submodules
git clone --recursive https://github.com/skelf-research/llamafu.git
cd llamafu

# Setup development environment
make setup

# Build and test
make build
make test
```

**Platform-specific builds:**

```bash
make build-android    # Android AAR
make build-ios        # iOS framework
make build-local      # Local dev with GPU support
```

### Project Structure

```
llamafu/
├── lib/src/
│   ├── llamafu_base.dart       # High-level Dart API
│   └── llamafu_bindings.dart   # FFI bindings (dart:ffi)
├── android/src/main/cpp/
│   ├── llamafu.h               # C API header
│   └── llamafu.cpp             # Native implementation
├── ios/Classes/                # iOS native code
├── llama.cpp/                  # llama.cpp submodule (inference engine)
├── test/                       # Comprehensive test suite
├── tools/                      # Build and test scripts
├── example/                    # Example Flutter app
└── docs/                       # Documentation
```

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Flutter App                      │
├─────────────────────────────────────────────────────────┤
│              Llamafu Dart API (lib/src/)                │
│         High-level, type-safe, async interface          │
├─────────────────────────────────────────────────────────┤
│           FFI Bindings (llamafu_bindings.dart)          │
│              dart:ffi ↔ Native C bridge                 │
├─────────────────────────────────────────────────────────┤
│            Native C++ Layer (llamafu.cpp)               │
│              RAII, memory safety, validation            │
├─────────────────────────────────────────────────────────┤
│                    llama.cpp Engine                      │
│        High-performance inference, GGUF loading         │
└─────────────────────────────────────────────────────────┘
```

### Performance Tips

- **Use quantized models** — Q4_K_M offers the best quality/size tradeoff for mobile
- **Right-size context** — Smaller context = less memory (start with 2048, increase if needed)
- **Tune threading** — `threads: Platform.numberOfProcessors - 1` is a good default
- **Clean up resources** — Always call `close()` when done to free native memory
- **Stream responses** — Use streaming for better perceived performance in chat UIs

### Error Handling

```dart
try {
  final result = await llamafu.complete(prompt: input, maxTokens: 200);
} on LlamafuException catch (e) {
  switch (e.code) {
    case LlamafuErrorCode.modelLoadFailed:
      print('Could not load model: ${e.message}');
    case LlamafuErrorCode.outOfMemory:
      print('Not enough memory—try a smaller model or context size');
    default:
      print('Error: ${e.message}');
  }
}
```

---

## Contributing

Contributions are welcome! See [docs/contributing.md](docs/contributing.md) for guidelines.

```bash
# Run the full test suite
make test

# Format and lint
dart format . && dart analyze
```

## Support

- **Issues:** [GitHub Issues](https://github.com/skelf-research/llamafu/issues)
- **Docs:** [docs/](docs/)

## License

MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgments

Built on the shoulders of giants:

- [llama.cpp](https://github.com/ggerganov/llama.cpp) — The inference engine that makes this possible
- [ggml](https://github.com/ggerganov/ggml) — Tensor library for efficient ML computation
