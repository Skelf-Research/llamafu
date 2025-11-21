# Getting Started

This guide covers installation, setup, and basic usage of Llamafu.

## Prerequisites

Before installing Llamafu, ensure you have:

- Flutter SDK 3.10.0 or higher
- Dart SDK 3.1.0 or higher
- For Android: Android Studio with NDK 21+
- For iOS: Xcode 14+ with Command Line Tools
- A GGUF format model file

## Installation

### 1. Add Dependency

Add Llamafu to your `pubspec.yaml`:

```yaml
dependencies:
  llamafu: ^0.0.1
```

Install the package:

```bash
flutter pub get
```

### 2. Platform Setup

#### Android

No additional setup required. The native libraries are bundled with the package.

Minimum requirements in `android/app/build.gradle`:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64'
        }
    }
}
```

#### iOS

Add to your `ios/Podfile`:

```ruby
platform :ios, '12.0'
```

Then run:

```bash
cd ios && pod install
```

### 3. Obtain a Model

Download a GGUF format model. Recommended sources:

- [Hugging Face](https://huggingface.co/models?search=gguf)
- [TheBloke's Quantized Models](https://huggingface.co/TheBloke)

For mobile, use quantized models (Q4_K_M or Q8_0) to reduce memory usage.

Example models for testing:
- TinyLlama 1.1B (small, fast)
- Phi-2 2.7B (balanced)
- Mistral 7B Q4_K_M (quality)

## Basic Usage

### Initialize and Generate

```dart
import 'package:llamafu/llamafu.dart';

class LLMService {
  Llamafu? _llamafu;

  Future<void> initialize(String modelPath) async {
    _llamafu = await Llamafu.init(
      modelPath: modelPath,
      threads: 4,
      contextSize: 2048,
    );
  }

  Future<String> generate(String prompt) async {
    if (_llamafu == null) {
      throw Exception('Model not initialized');
    }

    return await _llamafu!.complete(
      prompt: prompt,
      maxTokens: 256,
      temperature: 0.7,
    );
  }

  void dispose() {
    _llamafu?.close();
    _llamafu = null;
  }
}
```

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:llamafu/llamafu.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Llamafu? _llamafu;
  String _output = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    setState(() => _loading = true);

    try {
      _llamafu = await Llamafu.init(
        modelPath: '/path/to/model.gguf',
        threads: 4,
        contextSize: 2048,
      );
    } catch (e) {
      setState(() => _output = 'Error loading model: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _generate() async {
    if (_llamafu == null) return;

    setState(() => _loading = true);

    try {
      final result = await _llamafu!.complete(
        prompt: 'Hello, how are you?',
        maxTokens: 100,
        temperature: 0.7,
      );
      setState(() => _output = result);
    } catch (e) {
      setState(() => _output = 'Error: $e');
    }

    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _llamafu?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Llamafu Demo')),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _generate,
                child: Text('Generate'),
              ),
              SizedBox(height: 16),
              if (_loading) CircularProgressIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(_output),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Configuration Options

### Model Parameters

```dart
final llamafu = await Llamafu.init(
  modelPath: '/path/to/model.gguf',

  // Threading
  threads: 4,                    // CPU threads for inference

  // Context
  contextSize: 2048,             // Maximum context window

  // GPU (if available)
  nGpuLayers: 32,                // Layers to offload to GPU

  // Memory mapping
  useMmap: true,                 // Use memory-mapped files
  useMlock: false,               // Lock memory pages

  // Multimodal
  mmprojPath: '/path/to/mmproj.gguf',  // Vision projector
);
```

### Generation Parameters

```dart
final result = await llamafu.complete(
  prompt: 'Your prompt here',

  // Length control
  maxTokens: 256,                // Maximum tokens to generate

  // Sampling
  temperature: 0.7,              // Randomness (0.0 - 2.0)
  topK: 40,                      // Top-K sampling
  topP: 0.9,                     // Nucleus sampling
  minP: 0.05,                    // Minimum probability

  // Repetition control
  repeatPenalty: 1.1,            // Penalty for repetition
  frequencyPenalty: 0.0,         // Frequency-based penalty
  presencePenalty: 0.0,          // Presence-based penalty

  // Reproducibility
  seed: 42,                      // Random seed (-1 for random)
);
```

## Model Management

### Loading Models

Store models in app-accessible storage:

```dart
import 'package:path_provider/path_provider.dart';

Future<String> getModelPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/models/model.gguf';
}
```

### Model Information

```dart
final info = await llamafu.getModelInfo();
print('Vocabulary size: ${info.nVocab}');
print('Training context: ${info.nCtxTrain}');
print('Embedding dimensions: ${info.nEmbd}');
print('Multimodal: ${info.supportsMultimodal}');
```

### Memory Considerations

- 1B parameter model: ~1-2 GB RAM
- 7B parameter model (Q4): ~4-6 GB RAM
- 13B parameter model (Q4): ~8-10 GB RAM

Use quantized models for mobile deployment.

## Error Handling

```dart
try {
  final result = await llamafu.complete(
    prompt: prompt,
    maxTokens: 200,
  );
  // Handle success
} on LlamafuException catch (e) {
  switch (e.code) {
    case LlamafuErrorCode.modelLoadFailed:
      print('Failed to load model: ${e.message}');
      break;
    case LlamafuErrorCode.outOfMemory:
      print('Out of memory - try smaller model or context');
      break;
    case LlamafuErrorCode.invalidParam:
      print('Invalid parameter: ${e.message}');
      break;
    case LlamafuErrorCode.contextInitFailed:
      print('Failed to initialize context');
      break;
    default:
      print('Error: ${e.message}');
  }
} catch (e) {
  print('Unexpected error: $e');
}
```

## Next Steps

- [API Reference](api-reference.md) - Complete API documentation
- [Model Guide](model-guide.md) - Model selection and optimization
- [Performance Guide](performance-guide.md) - Optimization techniques
- [Architecture](architecture.md) - Technical internals

## Troubleshooting

### Model fails to load

- Verify the model file exists and is readable
- Ensure sufficient memory for the model
- Check that the model is in GGUF format

### Out of memory errors

- Use a smaller quantized model
- Reduce context size
- Close other applications

### Slow generation

- Increase thread count (up to CPU core count)
- Use GPU offloading if available
- Use a smaller or more quantized model

### iOS build failures

- Ensure Xcode Command Line Tools are installed
- Run `pod install` in the ios directory
- Check minimum iOS deployment target
