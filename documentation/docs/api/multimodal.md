# Multimodal API

API reference for vision and audio capabilities.

## MediaInput

Represents an image or audio input.

```dart
class MediaInput {
  final MediaType type;
  final String data;
  final DataSource sourceType;
  final AudioFormat? audioFormat;
  final int? sampleRate;
  final int? channels;
  final int? durationMs;
}
```

### Constructors

#### Default Constructor

```dart
MediaInput({
  required MediaType type,
  required String data,
  DataSource sourceType = DataSource.filePath,
  AudioFormat? audioFormat,
  int? sampleRate,
  int? channels,
  int? durationMs,
})
```

#### `MediaInput.fromBase64()`

Create from base64-encoded data.

```dart
final input = MediaInput.fromBase64(
  base64String,
  type: MediaType.image,
);
```

#### `MediaInput.fromUrl()`

Create from URL (will be fetched).

```dart
final input = MediaInput.fromUrl(
  'https://example.com/image.jpg',
  type: MediaType.image,
);
```

#### `MediaInput.fromAudioSamples()`

Create from raw audio samples.

```dart
final input = MediaInput.fromAudioSamples(
  samples,  // Float32List
  sampleRate: 16000,
  channels: 1,
);
```

## MediaType

```dart
enum MediaType {
  image,
  audio,
  video,  // Future support
}
```

## DataSource

```dart
enum DataSource {
  filePath,
  base64,
  url,
  rawSamples,
}
```

## AudioFormat

```dart
enum AudioFormat {
  wav,
  mp3,
  flac,
  pcm16,
}
```

## Multimodal Completion

### `multimodalComplete()`

Generate completion with media inputs.

```dart
Future<String> multimodalComplete({
  required String prompt,
  required List<MediaInput> mediaInputs,
  int maxTokens = 256,
  double temperature = 0.7,
  int? visionThreads,
  bool useVisionCache = true,
  bool includeImageTokens = false,
})
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | `String` | required | Text prompt |
| `mediaInputs` | `List<MediaInput>` | required | Images/audio to process |
| `maxTokens` | `int` | 256 | Max tokens to generate |
| `temperature` | `double` | 0.7 | Sampling temperature |
| `visionThreads` | `int?` | null | Threads for vision processing |
| `useVisionCache` | `bool` | true | Cache processed images |
| `includeImageTokens` | `bool` | false | Include image token count |

### `multimodalCompleteStream()`

Stream completion with media.

```dart
Stream<String> multimodalCompleteStream({
  required String prompt,
  required List<MediaInput> mediaInputs,
  int maxTokens = 256,
  double temperature = 0.7,
})
```

## Image Processing

### `processImage()`

Pre-process an image for embedding.

```dart
Future<ImageProcessResult> processImage(MediaInput input)
```

#### Returns

```dart
class ImageProcessResult {
  final List<double> embeddings;
  final int nTokens;
  final int processingTimeMs;
  final int width;
  final int height;
}
```

### `clearVisionCache()`

Clear cached image embeddings.

```dart
void clearVisionCache()
```

## Audio Processing

### Audio Input Requirements

| Property | Recommended | Notes |
|----------|-------------|-------|
| Sample Rate | 16000 Hz | Standard for speech |
| Channels | 1 (mono) | Stereo is downmixed |
| Format | WAV, PCM16 | Uncompressed preferred |
| Bit Depth | 16-bit | Float32 for raw |

### Example: Audio Transcription

```dart
final audioBytes = await File('recording.wav').readAsBytes();

final audioInput = MediaInput(
  type: MediaType.audio,
  data: base64Encode(audioBytes),
  sourceType: DataSource.base64,
  audioFormat: AudioFormat.wav,
  sampleRate: 16000,
  channels: 1,
);

final transcription = await llamafu.multimodalComplete(
  prompt: 'Transcribe this audio:',
  mediaInputs: [audioInput],
  maxTokens: 500,
);
```

## Usage Examples

### Single Image

```dart
final imageInput = MediaInput(
  type: MediaType.image,
  data: '/path/to/image.jpg',
  sourceType: DataSource.filePath,
);

final description = await llamafu.multimodalComplete(
  prompt: 'Describe this image:',
  mediaInputs: [imageInput],
);
```

### Multiple Images

```dart
final inputs = [
  MediaInput(type: MediaType.image, data: image1Path),
  MediaInput(type: MediaType.image, data: image2Path),
];

final comparison = await llamafu.multimodalComplete(
  prompt: 'Compare these two images:',
  mediaInputs: inputs,
);
```

### Base64 Image

```dart
final bytes = await File('image.png').readAsBytes();
final base64 = base64Encode(bytes);

final input = MediaInput.fromBase64(base64, type: MediaType.image);

final result = await llamafu.multimodalComplete(
  prompt: 'What is in this image?',
  mediaInputs: [input],
);
```

### Streaming with Image

```dart
await for (final token in llamafu.multimodalCompleteStream(
  prompt: 'Describe:',
  mediaInputs: [imageInput],
  maxTokens: 200,
)) {
  stdout.write(token);
}
```

## Error Handling

```dart
try {
  await llamafu.multimodalComplete(
    prompt: 'Describe:',
    mediaInputs: [imageInput],
  );
} on LlamafuMultimodalError catch (e) {
  switch (e.code) {
    case ErrorCode.visionInitFailed:
      print('Vision not initialized. Provide mmprojPath.');
      break;
    case ErrorCode.imageProcessFailed:
      print('Failed to process image: ${e.message}');
      break;
    case ErrorCode.audioProcessFailed:
      print('Failed to process audio: ${e.message}');
      break;
    case ErrorCode.multimodalNotSupported:
      print('Model does not support multimodal.');
      break;
  }
}
```

## Supported Formats

### Images

| Format | Extension | Notes |
|--------|-----------|-------|
| JPEG | .jpg, .jpeg | Recommended |
| PNG | .png | Supports transparency |
| WebP | .webp | Good compression |
| BMP | .bmp | Uncompressed |
| GIF | .gif | First frame only |

### Audio

| Format | Extension | Notes |
|--------|-----------|-------|
| WAV | .wav | Recommended |
| MP3 | .mp3 | Requires decoding |
| FLAC | .flac | Lossless |
| PCM | raw | Float32, 16kHz |

## Performance Tips

1. **Resize images** before processing (512-768px optimal)
2. **Use vision cache** for repeated images
3. **Pre-process** images during idle time
4. **Compress audio** to 16kHz mono WAV
