# Llamafu

A Flutter package for running language models on device with support for completion, instruct mode, tool calling, streaming, constrained generation, and LoRA.

## Features

- Run language models directly on device (Android and iOS)
- Support for text completion
- Instruct mode for chat-like interactions
- Tool calling capabilities
- Streaming output
- Constrained generation
- LoRA adapter support

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

## Usage

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

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- This project uses the excellent [llama.cpp](https://github.com/ggerganov/llama.cpp) library for running language models.