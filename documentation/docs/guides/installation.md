# Installation

This guide covers installing Llamafu and setting up your first model.

## Prerequisites

- Flutter SDK 3.16 or later
- Dart SDK 3.2 or later
- A GGUF model file

## Adding the Dependency

Add Llamafu to your `pubspec.yaml`:

```yaml
dependencies:
  llamafu: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Platform-Specific Setup

### Android

Add the following to your `android/app/build.gradle`:

```groovy
android {
    defaultConfig {
        minSdkVersion 21  // Minimum API level
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64'
        }
    }
}
```

!!! note "Memory Considerations"
    Quantized models (Q4, Q8) are recommended for Android to reduce memory usage.

### iOS

No additional configuration required. Metal GPU acceleration is automatically enabled on supported devices (A7 chip or later).

Add to your `ios/Podfile` if not present:

```ruby
platform :ios, '12.0'
```

### macOS

Add the following entitlements to enable file access:

**macos/Runner/DebugProfile.entitlements** and **Release.entitlements**:

```xml
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### Linux

Install build dependencies:

```bash
# Ubuntu/Debian
sudo apt-get install build-essential cmake

# Fedora
sudo dnf install gcc-c++ cmake
```

### Windows

Ensure you have Visual Studio 2019 or later with C++ build tools installed.

## Obtaining Models

### Recommended Sources

1. **Hugging Face** - Largest collection of GGUF models
   - [TheBloke's Models](https://huggingface.co/TheBloke)
   - [ggml-org Official](https://huggingface.co/ggml-org)

2. **Model Recommendations by Use Case**:

| Use Case | Recommended Model | Size |
|----------|-------------------|------|
| Mobile Chat | SmolLM-135M-Q8 | ~150MB |
| Desktop Chat | Llama-3.2-1B-Q4 | ~800MB |
| Vision (Mobile) | nanoLLaVA | ~2GB |
| Vision (Desktop) | LLaVA-1.5-7B-Q4 | ~4GB |

### Downloading a Model

```bash
# Example: Download SmolLM for testing
wget https://huggingface.co/HuggingFaceTB/SmolLM-135M-Instruct-GGUF/resolve/main/smollm-135m-instruct-q8_0.gguf
```

## Verifying Installation

Create a simple test to verify everything works:

```dart
import 'package:llamafu/llamafu.dart';

void main() async {
  try {
    final llamafu = await Llamafu.init(
      modelPath: 'path/to/your/model.gguf',
      contextSize: 512,
    );

    print('Model loaded successfully!');
    print('Vocab size: ${llamafu.vocabSize}');
    print('Context size: ${llamafu.contextSize}');

    llamafu.dispose();
  } catch (e) {
    print('Error: $e');
  }
}
```

## Troubleshooting

### "Model file not found"

Ensure the model path is correct and the file exists. On mobile, models should be in the app's documents directory or bundled as assets.

### "Out of memory"

Try a smaller quantization (Q4 instead of Q8) or reduce `contextSize`.

### "Unsupported model format"

Llamafu only supports GGUF format. Convert older GGML models using llama.cpp's conversion tools.

## Next Steps

- [Quick Start Guide](quickstart.md) - Your first completion
- [Basic Usage](basic-usage.md) - Core concepts and patterns
- [Text Generation](text-generation.md) - Detailed generation options
