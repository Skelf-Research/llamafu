# Llamafu

[![Pub](https://img.shields.io/pub/v/llamafu.svg)](https://pub.dev/packages/llamafu)
[![License](https://img.shields.io/github/license/dipankar/llamafu)](https://github.com/dipankar/llamafu/blob/main/LICENSE)

**Llamafu** is a production-ready Flutter package for running large language models directly on mobile devices (Android/iOS). Built on llama.cpp, it provides comprehensive LLM capabilities including text generation, multi-modal processing, LoRA fine-tuning, constrained generation, and advanced sampling techniques.

## Key Features

- **On-Device Inference**: Run language models locally without internet connectivity
- **Cross-Platform**: Native support for Android and iOS with optimized performance
- **Multi-Modal Processing**: Support for vision and audio models with simultaneous text processing
- **Advanced Sampling**: Top-K, Top-P, repetition penalties, and temperature controls
- **LoRA Adapters**: Dynamic fine-tuning with multiple adapter support
- **Constrained Generation**: GBNF grammar-based structured output generation
- **Token-Level Control**: Access to tokenization, logits, and model introspection
- **Embeddings Support**: Generate text embeddings for semantic similarity tasks
- **Memory Efficient**: Optimized for mobile device constraints

## Quick Start

### Installation

Add Llamafu to your Flutter project:

```yaml
dependencies:
  llamafu: ^0.0.1
```

```bash
flutter pub get
```

### Basic Usage

```dart
import 'package:llamafu/llamafu.dart';

// Initialize the model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/your/model.gguf',
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

// Clean up
llamafu.close();
```

## Core Capabilities

### Text Generation

Llamafu supports various text generation patterns for different use cases:

**Completion Mode**: Continue or complete text prompts
```dart
final result = await llamafu.complete(
  prompt: 'The future of artificial intelligence',
  maxTokens: 150,
  temperature: 0.8,
);
```

**Chat/Instruct Mode**: Conversational interactions
```dart
final result = await llamafu.complete(
  prompt: '<|im_start|>user\nExplain machine learning<|im_end|>\n<|im_start|>assistant\n',
  maxTokens: 200,
  temperature: 0.7,
);
```

### Advanced Sampling Parameters

Control generation quality with sophisticated sampling techniques:

```dart
final result = await llamafu.complete(
  prompt: 'Write a technical explanation of neural networks:',
  maxTokens: 300,
  temperature: 0.7,
  topK: 40,              // Limit to top 40 candidates
  topP: 0.9,             // Nucleus sampling threshold
  repeatPenalty: 1.1,    // Reduce repetition
  seed: 42,              // Reproducible generation
);
```

### Multi-Modal Processing

Process images and audio alongside text for comprehensive AI applications:

```dart
// Initialize with multi-modal projector
final llamafu = await Llamafu.init(
  modelPath: '/path/to/llava-model.gguf',
  mmprojPath: '/path/to/mmproj.gguf',
  threads: 4,
  contextSize: 2048,
  useGpu: true, // Enable GPU acceleration
);

// Process image with text
final mediaInputs = [
  MediaInput(
    type: MediaType.image,
    data: '/path/to/image.jpg',
  ),
];

final result = await llamafu.multimodalComplete(
  prompt: 'Describe what you see in this image in detail:',
  mediaInputs: mediaInputs,
  maxTokens: 200,
  temperature: 0.7,
);
```

### LoRA Fine-Tuning

Dynamically apply and manage LoRA adapters for specialized tasks:

```dart
// Load and apply LoRA adapter
final adapter = await llamafu.loadLoraAdapter('/path/to/specialized.gguf');
await llamafu.applyLoraAdapter(adapter, scale: 0.8);

// Generate with fine-tuned behavior
final result = await llamafu.complete(
  prompt: 'Translate the following to French: Hello, how are you?',
  maxTokens: 50,
);

// Manage multiple adapters
await llamafu.removeLoraAdapter(adapter);
await llamafu.clearAllLoraAdapters();
```

### Constrained Generation

Generate structured output using GBNF grammars:

```dart
const jsonGrammar = '''
root ::= object
object ::= "{" ws (string ":" ws value ("," ws string ":" ws value)*)? "}" ws
string ::= "\\"" ([^"\\\\] | "\\\\" ["\\\\/bfnrt] | "\\\\" "u" [0-9a-fA-F]{4})* "\\""
value ::= object | array | string | number | "true" | "false" | "null"
array ::= "[" ws (value ("," ws value)*)? "]" ws
number ::= "-"? ([0-9] | [1-9][0-9]*) ("." [0-9]+)? ([eE] [+-]? [0-9]+)?
ws ::= [ \\t\\n\\r]*
''';

final result = await llamafu.completeWithGrammar(
  prompt: 'Generate a JSON object for a user profile:',
  grammarStr: jsonGrammar,
  grammarRoot: 'root',
  maxTokens: 200,
);
```

### Token-Level Operations

Access low-level tokenization and model information for advanced use cases:

```dart
// Tokenize text
final tokens = await llamafu.tokenize('Hello world');
print('Tokens: $tokens');

// Get model information
final modelInfo = await llamafu.getModelInfo();
print('Vocabulary size: ${modelInfo.vocabularySize}');
print('Context length: ${modelInfo.contextLength}');
print('Architecture: ${modelInfo.architecture}');

// Generate embeddings
final embeddings = await llamafu.getEmbeddings('semantic similarity text');
print('Embedding dimensions: ${embeddings.length}');
```

## Supported Models

### Text Models
- **Llama 2/3**: General-purpose language models
- **Mistral**: Efficient multilingual models
- **Qwen**: Chinese-English bilingual models
- **Code Llama**: Specialized code generation
- **Phi**: Microsoft's small language models

### Vision-Language Models
- **LLaVA**: Visual question answering
- **Qwen2-VL**: Advanced vision-language understanding
- **Moondream**: Efficient vision model
- **Pixtral**: Multimodal reasoning

### Audio-Language Models
- **Qwen2-Audio**: Speech and audio understanding
- **Ultravox**: Voice interaction models

## Architecture and Performance

### Mobile Optimization
- **Static Linking**: Self-contained binaries with minimal dependencies
- **Memory Management**: Efficient resource utilization for mobile constraints
- **CPU Optimization**: Multi-threading with device-specific thread management
- **Model Quantization**: Support for INT4, INT8 quantized models

### Cross-Platform Build System
- **Git Submodules**: Automatic llama.cpp dependency management
- **CMake Integration**: Unified build system for Android NDK and iOS
- **CI/CD Ready**: Automated builds and testing pipelines

## Integration Patterns

### Chat Applications
```dart
class ChatService {
  late Llamafu _llamafu;

  Future<void> initialize() async {
    _llamafu = await Llamafu.init(
      modelPath: await getModelPath(),
      threads: Platform.numberOfProcessors,
      contextSize: 4096,
    );
  }

  Future<String> sendMessage(String message) async {
    final prompt = buildChatPrompt(message);
    return await _llamafu.complete(
      prompt: prompt,
      maxTokens: 150,
      temperature: 0.7,
    );
  }
}
```

### Document Analysis
```dart
class DocumentAnalyzer {
  Future<String> analyzeDocument(String imagePath) async {
    final llamafu = await Llamafu.init(
      modelPath: '/models/llava-13b.gguf',
      mmprojPath: '/models/llava-proj.gguf',
    );

    final result = await llamafu.multimodalComplete(
      prompt: 'Extract key information from this document:',
      mediaInputs: [MediaInput(type: MediaType.image, data: imagePath)],
      maxTokens: 500,
    );

    llamafu.close();
    return result;
  }
}
```

### Code Generation
```dart
class CodeAssistant {
  late Llamafu _llamafu;

  Future<void> initialize() async {
    _llamafu = await Llamafu.init(
      modelPath: '/models/codellama-13b.gguf',
      threads: 6,
      contextSize: 8192,
    );
  }

  Future<String> generateCode(String specification) async {
    const codeGrammar = '''
    root ::= code_block
    code_block ::= "```" language "\\n" code "\\n```"
    language ::= "dart" | "python" | "javascript"
    code ::= (line "\\n")*
    line ::= [^\\n]*
    ''';

    return await _llamafu.completeWithGrammar(
      prompt: 'Generate ${specification}:',
      grammarStr: codeGrammar,
      grammarRoot: 'root',
      maxTokens: 800,
    );
  }
}
```

## Build Configuration

### Development Setup
```bash
# Clone with dependencies
git clone --recursive https://github.com/your-org/llamafu.git
cd llamafu

# Build for development
flutter pub get
flutter build apk --debug
```

### Production Build
```bash
# Optimize for release
flutter build apk --release --obfuscate --split-debug-info=symbols/

# iOS release
flutter build ios --release
```

### Custom llama.cpp Build
```bash
# Use custom llama.cpp version
export LLAMA_CPP_DIR=/path/to/custom/llama.cpp
flutter build apk
```

## Performance Guidelines

### Model Selection
- **Small Models (1-3B)**: Real-time chat, quick responses
- **Medium Models (7-13B)**: Balanced quality and performance
- **Large Models (30B+)**: High-quality output, slower inference

### Memory Management
```dart
// Proper resource management
class ModelManager {
  Llamafu? _llamafu;

  Future<void> initialize() async {
    _llamafu = await Llamafu.init(
      modelPath: selectedModelPath,
      contextSize: calculateOptimalContext(),
      threads: Platform.numberOfProcessors - 1, // Leave one core free
    );
  }

  void dispose() {
    _llamafu?.close();
    _llamafu = null;
  }
}
```

### Context Management
```dart
// Efficient context handling
final result = await llamafu.complete(
  prompt: truncateToFitContext(fullPrompt, maxContextSize: 2048),
  maxTokens: min(256, remainingContext),
);
```

## Error Handling

```dart
try {
  final result = await llamafu.complete(
    prompt: userInput,
    maxTokens: 200,
  );
  handleSuccess(result);
} on LlamafuException catch (e) {
  switch (e.code) {
    case LlamafuErrorCode.modelLoadFailed:
      handleModelLoadError(e);
      break;
    case LlamafuErrorCode.outOfMemory:
      handleMemoryError(e);
      break;
    case LlamafuErrorCode.invalidParam:
      handleInvalidInput(e);
      break;
    default:
      handleGenericError(e);
  }
} catch (e) {
  handleUnexpectedError(e);
}
```

## Documentation

- [API Reference](docs/api-reference.md) - Complete API documentation
- [Integration Guide](docs/integration-guide.md) - Detailed integration patterns
- [Model Guide](docs/model-guide.md) - Model selection and optimization
- [Performance Tuning](docs/performance-guide.md) - Optimization techniques
- [Build Guide](docs/build-guide.md) - Custom build configurations
- [Examples](docs/examples.md) - Complete example applications

## Requirements

### Development Environment
- **Flutter**: 3.0 or higher
- **Dart**: 3.0 or higher
- **Android**: API level 21+ (Android 5.0)
- **iOS**: 12.0 or higher

### Build Tools
- **Android**: NDK 21+ and CMake 3.18+
- **iOS**: Xcode 14+ and Command Line Tools
- **Git**: For submodule management

### Hardware Requirements
- **Memory**: Minimum 4GB RAM (8GB recommended)
- **Storage**: 1GB+ available space for models
- **CPU**: ARMv7/ARM64 or x86_64 architecture

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Support

- **Issues**: [GitHub Issues](https://github.com/your-org/llamafu/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/llamafu/discussions)
- **Documentation**: [docs/](docs/)

## Acknowledgments

Llamafu builds upon the excellent work of:
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - Core inference engine
- The Hugging Face community for model development and quantization
- Flutter team for the cross-platform framework