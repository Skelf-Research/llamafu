# Llamafu

[![Pub](https://img.shields.io/pub/v/llamafu.svg)](https://pub.dev/packages/llamafu)
[![License](https://img.shields.io/github/license/dipankar/llamafu)](https://github.com/dipankar/llamafu/blob/main/LICENSE)

A Flutter package for running language models on device with support for completion, instruct mode, tool calling, streaming, constrained generation, LoRA, and multi-modal inputs (images, audio).

## Features

- 🚀 Run language models directly on device (Android and iOS)
- 💬 Support for text completion
- 🤖 Instruct mode for chat-like interactions
- 🛠️ Tool calling capabilities
- 🌊 Streaming output
- 🔒 Constrained generation (GBNF grammars)
- 🧬 LoRA adapter support
- 🖼️🎧 Multi-modal support (images, audio)

## Prerequisites

- Flutter 3.0 or higher
- Android SDK/NDK for Android development
- Xcode for iOS development
- Pre-built llama.cpp libraries

## Installation

Add `llamafu` as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  llamafu: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Usage

### Text Completion

```dart
import 'package:llamafu/llamafu.dart';

// Initialize the model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/your/model.gguf',
  threads: 4,
  contextSize: 512,
);

// Generate text
final result = await llamafu.complete(
  prompt: 'The quick brown fox',
  maxTokens: 128,
  temperature: 0.8,
);

print(result);

// Clean up resources
llamafu.close();
```

### Multi-modal Inference

```dart
import 'package:llamafu/llamafu.dart';

// Initialize the model with multi-modal projector
final llamafu = await Llamafu.init(
  modelPath: '/path/to/your/model.gguf',
  mmprojPath: '/path/to/your/mmproj.gguf', // Multi-modal projector file
  threads: 4,
  contextSize: 512,
  useGpu: false, // Set to true to use GPU for multi-modal processing
);

// Generate text with image input
final mediaInputs = [
  MediaInput(
    type: MediaType.image,
    data: '/path/to/your/image.jpg', // Path to image file
  ),
];

final result = await llamafu.multimodalComplete(
  prompt: 'Describe this image: <image>',
  mediaInputs: mediaInputs,
  maxTokens: 128,
  temperature: 0.8,
);

print(result);

// Clean up resources
llamafu.close();
```

### LoRA Adapter Support

```dart
import 'package:llamafu/llamafu.dart';

// Initialize the model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/your/model.gguf',
  threads: 4,
  contextSize: 512,
);

// Load a LoRA adapter
final loraAdapter = await llamafu.loadLoraAdapter('/path/to/your/lora.gguf');

// Apply the LoRA adapter with a scale factor
await llamafu.applyLoraAdapter(loraAdapter, scale: 0.5);

// Generate text with the LoRA adapter applied
final result = await llamafu.complete(
  prompt: 'Write a story about space exploration',
  maxTokens: 128,
  temperature: 0.8,
);

print(result);

// Remove the LoRA adapter
await llamafu.removeLoraAdapter(loraAdapter);

// Or clear all LoRA adapters
await llamafu.clearAllLoraAdapters();

// Clean up resources
llamafu.close();
```

### Constrained Generation

```dart
import 'package:llamafu/llamafu.dart';

// Initialize the model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/your/model.gguf',
  threads: 4,
  contextSize: 512,
);

// Define a JSON grammar
final jsonGrammar = '''
root   ::= object
value  ::= object | array | string | number | ("true" | "false" | "null") ws

object ::=
  "{" ws (
            string ":" ws value
    ("," ws string ":" ws value)*
  )? "}" ws

array  ::=
  "[" ws (
            value
    ("," ws value)*
  )? "]" ws

string ::=
  "\"" (
    [^\"\\\\\x7F\x00-\x1F] |
    "\\\\" (["\\\\bfnrt] | "u" [0-9a-fA-F]{4}) # escapes
  )* "\"" ws

number ::= ("-"? ([0-9] | [1-9] [0-9]{0,15})) ("." [0-9]+)? ([eE] [-+]? [0-9] [1-9]{0,15})? ws

# Optional space: by convention, applied in this grammar after literal chars when allowed
ws ::= | " " | "\n" [ \t]{0,20}
''';

// Generate text constrained to JSON format
final result = await llamafu.completeWithGrammar(
  prompt: 'Generate a JSON object describing a person:',
  grammarStr: jsonGrammar,
  grammarRoot: 'root',
  maxTokens: 256,
  temperature: 0.8,
);

print(result);

// Clean up resources
llamafu.close();
```

## Supported Multi-modal Models

Llamafu supports various multi-modal models through the llama.cpp MTMD library:

### Vision Models
- Gemma 3
- SmolVLM
- Pixtral 12B
- Qwen 2 VL
- Qwen 2.5 VL
- Mistral Small 3.1 24B
- InternVL 2.5 and 3
- Llama 4 Scout
- Moondream2

### Audio Models
- Ultravox 0.5
- Qwen2-Audio
- SeaLLM-Audio
- Voxtral Mini

### Mixed Modalities
- Qwen2.5 Omni (audio + vision)

## Building

### Android

1. Ensure you have the Android NDK installed
2. Build the native libraries:
   ```bash
   cd android/src/main/cpp
   mkdir build
   cd build
   cmake .. -DLLAMA_CPP_DIR=/path/to/llama.cpp
   make
   ```

### iOS

1. Ensure you have Xcode installed
2. Build the native libraries using Xcode or CMake

## API Reference

For detailed API documentation, please refer to the [API documentation](https://pub.dev/documentation/llamafu/latest/).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- This project uses the excellent [llama.cpp](https://github.com/ggerganov/llama.cpp) library for running language models.
- Multi-modal support is provided by the MTMD library in llama.cpp.
- LoRA support is provided by the native LoRA adapter functionality in llama.cpp.
- Constrained generation support is provided by the grammar sampler functionality in llama.cpp.