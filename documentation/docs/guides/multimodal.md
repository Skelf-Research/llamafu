# Multimodal (Vision & Audio)

Llamafu supports vision-language models (VLMs) and audio models through llama.cpp's multimodal capabilities.

## Supported Models

### Vision Models

| Model | Size | Description |
|-------|------|-------------|
| nanoLLaVA | ~2GB | Smallest VLM, runs on mobile |
| LLaVA 1.5/1.6 | 4-14GB | Popular vision model family |
| Qwen2-VL | 2-72GB | State-of-the-art VLM |
| InternVL | 1-14GB | Strong multilingual VLM |
| Moondream | ~2GB | Compact vision model |

### Audio Models

| Model | Size | Description |
|-------|------|-------------|
| Ultravox | ~2GB | Audio-to-text understanding |
| Qwen2-Audio | ~8GB | Audio comprehension |

## Vision Setup

### Loading a Vision Model

Vision models require two files:

1. **Text model** - Main language model (`.gguf`)
2. **Vision projector** - Image encoder (`mmproj-*.gguf`)

```dart
final llamafu = await Llamafu.init(
  modelPath: 'models/nanollava-text.gguf',
  mmprojPath: 'models/nanollava-mmproj.gguf',  // Vision projector
  contextSize: 2048,
);

print('Is multimodal: ${llamafu.isMultimodal}');  // true
```

### Image Completion

```dart
import 'dart:io';
import 'dart:convert';

// Load image as base64
final imageBytes = await File('photo.jpg').readAsBytes();
final imageBase64 = base64Encode(imageBytes);

// Create media input
final imageInput = MediaInput(
  type: MediaType.image,
  data: imageBase64,
  sourceType: DataSource.base64,
);

// Generate description
final response = await llamafu.multimodalComplete(
  prompt: 'Describe this image in detail:',
  mediaInputs: [imageInput],
  maxTokens: 256,
);

print(response);
```

### From File Path

```dart
final imageInput = MediaInput(
  type: MediaType.image,
  data: '/path/to/image.jpg',
  sourceType: DataSource.filePath,
);

final response = await llamafu.multimodalComplete(
  prompt: 'What objects are in this image?',
  mediaInputs: [imageInput],
);
```

### From URL

```dart
final imageInput = MediaInput.fromUrl(
  'https://example.com/image.jpg',
  type: MediaType.image,
);
```

## Streaming with Images

```dart
await for (final token in llamafu.multimodalCompleteStream(
  prompt: 'Describe this image:',
  mediaInputs: [imageInput],
  maxTokens: 200,
)) {
  stdout.write(token);
}
```

## Audio Setup

### Loading an Audio Model

```dart
final llamafu = await Llamafu.init(
  modelPath: 'models/ultravox-1b.gguf',
  mmprojPath: 'models/ultravox-mmproj.gguf',
  contextSize: 4096,
);
```

### Audio Completion

```dart
final audioBytes = await File('recording.wav').readAsBytes();
final audioBase64 = base64Encode(audioBytes);

final audioInput = MediaInput(
  type: MediaType.audio,
  data: audioBase64,
  sourceType: DataSource.base64,
  audioFormat: AudioFormat.wav,
  sampleRate: 16000,
  channels: 1,
);

final response = await llamafu.multimodalComplete(
  prompt: 'Transcribe this audio:',
  mediaInputs: [audioInput],
  maxTokens: 500,
);
```

### From Raw Samples

```dart
// Float32 audio samples at 16kHz
final Float32List samples = getAudioSamples();

final audioInput = MediaInput.fromAudioSamples(
  samples,
  sampleRate: 16000,
  channels: 1,
);
```

## Multiple Inputs

Process multiple images or mixed media:

```dart
final inputs = [
  MediaInput(type: MediaType.image, data: image1Base64),
  MediaInput(type: MediaType.image, data: image2Base64),
];

final response = await llamafu.multimodalComplete(
  prompt: 'Compare these two images:',
  mediaInputs: inputs,
  maxTokens: 300,
);
```

## Image Processing Options

### Custom Processing

```dart
final result = await llamafu.processImage(imageInput);
print('Image tokens: ${result.nTokens}');
print('Processing time: ${result.processingTimeMs}ms');
```

### Vision Parameters

```dart
final response = await llamafu.multimodalComplete(
  prompt: 'Analyze this image:',
  mediaInputs: [imageInput],
  visionThreads: 4,        // Threads for image processing
  useVisionCache: true,    // Cache processed images
  includeImageTokens: true,
);
```

## Chat with Vision

Use chat templates with images:

```dart
final session = llamafu.createChatSession();

// Add image context
session.addImage(imageInput);

// Chat about the image
session.addMessage('user', 'What do you see in this image?');
final response1 = await session.generate(maxTokens: 200);

session.addMessage('user', 'What colors are prominent?');
final response2 = await session.generate(maxTokens: 100);
```

## Best Practices

### 1. Image Size

Resize large images before processing:

```dart
// Images are internally resized, but pre-resizing saves memory
import 'package:image/image.dart' as img;

final image = img.decodeImage(bytes);
final resized = img.copyResize(image!, width: 512);
final optimized = img.encodeJpg(resized, quality: 85);
```

### 2. Memory Management

```dart
// Clear vision cache when switching contexts
llamafu.clearVisionCache();
```

### 3. Mobile Considerations

```dart
// Use smaller models on mobile
if (Platform.isAndroid || Platform.isIOS) {
  modelPath = 'models/nanollava.gguf';  // ~2GB
} else {
  modelPath = 'models/llava-7b.gguf';   // ~4GB
}
```

### 4. Supported Formats

| Format | Extension | Notes |
|--------|-----------|-------|
| JPEG | .jpg, .jpeg | Recommended |
| PNG | .png | Supports transparency |
| WebP | .webp | Good compression |
| BMP | .bmp | Uncompressed |

For audio:

| Format | Extension | Notes |
|--------|-----------|-------|
| WAV | .wav | Recommended, uncompressed |
| MP3 | .mp3 | Requires decoding |
| FLAC | .flac | Lossless |
| PCM | raw | Float32, 16kHz mono preferred |

## Error Handling

```dart
try {
  final response = await llamafu.multimodalComplete(
    prompt: 'Describe:',
    mediaInputs: [imageInput],
  );
} on LlamafuMultimodalError catch (e) {
  if (e.code == ErrorCode.visionInitFailed) {
    print('Vision model not loaded. Check mmproj path.');
  } else if (e.code == ErrorCode.imageProcessFailed) {
    print('Failed to process image: ${e.message}');
  }
}
```

## Troubleshooting

### "Vision not initialized"

Ensure you provided `mmprojPath` during initialization:

```dart
final llamafu = await Llamafu.init(
  modelPath: 'model.gguf',
  mmprojPath: 'mmproj.gguf',  // Required for vision
);
```

### "Unsupported image format"

Convert to JPEG or PNG:

```dart
import 'package:image/image.dart' as img;
final image = img.decodeImage(bytes);
final jpeg = img.encodeJpg(image!);
```

### Poor image understanding

Try:
1. Using a larger model
2. Providing more specific prompts
3. Ensuring image is clear and well-lit

## Next Steps

- [Examples: Image Analysis](../examples/image-analysis.md)
- [API: Multimodal](../api/multimodal.md)
- [Performance Tuning](performance.md)
