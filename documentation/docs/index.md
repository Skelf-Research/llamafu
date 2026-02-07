# Llamafu

**On-device LLM inference for Flutter applications**

Llamafu is a Flutter FFI plugin that brings the power of [llama.cpp](https://github.com/ggml-org/llama.cpp) to mobile and desktop applications. Run large language models directly on-device with no cloud dependency.

## Features

- **Text Generation** - Generate text completions with customizable parameters
- **Multimodal Support** - Process images and audio with vision-language models
- **Chat Sessions** - Manage conversations with proper chat templates
- **LoRA Adapters** - Load and apply fine-tuned adapters at runtime
- **Streaming** - Real-time token-by-token output
- **Cross-Platform** - Android, iOS, macOS, Linux, and Windows

## Quick Example

```dart
import 'package:llamafu/llamafu.dart';

void main() async {
  // Initialize with a GGUF model
  final llamafu = await Llamafu.init(
    modelPath: 'models/llama-3.2-1b-q4.gguf',
    contextSize: 2048,
  );

  // Generate text
  final response = await llamafu.complete(
    'Explain quantum computing in simple terms:',
    maxTokens: 256,
    temperature: 0.7,
  );

  print(response);

  // Clean up
  llamafu.dispose();
}
```

## Supported Models

Llamafu supports any model in GGUF format compatible with llama.cpp:

| Model Type | Examples |
|------------|----------|
| Text LLMs | Llama 3.x, Mistral, Phi, Qwen, SmolLM |
| Vision LLMs | LLaVA, nanoLLaVA, Qwen2-VL, InternVL |
| Audio LLMs | Ultravox, Qwen2-Audio |

## Requirements

- Flutter 3.16+
- Dart 3.2+
- GGUF model files (quantized recommended for mobile)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  llamafu: ^1.0.0
```

See the [Installation Guide](guides/installation.md) for detailed setup instructions.

## Platform Support

| Platform | Status | GPU Acceleration |
|----------|--------|------------------|
| Android | :white_check_mark: Supported | CPU only (NNAPI planned) |
| iOS | :white_check_mark: Supported | Metal |
| macOS | :white_check_mark: Supported | Metal |
| Linux | :white_check_mark: Supported | CPU (CUDA optional) |
| Windows | :white_check_mark: Supported | CPU (CUDA optional) |

## Getting Help

- [GitHub Issues](https://github.com/skelf-research/llamafu/issues) - Bug reports and feature requests
- [API Reference](api/llamafu.md) - Complete API documentation
- [Examples](examples/chatbot.md) - Working code examples
