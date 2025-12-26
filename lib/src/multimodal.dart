import 'dart:async';
import 'dart:typed_data';

import 'llamafu_base.dart' show MediaType;

/// Source type for media data.
enum MediaSource {
  /// File path on disk.
  file,

  /// Base64 encoded string.
  base64,

  /// Raw bytes.
  bytes,

  /// URL (for future support).
  url,
}

/// A media input for multimodal processing.
class Media {
  /// Type of media.
  final MediaType type;

  /// Source type.
  final MediaSource source;

  /// The data (path string, base64 string, or bytes).
  final dynamic data;

  /// Optional caption or description.
  final String? caption;

  const Media._({
    required this.type,
    required this.source,
    required this.data,
    this.caption,
  });

  /// Create from file path.
  factory Media.file(String path, {MediaType? type, String? caption}) {
    final inferredType = type ?? _inferTypeFromPath(path);
    return Media._(
      type: inferredType,
      source: MediaSource.file,
      data: path,
      caption: caption,
    );
  }

  /// Create from base64 string.
  factory Media.base64(String data, {required MediaType type, String? caption}) {
    return Media._(
      type: type,
      source: MediaSource.base64,
      data: data,
      caption: caption,
    );
  }

  /// Create from raw bytes.
  factory Media.bytes(Uint8List data, {required MediaType type, String? caption}) {
    return Media._(
      type: type,
      source: MediaSource.bytes,
      data: data,
      caption: caption,
    );
  }

  /// Create image from file.
  factory Media.image(String path, {String? caption}) => Media.file(
        path,
        type: MediaType.image,
        caption: caption,
      );

  /// Create audio from file.
  factory Media.audio(String path, {String? caption}) => Media.file(
        path,
        type: MediaType.audio,
        caption: caption,
      );

  static MediaType _inferTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp')) {
      return MediaType.image;
    } else if (lower.endsWith('.wav') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.ogg')) {
      return MediaType.audio;
    } else if (lower.endsWith('.mp4') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov')) {
      return MediaType.video;
    }
    return MediaType.image; // Default
  }

  @override
  String toString() => 'Media($type, $source)';
}

/// Configuration for vision/image processing.
class VisionConfig {
  /// Maximum tokens to generate.
  final int maxTokens;

  /// Sampling temperature.
  final double temperature;

  /// Number of threads for vision processing.
  final int threads;

  /// Whether to cache processed images.
  final bool useCache;

  /// Whether to auto-resize images to model requirements.
  final bool autoResize;

  const VisionConfig({
    this.maxTokens = 256,
    this.temperature = 0.7,
    this.threads = 4,
    this.useCache = true,
    this.autoResize = true,
  });
}

/// Configuration for audio processing.
class AudioConfig {
  /// Maximum tokens to generate.
  final int maxTokens;

  /// Sampling temperature.
  final double temperature;

  /// Target sample rate for processing.
  final int sampleRate;

  /// Whether to auto-resample audio.
  final bool autoResample;

  const AudioConfig({
    this.maxTokens = 256,
    this.temperature = 0.7,
    this.sampleRate = 16000,
    this.autoResample = true,
  });
}

/// High-level Vision API for image understanding.
///
/// Provides simple methods for common vision tasks like description,
/// OCR, and visual question answering.
///
/// Example:
/// ```dart
/// final vision = Vision(llamafu);
///
/// // Describe an image
/// final description = await vision.describe('photo.jpg');
///
/// // Ask about an image
/// final answer = await vision.ask(
///   'What color is the car?',
///   image: 'car.jpg',
/// );
///
/// // Extract text (OCR)
/// final text = await vision.extractText('document.png');
///
/// // Compare images
/// final comparison = await vision.compare([
///   'image1.jpg',
///   'image2.jpg',
/// ]);
/// ```
class Vision {
  final dynamic _llamafu;
  final VisionConfig config;

  /// Create a Vision API instance.
  Vision(this._llamafu, {this.config = const VisionConfig()});

  /// Describe an image.
  ///
  /// Returns a natural language description of the image contents.
  Future<String> describe(String imagePath, {String? detail}) async {
    final prompt = detail ?? 'Describe this image in detail:';
    return await _llamafu.multimodalComplete(
      prompt: prompt,
      mediaInputs: [Media.image(imagePath)],
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }

  /// Ask a question about an image.
  Future<String> ask(String question, {required String image}) async {
    return await _llamafu.multimodalComplete(
      prompt: question,
      mediaInputs: [Media.image(image)],
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }

  /// Extract text from an image (OCR).
  Future<String> extractText(String imagePath) async {
    return await _llamafu.multimodalComplete(
      prompt: 'Extract and transcribe all text visible in this image:',
      mediaInputs: [Media.image(imagePath)],
      maxTokens: config.maxTokens,
      temperature: 0.1, // Low temp for accuracy
    );
  }

  /// Identify objects in an image.
  Future<String> identifyObjects(String imagePath) async {
    return await _llamafu.multimodalComplete(
      prompt: 'List all objects visible in this image:',
      mediaInputs: [Media.image(imagePath)],
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }

  /// Compare multiple images.
  Future<String> compare(List<String> imagePaths, {String? aspect}) async {
    final prompt = aspect != null
        ? 'Compare these images in terms of $aspect:'
        : 'Compare and contrast these images:';

    return await _llamafu.multimodalComplete(
      prompt: prompt,
      mediaInputs: imagePaths.map((p) => Media.image(p)).toList(),
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }

  /// Analyze image for specific attributes.
  Future<String> analyze(
    String imagePath, {
    required List<String> attributes,
  }) async {
    final attrList = attributes.join(', ');
    return await _llamafu.multimodalComplete(
      prompt: 'Analyze this image for: $attrList',
      mediaInputs: [Media.image(imagePath)],
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }

  /// Stream response while analyzing image.
  Stream<String> describeStream(String imagePath, {String? detail}) {
    final prompt = detail ?? 'Describe this image in detail:';
    return _llamafu.multimodalCompleteStream(
      prompt: prompt,
      mediaInputs: [Media.image(imagePath)],
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }
}

/// High-level Audio API for audio understanding.
///
/// Example:
/// ```dart
/// final audio = Audio(llamafu);
///
/// // Transcribe audio
/// final text = await audio.transcribe('recording.wav');
///
/// // Analyze audio content
/// final analysis = await audio.analyze('speech.mp3');
/// ```
class Audio {
  final dynamic _llamafu;
  final AudioConfig config;

  /// Create an Audio API instance.
  Audio(this._llamafu, {this.config = const AudioConfig()});

  /// Transcribe audio to text.
  Future<String> transcribe(String audioPath) async {
    return await _llamafu.multimodalComplete(
      prompt: 'Transcribe the audio:',
      mediaInputs: [Media.audio(audioPath)],
      maxTokens: config.maxTokens,
      temperature: 0.1,
    );
  }

  /// Analyze audio content.
  Future<String> analyze(String audioPath, {String? focus}) async {
    final prompt = focus != null
        ? 'Analyze this audio for $focus:'
        : 'Analyze this audio:';

    return await _llamafu.multimodalComplete(
      prompt: prompt,
      mediaInputs: [Media.audio(audioPath)],
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }

  /// Summarize audio content.
  Future<String> summarize(String audioPath) async {
    return await _llamafu.multimodalComplete(
      prompt: 'Summarize the content of this audio:',
      mediaInputs: [Media.audio(audioPath)],
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }

  /// Answer questions about audio.
  Future<String> ask(String question, {required String audio}) async {
    return await _llamafu.multimodalComplete(
      prompt: question,
      mediaInputs: [Media.audio(audio)],
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    );
  }
}

/// High-level Multimodal API for combined media inputs.
///
/// Handles combinations of text, images, and audio in a single request.
///
/// Example:
/// ```dart
/// final multimodal = Multimodal(llamafu);
///
/// // Combine image and text
/// final result = await multimodal.complete(
///   prompt: 'Based on this image and context, what should I do?',
///   media: [
///     Media.image('diagram.png'),
///   ],
/// );
///
/// // Multiple images with audio
/// final analysis = await multimodal.complete(
///   prompt: 'Describe the relationship between these',
///   media: [
///     Media.image('photo1.jpg'),
///     Media.image('photo2.jpg'),
///     Media.audio('narration.wav'),
///   ],
/// );
/// ```
class Multimodal {
  final dynamic _llamafu;
  final int maxTokens;
  final double temperature;

  /// Create a Multimodal API instance.
  Multimodal(
    this._llamafu, {
    this.maxTokens = 512,
    this.temperature = 0.7,
  });

  /// Complete with multiple media inputs.
  Future<String> complete({
    required String prompt,
    required List<Media> media,
    int? maxTokens,
    double? temperature,
  }) async {
    return await _llamafu.multimodalComplete(
      prompt: prompt,
      mediaInputs: media,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
    );
  }

  /// Stream completion with media inputs.
  Stream<String> completeStream({
    required String prompt,
    required List<Media> media,
    int? maxTokens,
    double? temperature,
  }) {
    return _llamafu.multimodalCompleteStream(
      prompt: prompt,
      mediaInputs: media,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
    );
  }

  /// Analyze multiple media items together.
  Future<String> analyze({
    required List<Media> media,
    String? focus,
  }) async {
    final prompt = focus != null
        ? 'Analyze these items for $focus:'
        : 'Analyze these items:';

    return complete(prompt: prompt, media: media);
  }

  /// Compare media items.
  Future<String> compare({
    required List<Media> media,
    String? criteria,
  }) async {
    final prompt = criteria != null
        ? 'Compare these items based on $criteria:'
        : 'Compare and contrast these items:';

    return complete(prompt: prompt, media: media);
  }

  /// Summarize content from multiple sources.
  Future<String> summarize({
    required List<Media> media,
    int? maxLength,
  }) async {
    final lengthHint = maxLength != null ? ' in $maxLength words or less' : '';
    return complete(
      prompt: 'Summarize the content from these sources$lengthHint:',
      media: media,
    );
  }
}

/// Builder for constructing multimodal requests.
class MultimodalBuilder {
  final dynamic _llamafu;
  String _prompt = '';
  final List<Media> _media = [];
  int _maxTokens = 512;
  double _temperature = 0.7;

  MultimodalBuilder(this._llamafu);

  /// Set the prompt.
  MultimodalBuilder prompt(String prompt) {
    _prompt = prompt;
    return this;
  }

  /// Add an image.
  MultimodalBuilder addImage(String path, {String? caption}) {
    _media.add(Media.image(path, caption: caption));
    return this;
  }

  /// Add audio.
  MultimodalBuilder addAudio(String path, {String? caption}) {
    _media.add(Media.audio(path, caption: caption));
    return this;
  }

  /// Add any media.
  MultimodalBuilder addMedia(Media media) {
    _media.add(media);
    return this;
  }

  /// Set max tokens.
  MultimodalBuilder maxTokens(int tokens) {
    _maxTokens = tokens;
    return this;
  }

  /// Set temperature.
  MultimodalBuilder temperature(double temp) {
    _temperature = temp;
    return this;
  }

  /// Execute the request.
  Future<String> execute() async {
    return await _llamafu.multimodalComplete(
      prompt: _prompt,
      mediaInputs: _media,
      maxTokens: _maxTokens,
      temperature: _temperature,
    );
  }

  /// Execute with streaming.
  Stream<String> stream() {
    return _llamafu.multimodalCompleteStream(
      prompt: _prompt,
      mediaInputs: _media,
      maxTokens: _maxTokens,
      temperature: _temperature,
    );
  }
}
