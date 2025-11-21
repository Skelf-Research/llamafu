import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'llamafu_bindings.dart';

// =============================================================================
// ERROR CODES
// =============================================================================

/// Error codes returned by Llamafu operations.
enum ErrorCode {
  /// Operation completed successfully.
  success(0),

  /// An unknown error occurred.
  unknown(-1),

  /// An invalid parameter was provided.
  invalidParam(-2),

  /// Failed to load the model.
  modelLoadFailed(-3),

  /// Out of memory error.
  outOfMemory(-4),

  /// Multi-modal processing is not supported.
  multimodalNotSupported(-5),

  /// Failed to load the LoRA adapter.
  loraLoadFailed(-6),

  /// The specified LoRA adapter was not found.
  loraNotFound(-7),

  /// Failed to initialize the grammar sampler.
  grammarInitFailed(-8),

  /// Failed to load image.
  imageLoadFailed(-9),

  /// Image format is not supported.
  imageFormatUnsupported(-10),

  /// Base64 decoding failed.
  base64DecodeFailed(-11),

  /// Vision model initialization failed.
  visionInitFailed(-12),

  /// Audio processing failed.
  audioProcessFailed(-13),

  /// Streaming operation failed.
  streamingFailed(-14),

  /// Context overflow error.
  contextOverflow(-15);

  final int value;
  const ErrorCode(this.value);

  static ErrorCode fromValue(int value) {
    return ErrorCode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ErrorCode.unknown,
    );
  }
}

// =============================================================================
// IMAGE TYPES
// =============================================================================

/// Supported image formats.
enum ImageFormat {
  /// Auto-detect format from file header.
  auto,

  /// JPEG format.
  jpeg,

  /// PNG format.
  png,

  /// WebP format.
  webp,

  /// BMP format.
  bmp,

  /// GIF format.
  gif,
}

/// Image validation configuration.
class ImageValidation {
  final int maxWidth;
  final int maxHeight;
  final List<ImageFormat> allowedFormats;
  final int maxFileSizeBytes;

  const ImageValidation({
    this.maxWidth = 4096,
    this.maxHeight = 4096,
    this.allowedFormats = const [ImageFormat.jpeg, ImageFormat.png, ImageFormat.webp],
    this.maxFileSizeBytes = 10 * 1024 * 1024,
  });
}

/// Image processing options.
class ImageProcessingOptions {
  final bool resizeToModel;
  final bool maintainAspectRatio;
  final bool padToSquare;
  final double qualityHint;

  const ImageProcessingOptions({
    this.resizeToModel = true,
    this.maintainAspectRatio = true,
    this.padToSquare = false,
    this.qualityHint = 0.8,
  });
}

// =============================================================================
// AUDIO TYPES
// =============================================================================

/// Supported audio formats.
enum AudioFormat {
  /// Auto-detect format.
  auto,

  /// WAV format.
  wav,

  /// MP3 format.
  mp3,

  /// FLAC format.
  flac,

  /// Raw PCM 16-bit.
  pcm16,

  /// Raw PCM float.
  pcmFloat,

  /// Opus format.
  opus,

  /// OGG format.
  ogg,
}

/// Audio streaming configuration.
class AudioStreamConfig {
  final int bufferSizeMs;
  final int chunkSizeMs;
  final bool enableRealTime;
  final int targetSampleRate;

  const AudioStreamConfig({
    this.bufferSizeMs = 100,
    this.chunkSizeMs = 20,
    this.enableRealTime = true,
    this.targetSampleRate = 16000,
  });
}

// =============================================================================
// DATA SOURCE TYPES
// =============================================================================

/// Data source types for media inputs.
enum DataSource {
  /// File path.
  filePath,

  /// Base64 encoded data.
  base64,

  /// Raw samples (for audio).
  rawSamples,

  /// URL (not yet supported).
  url,
}

// =============================================================================
// STRUCTURED OUTPUT TYPES
// =============================================================================

/// Output format types.
enum OutputFormat {
  /// Plain text.
  text,

  /// JSON format.
  json,

  /// YAML format.
  yaml,

  /// CSV format.
  csv,

  /// Markdown format.
  markdown,

  /// XML format.
  xml,
}

/// Structured output configuration.
class StructuredOutput {
  final OutputFormat format;
  final String? schema;
  final bool strictValidation;
  final bool prettyPrint;

  const StructuredOutput({
    this.format = OutputFormat.json,
    this.schema,
    this.strictValidation = false,
    this.prettyPrint = false,
  });
}

/// Text template configuration.
class TextTemplate {
  final String templateString;
  final Map<String, String> variables;
  final bool escapeHtml;
  final bool preserveWhitespace;

  const TextTemplate({
    required this.templateString,
    this.variables = const {},
    this.escapeHtml = true,
    this.preserveWhitespace = false,
  });
}

/// Schema validation configuration.
class SchemaValidation {
  final bool enableValidation;
  final int maxDepth;
  final bool allowAdditionalProperties;
  final bool strictTypeChecking;

  const SchemaValidation({
    this.enableValidation = true,
    this.maxDepth = 10,
    this.allowAdditionalProperties = true,
    this.strictTypeChecking = false,
  });
}

// =============================================================================
// LORA TYPES
// =============================================================================

/// LoRA adapter information.
class LoraAdapterInfo {
  final String name;
  final String filePath;
  final double scale;
  final bool isActive;
  final String? description;
  final List<String> targetModules;

  const LoraAdapterInfo({
    required this.name,
    required this.filePath,
    this.scale = 1.0,
    this.isActive = false,
    this.description,
    this.targetModules = const [],
  });
}

/// LoRA merge strategy.
enum MergeStrategy {
  /// Simple addition.
  add,

  /// Weighted merge.
  weighted,

  /// Concatenation.
  concatenate,
}

/// LoRA batch configuration.
class LoraBatch {
  final List<String> adapters;
  final List<double> scales;
  final MergeStrategy mergeStrategy;
  final bool enableBatching;

  const LoraBatch({
    required this.adapters,
    required this.scales,
    this.mergeStrategy = MergeStrategy.weighted,
    this.enableBatching = true,
  });
}

/// LoRA management configuration.
class LoraManagement {
  final bool autoLoadConfig;
  final String? configPath;
  final bool enableCaching;
  final int maxCachedAdapters;

  const LoraManagement({
    this.autoLoadConfig = false,
    this.configPath,
    this.enableCaching = true,
    this.maxCachedAdapters = 5,
  });
}

// =============================================================================
// STREAMING TYPES
// =============================================================================

/// Stream types for different output modalities.
enum StreamType {
  /// Text token stream.
  textTokens,

  /// Audio sample stream.
  audioSamples,

  /// Structured data chunks.
  structuredChunks,
}

/// Stream configuration.
class StreamConfig {
  final StreamType streamType;
  final int bufferSize;
  final int chunkSize;
  final bool enableRealTime;
  final int maxLatencyMs;

  const StreamConfig({
    this.streamType = StreamType.textTokens,
    this.bufferSize = 1024,
    this.chunkSize = 128,
    this.enableRealTime = true,
    this.maxLatencyMs = 50,
  });
}

/// Stream callback configuration.
class StreamCallbackConfig {
  final void Function(String)? onTextToken;
  final void Function(Float32List)? onAudioSamples;
  final void Function(String)? onStructuredChunk;
  final void Function(String)? onError;

  const StreamCallbackConfig({
    this.onTextToken,
    this.onAudioSamples,
    this.onStructuredChunk,
    this.onError,
  });
}

/// Stream event for different data types.
class StreamEvent {
  final StreamType type;
  final String? token;
  final Float32List? samples;
  final int? sampleRate;
  final bool isFinalToken;
  final bool isFinalChunk;
  final double? confidence;

  const StreamEvent._({
    required this.type,
    this.token,
    this.samples,
    this.sampleRate,
    this.isFinalToken = false,
    this.isFinalChunk = false,
    this.confidence,
  });

  factory StreamEvent.text({
    required String token,
    bool isFinalToken = false,
    double? confidence,
  }) {
    return StreamEvent._(
      type: StreamType.textTokens,
      token: token,
      isFinalToken: isFinalToken,
      confidence: confidence,
    );
  }

  factory StreamEvent.audio({
    required Float32List samples,
    required int sampleRate,
    bool isFinalChunk = false,
  }) {
    return StreamEvent._(
      type: StreamType.audioSamples,
      samples: samples,
      sampleRate: sampleRate,
      isFinalChunk: isFinalChunk,
    );
  }
}

// =============================================================================
// TEXT PROCESSING TYPES
// =============================================================================

/// Text preprocessing configuration.
class TextPreprocessing {
  final bool normalizeWhitespace;
  final bool removeMarkdown;
  final bool escapeSpecialChars;
  final int maxLength;

  const TextPreprocessing({
    this.normalizeWhitespace = true,
    this.removeMarkdown = false,
    this.escapeSpecialChars = false,
    this.maxLength = 10000,
  });
}

/// Memory strategy for chat sessions.
enum MemoryStrategy {
  /// Fixed window.
  fixed,

  /// Sliding window.
  sliding,

  /// Summary-based compression.
  summary,
}

/// Chat session configuration.
class ChatSessionConfig {
  final String? systemPrompt;
  final int maxHistoryLength;
  final bool enableMemory;
  final MemoryStrategy memoryStrategy;

  const ChatSessionConfig({
    this.systemPrompt,
    this.maxHistoryLength = 50,
    this.enableMemory = true,
    this.memoryStrategy = MemoryStrategy.sliding,
  });
}

/// Content analysis configuration.
class ContentAnalysis {
  final bool enableSentiment;
  final bool enableEntityExtraction;
  final bool enableKeywordExtraction;
  final bool enableLanguageDetection;
  final int maxKeywords;

  const ContentAnalysis({
    this.enableSentiment = false,
    this.enableEntityExtraction = false,
    this.enableKeywordExtraction = false,
    this.enableLanguageDetection = false,
    this.maxKeywords = 10,
  });
}

/// Translation configuration.
class TranslationConfig {
  final String sourceLanguage;
  final String targetLanguage;
  final bool enableAutoDetect;
  final bool preserveFormatting;

  const TranslationConfig({
    required this.sourceLanguage,
    required this.targetLanguage,
    this.enableAutoDetect = true,
    this.preserveFormatting = true,
  });
}

// =============================================================================
// MULTIMODAL TYPES
// =============================================================================

/// Multimodal inference parameters.
class MultimodalInferParams {
  final String prompt;
  final List<MediaInput> mediaInputs;
  final int maxTokens;
  final double temperature;
  final bool includeImageTokens;
  final bool preserveImageOrder;
  final int visionThreads;
  final bool useVisionCache;

  const MultimodalInferParams({
    required this.prompt,
    this.mediaInputs = const [],
    this.maxTokens = 128,
    this.temperature = 0.8,
    this.includeImageTokens = false,
    this.preserveImageOrder = true,
    this.visionThreads = 4,
    this.useVisionCache = true,
  });
}

/// Media batch processing configuration.
class MediaBatch {
  final List<MediaInput> inputs;
  final bool processParallel;
  final int maxBatchSize;
  final bool enableCaching;

  const MediaBatch({
    required this.inputs,
    this.processParallel = true,
    this.maxBatchSize = 8,
    this.enableCaching = true,
  });
}

/// Workflow stages for multimodal processing.
enum WorkflowStage {
  /// Image preprocessing stage.
  imagePreprocessing,

  /// Audio preprocessing stage.
  audioPreprocessing,

  /// Feature extraction stage.
  featureExtraction,

  /// Multimodal fusion stage.
  multimodalFusion,

  /// Text generation stage.
  textGeneration,
}

/// Multimodal workflow configuration.
class MultimodalWorkflow {
  final List<WorkflowStage> stages;
  final bool enablePipeline;
  final List<WorkflowStage> parallelStages;
  final OutputFormat outputFormat;

  const MultimodalWorkflow({
    required this.stages,
    this.enablePipeline = true,
    this.parallelStages = const [],
    this.outputFormat = OutputFormat.text,
  });
}

// =============================================================================
// ERROR HANDLING TYPES
// =============================================================================

/// Error handling configuration.
class ErrorHandling {
  final bool enableDetailedErrors;
  final bool includeStackTrace;
  final int maxErrorMessageLength;
  final bool enableErrorLogging;

  const ErrorHandling({
    this.enableDetailedErrors = true,
    this.includeStackTrace = false,
    this.maxErrorMessageLength = 512,
    this.enableErrorLogging = true,
  });
}

// =============================================================================
// PERFORMANCE TYPES
// =============================================================================

/// Performance monitoring configuration.
class PerformanceConfig {
  final bool enableProfiling;
  final bool trackMemoryUsage;
  final bool trackProcessingTime;
  final bool enableBenchmarking;
  final int maxProfilingHistory;

  const PerformanceConfig({
    this.enableProfiling = false,
    this.trackMemoryUsage = false,
    this.trackProcessingTime = false,
    this.enableBenchmarking = false,
    this.maxProfilingHistory = 100,
  });
}

/// Memory configuration.
class MemoryConfig {
  final bool enableCaching;
  final int maxCacheSize;
  final bool enableGarbageCollection;
  final double gcThreshold;

  const MemoryConfig({
    this.enableCaching = true,
    this.maxCacheSize = 256 * 1024 * 1024,
    this.enableGarbageCollection = true,
    this.gcThreshold = 0.8,
  });
}

/// Threading configuration.
class ThreadingConfig {
  final int textThreads;
  final int visionThreads;
  final int audioThreads;
  final bool enableParallelProcessing;
  final int maxConcurrentOperations;

  const ThreadingConfig({
    this.textThreads = 4,
    this.visionThreads = 4,
    this.audioThreads = 2,
    this.enableParallelProcessing = true,
    this.maxConcurrentOperations = 16,
  });
}

/// A Flutter package for running language models on device with support for
/// completion, instruct mode, tool calling, streaming, constrained generation,
/// and LoRA.
class Llamafu {
  late final LlamafuBindings _bindings;
  late final Pointer<LlamafuModelParams> _modelParams;
  late final Pointer<Void> _llamafuInstance;
  final List<LoraAdapter> _loraAdapters = [];
  final List<GrammarSampler> _grammarSamplers = [];

  Llamafu._(this._bindings, this._modelParams, this._llamafuInstance);

  /// Maximum allowed length for prompts to prevent excessive memory usage
  static const int maxPromptLength = 100000;

  /// Maximum allowed number of tokens to prevent resource exhaustion
  static const int maxTokens = 8192;

  /// Minimum and maximum temperature values
  static const double minTemperature = 0.0;
  static const double maxTemperature = 2.0;

  /// Validates file path for security
  static bool _isValidFilePath(String filePath) {
    // Check for null bytes
    if (filePath.contains('\0')) return false;

    // Check for path traversal attempts
    if (filePath.contains('..')) return false;

    // Check for absolute paths with suspicious patterns
    if (filePath.startsWith('/etc/') ||
        filePath.startsWith('/usr/') ||
        filePath.startsWith('/system/') ||
        filePath.contains('/proc/') ||
        filePath.contains('/dev/')) return false;

    // Check file length
    if (filePath.length > 4096) return false;

    return true;
  }

  /// Validates numerical parameters
  static bool _isValidParameter(double value, double min, double max) {
    return value >= min && value <= max && value.isFinite;
  }

  /// Validates prompt content
  static bool _isValidPrompt(String prompt) {
    // Check for null bytes
    if (prompt.contains('\0')) return false;

    // Check length
    if (prompt.length > maxPromptLength) return false;

    // Check for control characters (except common ones like newline, tab)
    for (int i = 0; i < prompt.length; i++) {
      final codeUnit = prompt.codeUnitAt(i);
      if (codeUnit < 32 && codeUnit != 9 && codeUnit != 10 && codeUnit != 13) {
        return false;
      }
    }

    return true;
  }

  /// Initializes the Llamafu library with the specified model.
  ///
  /// [modelPath] is the path to the GGUF model file.
  /// [mmprojPath] is the optional path to the multi-modal projector file.
  /// [threads] is the number of threads to use for inference (default: 4).
  /// [contextSize] is the context size for the model (default: 512).
  /// [useGpu] whether to use GPU for multi-modal processing (default: false).
  ///
  /// Returns a [Llamafu] instance that can be used for text generation.
  ///
  /// Throws an exception if initialization fails.
  static Future<Llamafu> init({
    required String modelPath,
    String? mmprojPath,  // Multi-modal projector path (optional)
    int threads = 4,
    int contextSize = 512,
    bool useGpu = false,
  }) async {
    // Input validation
    if (!_isValidFilePath(modelPath)) {
      throw ArgumentError('Invalid model path: $modelPath');
    }

    if (mmprojPath != null && !_isValidFilePath(mmprojPath)) {
      throw ArgumentError('Invalid multi-modal projector path: $mmprojPath');
    }

    if (threads < 1 || threads > 64) {
      throw ArgumentError('Invalid thread count: $threads (must be 1-64)');
    }

    if (contextSize < 1 || contextSize > 32768) {
      throw ArgumentError('Invalid context size: $contextSize (must be 1-32768)');
    }

    // Check if model file exists and is readable
    final modelFile = File(modelPath);
    if (!await modelFile.exists()) {
      throw ArgumentError('Model file does not exist: $modelPath');
    }

    if (mmprojPath != null) {
      final mmprojFile = File(mmprojPath);
      if (!await mmprojFile.exists()) {
        throw ArgumentError('Multi-modal projector file does not exist: $mmprojPath');
      }
    }

    final bindings = await LlamafuBindings.init();

    // Allocate and initialize model parameters
    final modelParams = malloc<LlamafuModelParams>();
    modelParams.ref.model_path = modelPath.toNativeUtf8();
    modelParams.ref.mmproj_path = mmprojPath?.toNativeUtf8() ?? nullptr;
    modelParams.ref.n_threads = threads;
    modelParams.ref.n_ctx = contextSize;
    modelParams.ref.use_gpu = useGpu ? 1 : 0;

    // Initialize the native library
    final outLlamafu = malloc<Pointer<Void>>();
    final result = bindings.llamafuInit(modelParams, outLlamafu);

    if (result != 0) {
      malloc.free(modelParams);
      malloc.free(outLlamafu);
      throw Exception('Failed to initialize Llamafu: $result');
    }

    return Llamafu._(bindings, modelParams, outLlamafu.value);
  }

  /// Performs text completion with the loaded model.
  ///
  /// [prompt] is the input text to generate from.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns the generated text.
  ///
  /// Throws an exception if completion fails.
  Future<String> complete({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.8,
  }) async {
    // Input validation
    if (!_isValidPrompt(prompt)) {
      throw ArgumentError('Invalid prompt: contains invalid characters or is too long');
    }

    if (maxTokens < 1 || maxTokens > Llamafu.maxTokens) {
      throw ArgumentError('Invalid maxTokens: $maxTokens (must be 1-${Llamafu.maxTokens})');
    }

    if (!_isValidParameter(temperature, minTemperature, maxTemperature)) {
      throw ArgumentError('Invalid temperature: $temperature (must be $minTemperature-$maxTemperature)');
    }

    // Allocate and initialize inference parameters
    final inferParams = malloc<LlamafuInferParams>();
    inferParams.ref.prompt = prompt.toNativeUtf8();
    inferParams.ref.max_tokens = maxTokens;
    inferParams.ref.temperature = temperature;

    // Allocate output result
    final outResult = malloc<Pointer<Utf8>>();

    // Perform completion
    final result = _bindings.llamafuComplete(_llamafuInstance, inferParams, outResult);

    // Free inference parameters
    malloc.free(inferParams);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to complete: $result');
    }

    // Convert result to Dart string
    final dartResult = outResult.value.toDartString();
    malloc.free(outResult.value);
    malloc.free(outResult);

    return dartResult;
  }

  /// Performs streaming text completion with the loaded model.
  ///
  /// [prompt] is the input text to generate from.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns a [Stream] of tokens as they are generated.
  ///
  /// Throws an exception if streaming fails.
  Stream<String> completeStream({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.8,
  }) {
    // Input validation
    if (!_isValidPrompt(prompt)) {
      throw ArgumentError('Invalid prompt: contains invalid characters or is too long');
    }

    if (maxTokens < 1 || maxTokens > Llamafu.maxTokens) {
      throw ArgumentError('Invalid maxTokens: $maxTokens (must be 1-${Llamafu.maxTokens})');
    }

    if (!_isValidParameter(temperature, minTemperature, maxTemperature)) {
      throw ArgumentError('Invalid temperature: $temperature (must be $minTemperature-$maxTemperature)');
    }

    final controller = StreamController<String>();

    // Run the streaming operation
    _runStreamingCompletion(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
      controller: controller,
    );

    return controller.stream;
  }

  Future<void> _runStreamingCompletion({
    required String prompt,
    required int maxTokens,
    required double temperature,
    required StreamController<String> controller,
  }) async {
    // Allocate and initialize inference parameters
    final inferParams = malloc<LlamafuInferParams>();
    inferParams.ref.prompt = prompt.toNativeUtf8();
    inferParams.ref.max_tokens = maxTokens;
    inferParams.ref.temperature = temperature;

    // Create a native callable for the streaming callback
    late final NativeCallable<LlamafuStreamCallbackC> nativeCallback;

    void onToken(Pointer<Utf8> token, Pointer<Void> userData) {
      if (token != nullptr) {
        final dartToken = token.toDartString();
        controller.add(dartToken);
      }
    }

    nativeCallback = NativeCallable<LlamafuStreamCallbackC>.listener(onToken);

    try {
      // Perform streaming completion
      final result = _bindings.llamafuCompleteStream(
        _llamafuInstance,
        inferParams,
        nativeCallback.nativeFunction,
        nullptr,
      );

      if (result != 0) {
        controller.addError(Exception('Streaming completion failed: $result'));
      }
    } catch (e) {
      controller.addError(e);
    } finally {
      // Clean up
      malloc.free(inferParams.ref.prompt);
      malloc.free(inferParams);
      nativeCallback.close();
      await controller.close();
    }
  }

  /// Performs text completion with grammar constraints.
  ///
  /// [prompt] is the input text to generate from.
  /// [grammarStr] is the GBNF grammar string to constrain generation.
  /// [grammarRoot] is the root symbol of the grammar.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns the generated text that conforms to the specified grammar.
  ///
  /// Throws an exception if completion fails.
  Future<String> completeWithGrammar({
    required String prompt,
    String? grammarStr,
    String? grammarRoot,
    int maxTokens = 128,
    double temperature = 0.8,
  }) async {
    // Allocate and initialize inference parameters
    final inferParams = malloc<LlamafuInferParams>();
    inferParams.ref.prompt = prompt.toNativeUtf8();
    inferParams.ref.max_tokens = maxTokens;
    inferParams.ref.temperature = temperature;

    // Allocate and initialize grammar parameters
    final grammarParams = malloc<LlamafuGrammarParams>();
    grammarParams.ref.grammar_str = grammarStr?.toNativeUtf8() ?? nullptr;
    grammarParams.ref.grammar_root = grammarRoot?.toNativeUtf8() ?? nullptr;

    // Allocate output result
    final outResult = malloc<Pointer<Utf8>>();

    // Perform completion with grammar constraints
    final result = _bindings.llamafuCompleteWithGrammar(_llamafuInstance, inferParams, grammarParams, outResult);

    // Free inference parameters
    malloc.free(inferParams);
    
    // Free grammar parameters
    if (grammarStr != null) malloc.free(grammarParams.ref.grammar_str);
    if (grammarRoot != null) malloc.free(grammarParams.ref.grammar_root);
    malloc.free(grammarParams);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to complete with grammar: $result');
    }

    // Convert result to Dart string
    final dartResult = outResult.value.toDartString();
    malloc.free(outResult.value);
    malloc.free(outResult);

    return dartResult;
  }

  /// Performs streaming text completion with grammar constraints.
  ///
  /// [prompt] is the input text to generate from.
  /// [grammarStr] is the GBNF grammar string to constrain generation.
  /// [grammarRoot] is the root symbol of the grammar.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns a [Stream] of tokens that conform to the specified grammar.
  ///
  /// Throws an exception if streaming fails.
  Stream<String> completeWithGrammarStream({
    required String prompt,
    String? grammarStr,
    String? grammarRoot,
    int maxTokens = 128,
    double temperature = 0.8,
  }) {
    // Input validation
    if (!_isValidPrompt(prompt)) {
      throw ArgumentError('Invalid prompt: contains invalid characters or is too long');
    }

    if (maxTokens < 1 || maxTokens > Llamafu.maxTokens) {
      throw ArgumentError('Invalid maxTokens: $maxTokens (must be 1-${Llamafu.maxTokens})');
    }

    if (!_isValidParameter(temperature, minTemperature, maxTemperature)) {
      throw ArgumentError('Invalid temperature: $temperature (must be $minTemperature-$maxTemperature)');
    }

    final controller = StreamController<String>();

    // Run the streaming operation
    _runStreamingCompletionWithGrammar(
      prompt: prompt,
      grammarStr: grammarStr,
      grammarRoot: grammarRoot,
      maxTokens: maxTokens,
      temperature: temperature,
      controller: controller,
    );

    return controller.stream;
  }

  Future<void> _runStreamingCompletionWithGrammar({
    required String prompt,
    String? grammarStr,
    String? grammarRoot,
    required int maxTokens,
    required double temperature,
    required StreamController<String> controller,
  }) async {
    // Allocate and initialize inference parameters
    final inferParams = malloc<LlamafuInferParams>();
    inferParams.ref.prompt = prompt.toNativeUtf8();
    inferParams.ref.max_tokens = maxTokens;
    inferParams.ref.temperature = temperature;

    // Allocate and initialize grammar parameters
    final grammarParams = malloc<LlamafuGrammarParams>();
    grammarParams.ref.grammar_str = grammarStr?.toNativeUtf8() ?? nullptr;
    grammarParams.ref.grammar_root = grammarRoot?.toNativeUtf8() ?? nullptr;

    // Create a native callable for the streaming callback
    late final NativeCallable<LlamafuStreamCallbackC> nativeCallback;

    void onToken(Pointer<Utf8> token, Pointer<Void> userData) {
      if (token != nullptr) {
        final dartToken = token.toDartString();
        controller.add(dartToken);
      }
    }

    nativeCallback = NativeCallable<LlamafuStreamCallbackC>.listener(onToken);

    try {
      // Perform streaming completion with grammar
      final result = _bindings.llamafuCompleteWithGrammarStream(
        _llamafuInstance,
        inferParams,
        grammarParams,
        nativeCallback.nativeFunction,
        nullptr,
      );

      if (result != 0) {
        controller.addError(Exception('Streaming completion with grammar failed: $result'));
      }
    } catch (e) {
      controller.addError(e);
    } finally {
      // Clean up
      malloc.free(inferParams.ref.prompt);
      malloc.free(inferParams);
      if (grammarStr != null) malloc.free(grammarParams.ref.grammar_str);
      if (grammarRoot != null) malloc.free(grammarParams.ref.grammar_root);
      malloc.free(grammarParams);
      nativeCallback.close();
      await controller.close();
    }
  }

  /// Performs streaming multi-modal completion.
  ///
  /// [prompt] is the input text prompt that may contain media placeholders.
  /// [mediaInputs] is a list of [MediaInput] objects containing media data.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns a [Stream] of tokens as they are generated.
  ///
  /// Throws an exception if streaming fails.
  Stream<String> multimodalCompleteStream({
    required String prompt,
    List<MediaInput> mediaInputs = const [],
    int maxTokens = 128,
    double temperature = 0.8,
  }) {
    // Input validation
    if (!_isValidPrompt(prompt)) {
      throw ArgumentError('Invalid prompt: contains invalid characters or is too long');
    }

    if (maxTokens < 1 || maxTokens > Llamafu.maxTokens) {
      throw ArgumentError('Invalid maxTokens: $maxTokens (must be 1-${Llamafu.maxTokens})');
    }

    if (!_isValidParameter(temperature, minTemperature, maxTemperature)) {
      throw ArgumentError('Invalid temperature: $temperature (must be $minTemperature-$maxTemperature)');
    }

    final controller = StreamController<String>();

    // Run the streaming operation
    _runMultimodalStreamingCompletion(
      prompt: prompt,
      mediaInputs: mediaInputs,
      maxTokens: maxTokens,
      temperature: temperature,
      controller: controller,
    );

    return controller.stream;
  }

  Future<void> _runMultimodalStreamingCompletion({
    required String prompt,
    required List<MediaInput> mediaInputs,
    required int maxTokens,
    required double temperature,
    required StreamController<String> controller,
  }) async {
    // Allocate and initialize multi-modal inference parameters
    final multimodalParams = malloc<LlamafuMultimodalInferParams>();
    multimodalParams.ref.prompt = prompt.toNativeUtf8();
    multimodalParams.ref.n_media_inputs = mediaInputs.length;
    multimodalParams.ref.max_tokens = maxTokens;
    multimodalParams.ref.temperature = temperature;

    // Allocate media inputs array
    Pointer<LlamafuMediaInput>? mediaInputsArray;
    if (mediaInputs.isNotEmpty) {
      mediaInputsArray = malloc<LlamafuMediaInput>(mediaInputs.length);
      for (int i = 0; i < mediaInputs.length; i++) {
        mediaInputsArray[i].type = mediaInputs[i].type.index;
        mediaInputsArray[i].data = mediaInputs[i].data.toNativeUtf8();
        mediaInputsArray[i].data_size = mediaInputs[i].data.length;
      }
      multimodalParams.ref.media_inputs = mediaInputsArray;
    } else {
      multimodalParams.ref.media_inputs = nullptr;
    }

    // Create a native callable for the streaming callback
    late final NativeCallable<LlamafuStreamCallbackC> nativeCallback;

    void onToken(Pointer<Utf8> token, Pointer<Void> userData) {
      if (token != nullptr) {
        final dartToken = token.toDartString();
        controller.add(dartToken);
      }
    }

    nativeCallback = NativeCallable<LlamafuStreamCallbackC>.listener(onToken);

    try {
      // Perform streaming multi-modal completion
      final result = _bindings.llamafuMultimodalCompleteStream(
        _llamafuInstance,
        multimodalParams,
        nativeCallback.nativeFunction,
        nullptr,
      );

      if (result != 0) {
        controller.addError(Exception('Multi-modal streaming completion failed: $result'));
      }
    } catch (e) {
      controller.addError(e);
    } finally {
      // Clean up media inputs
      if (mediaInputs.isNotEmpty && mediaInputsArray != null) {
        for (int i = 0; i < mediaInputs.length; i++) {
          malloc.free(mediaInputsArray[i].data);
        }
        malloc.free(mediaInputsArray);
      }
      malloc.free(multimodalParams.ref.prompt);
      malloc.free(multimodalParams);
      nativeCallback.close();
      await controller.close();
    }
  }

  /// Performs multi-modal completion with text and media inputs.
  ///
  /// [prompt] is the input text prompt that may contain media placeholders.
  /// [mediaInputs] is a list of [MediaInput] objects containing media data.
  /// [maxTokens] is the maximum number of tokens to generate (default: 128).
  /// [temperature] is the sampling temperature (default: 0.8).
  ///
  /// Returns the generated text based on both text and media inputs.
  ///
  /// Throws an exception if multi-modal completion fails.
  Future<String> multimodalComplete({
    required String prompt,
    List<MediaInput> mediaInputs = const [],
    int maxTokens = 128,
    double temperature = 0.8,
  }) async {
    // Allocate and initialize multi-modal inference parameters
    final multimodalParams = malloc<LlamafuMultimodalInferParams>();
    multimodalParams.ref.prompt = prompt.toNativeUtf8();
    multimodalParams.ref.n_media_inputs = mediaInputs.length;
    multimodalParams.ref.max_tokens = maxTokens;
    multimodalParams.ref.temperature = temperature;

    // Allocate media inputs array
    if (mediaInputs.isNotEmpty) {
      final mediaInputsArray = malloc<LlamafuMediaInput>(mediaInputs.length);
      for (int i = 0; i < mediaInputs.length; i++) {
        mediaInputsArray[i].type = mediaInputs[i].type.index;
        mediaInputsArray[i].data = mediaInputs[i].data.toNativeUtf8();
        mediaInputsArray[i].data_size = mediaInputs[i].data.length;
      }
      multimodalParams.ref.media_inputs = mediaInputsArray;
    } else {
      multimodalParams.ref.media_inputs = nullptr;
    }

    // Allocate output result
    final outResult = malloc<Pointer<Utf8>>();

    // Perform multi-modal completion
    final result = _bindings.llamafuMultimodalComplete(_llamafuInstance, multimodalParams, outResult);

    // Free media inputs array
    if (mediaInputs.isNotEmpty) {
      malloc.free(multimodalParams.ref.media_inputs);
    }

    // Free inference parameters
    malloc.free(multimodalParams);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to complete multi-modal inference: $result');
    }

    // Convert result to Dart string
    final dartResult = outResult.value.toDartString();
    malloc.free(outResult.value);
    malloc.free(outResult);

    return dartResult;
  }

  /// Loads a LoRA adapter from the specified file path.
  ///
  /// [loraPath] is the path to the LoRA adapter GGUF file.
  ///
  /// Returns a [LoraAdapter] instance that can be applied to the model.
  ///
  /// Throws an exception if the LoRA adapter fails to load.
  Future<LoraAdapter> loadLoraAdapter(String loraPath) async {
    // Input validation
    if (!_isValidFilePath(loraPath)) {
      throw ArgumentError('Invalid LoRA adapter path: $loraPath');
    }

    // Check if LoRA file exists
    final loraFile = File(loraPath);
    if (!await loraFile.exists()) {
      throw ArgumentError('LoRA adapter file does not exist: $loraPath');
    }

    final loraPathPtr = loraPath.toNativeUtf8();
    final outAdapter = malloc<Pointer<Void>>();

    final result = _bindings.llamafuLoraAdapterInit(_llamafuInstance, loraPathPtr, outAdapter);

    malloc.free(loraPathPtr);

    if (result != 0) {
      malloc.free(outAdapter);
      throw Exception('Failed to load LoRA adapter: $result');
    }

    final adapter = LoraAdapter._(_bindings, outAdapter.value);
    _loraAdapters.add(adapter);
    return adapter;
  }

  /// Applies a LoRA adapter to the model with the specified scale.
  ///
  /// [adapter] is the LoRA adapter to apply.
  /// [scale] is the scaling factor for the adapter (default: 1.0).
  ///
  /// Throws an exception if the LoRA adapter fails to apply.
  Future<void> applyLoraAdapter(LoraAdapter adapter, {double scale = 1.0}) async {
    // Input validation
    if (!_isValidParameter(scale, -10.0, 10.0)) {
      throw ArgumentError('Invalid LoRA scale: $scale (must be -10.0 to 10.0)');
    }

    final result = _bindings.llamafuLoraAdapterApply(_llamafuInstance, adapter._nativeAdapter, scale);
    if (result != 0) {
      throw Exception('Failed to apply LoRA adapter: $result');
    }
  }

  /// Removes a LoRA adapter from the model.
  ///
  /// [adapter] is the LoRA adapter to remove.
  ///
  /// Throws an exception if the LoRA adapter fails to remove.
  Future<void> removeLoraAdapter(LoraAdapter adapter) async {
    final result = _bindings.llamafuLoraAdapterRemove(_llamafuInstance, adapter._nativeAdapter);
    if (result != 0) {
      throw Exception('Failed to remove LoRA adapter: $result');
    }
  }

  /// Clears all LoRA adapters from the model.
  ///
  /// Throws an exception if clearing the adapters fails.
  Future<void> clearAllLoraAdapters() async {
    final result = _bindings.llamafuLoraAdapterClearAll(_llamafuInstance);
    if (result != 0) {
      throw Exception('Failed to clear LoRA adapters: $result');
    }
    
    // Free all adapter references
    for (final adapter in _loraAdapters) {
      _bindings.llamafuLoraAdapterFree(adapter._nativeAdapter);
    }
    _loraAdapters.clear();
  }

  /// Creates a grammar sampler for constrained generation.
  ///
  /// [grammarStr] is the GBNF grammar string to constrain generation.
  /// [grammarRoot] is the root symbol of the grammar.
  ///
  /// Returns a [GrammarSampler] instance that can be used for constrained generation.
  ///
  /// Throws an exception if the grammar sampler fails to initialize.
  Future<GrammarSampler> createGrammarSampler(String grammarStr, String grammarRoot) async {
    final grammarStrPtr = grammarStr.toNativeUtf8();
    final grammarRootPtr = grammarRoot.toNativeUtf8();
    final outSampler = malloc<Pointer<Void>>();

    final result = _bindings.llamafuGrammarSamplerInit(
        _llamafuInstance, grammarStrPtr, grammarRootPtr, outSampler);

    malloc.free(grammarStrPtr);
    malloc.free(grammarRootPtr);

    if (result != 0) {
      malloc.free(outSampler);
      throw Exception('Failed to create grammar sampler: $result');
    }

    final sampler = GrammarSampler._(_bindings, outSampler.value);
    _grammarSamplers.add(sampler);
    return sampler;
  }

  // ==========================================================================
  // TOKENIZATION API
  // ==========================================================================

  /// Tokenizes text into tokens.
  ///
  /// [text] is the input text to tokenize.
  /// [addSpecial] whether to add special tokens (default: true).
  /// [parseSpecial] whether to parse special tokens (default: true).
  ///
  /// Returns a list of token IDs.
  List<int> tokenize(String text, {bool addSpecial = true, bool parseSpecial = true}) {
    final textPtr = text.toNativeUtf8();
    final outTokens = malloc<Pointer<Int32>>();
    final outNTokens = malloc<Int32>();

    final result = _bindings.llamafuTokenize(
      _llamafuInstance, textPtr, text.length, outTokens, outNTokens, addSpecial, parseSpecial);

    malloc.free(textPtr);

    if (result != 0) {
      malloc.free(outTokens);
      malloc.free(outNTokens);
      throw Exception('Failed to tokenize text: $result');
    }

    final nTokens = outNTokens.value;
    final tokens = List<int>.generate(nTokens, (i) => outTokens.value[i]);

    _bindings.llamafuFreeTokens(outTokens.value);
    malloc.free(outTokens);
    malloc.free(outNTokens);

    return tokens;
  }

  /// Detokenizes tokens back into text.
  ///
  /// [tokens] is the list of token IDs to detokenize.
  /// [removeSpecial] whether to remove special tokens (default: true).
  /// [unparseSpecial] whether to unparse special tokens (default: true).
  ///
  /// Returns the detokenized text.
  String detokenize(List<int> tokens, {bool removeSpecial = true, bool unparseSpecial = true}) {
    final tokensPtr = malloc<Int32>(tokens.length);
    for (int i = 0; i < tokens.length; i++) {
      tokensPtr[i] = tokens[i];
    }

    final outText = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuDetokenize(
      _llamafuInstance, tokensPtr, tokens.length, outText, removeSpecial, unparseSpecial);

    malloc.free(tokensPtr);

    if (result != 0) {
      malloc.free(outText);
      throw Exception('Failed to detokenize tokens: $result');
    }

    final text = outText.value.toDartString();
    _bindings.llamafuFreeString(outText.value);
    malloc.free(outText);

    return text;
  }

  /// Gets the string representation of a single token.
  String tokenToPiece(int token) {
    final outPiece = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuTokenToPiece(_llamafuInstance, token, outPiece);

    if (result != 0) {
      malloc.free(outPiece);
      throw Exception('Failed to convert token to piece: $result');
    }

    final piece = outPiece.value.toDartString();
    _bindings.llamafuFreeString(outPiece.value);
    malloc.free(outPiece);

    return piece;
  }

  /// Gets the beginning-of-sequence token ID.
  int get bosToken => _bindings.llamafuTokenBos(_llamafuInstance);

  /// Gets the end-of-sequence token ID.
  int get eosToken => _bindings.llamafuTokenEos(_llamafuInstance);

  // ==========================================================================
  // EMBEDDINGS API
  // ==========================================================================

  /// Gets embeddings for the given text.
  ///
  /// [text] is the input text to get embeddings for.
  ///
  /// Returns a list of embedding values.
  Float32List getEmbeddings(String text) {
    final textPtr = text.toNativeUtf8();
    final outEmbeddings = malloc<Pointer<Float>>();
    final outNEmbd = malloc<Int32>();

    final result = _bindings.llamafuGetEmbeddings(_llamafuInstance, textPtr, outEmbeddings, outNEmbd);

    malloc.free(textPtr);

    if (result != 0) {
      malloc.free(outEmbeddings);
      malloc.free(outNEmbd);
      throw Exception('Failed to get embeddings: $result');
    }

    final nEmbd = outNEmbd.value;
    final embeddings = Float32List(nEmbd);
    for (int i = 0; i < nEmbd; i++) {
      embeddings[i] = outEmbeddings.value[i];
    }

    _bindings.llamafuFreeEmbeddings(outEmbeddings.value);
    malloc.free(outEmbeddings);
    malloc.free(outNEmbd);

    return embeddings;
  }

  // ==========================================================================
  // KV CACHE MANAGEMENT
  // ==========================================================================

  /// Clears the KV cache.
  void clearKvCache() => _bindings.llamafuKvCacheClear(_llamafuInstance);

  /// Removes tokens from the KV cache for a sequence.
  void kvCacheSeqRm(int seqId, int p0, int p1) =>
      _bindings.llamafuKvCacheSeqRm(_llamafuInstance, seqId, p0, p1);

  /// Copies KV cache from one sequence to another.
  void kvCacheSeqCp(int seqIdSrc, int seqIdDst, int p0, int p1) =>
      _bindings.llamafuKvCacheSeqCp(_llamafuInstance, seqIdSrc, seqIdDst, p0, p1);

  /// Keeps only the specified sequence in the KV cache.
  void kvCacheSeqKeep(int seqId) => _bindings.llamafuKvCacheSeqKeep(_llamafuInstance, seqId);

  // ==========================================================================
  // STATE MANAGEMENT
  // ==========================================================================

  /// Gets the size of the serialized state in bytes.
  int getStateSize() => _bindings.llamafuStateGetSize(_llamafuInstance);

  /// Saves the current state to a file.
  void saveState(String path) {
    if (!_isValidFilePath(path)) {
      throw ArgumentError('Invalid state file path: $path');
    }

    final pathPtr = path.toNativeUtf8();
    final result = _bindings.llamafuStateSaveFile(_llamafuInstance, pathPtr);
    malloc.free(pathPtr);

    if (result != 0) {
      throw Exception('Failed to save state: $result');
    }
  }

  /// Loads state from a file.
  void loadState(String path) {
    if (!_isValidFilePath(path)) {
      throw ArgumentError('Invalid state file path: $path');
    }

    final pathPtr = path.toNativeUtf8();
    final result = _bindings.llamafuStateLoadFile(_llamafuInstance, pathPtr);
    malloc.free(pathPtr);

    if (result != 0) {
      throw Exception('Failed to load state: $result');
    }
  }

  // ==========================================================================
  // MODEL INFO & PERFORMANCE
  // ==========================================================================

  /// Gets model information.
  ModelInfo getModelInfo() {
    final outInfo = malloc<LlamafuModelInfoStruct>();
    final result = _bindings.llamafuGetModelInfo(_llamafuInstance, outInfo);

    if (result != 0) {
      malloc.free(outInfo);
      throw Exception('Failed to get model info: $result');
    }

    final info = ModelInfo(
      vocabSize: outInfo.ref.n_vocab,
      contextLength: outInfo.ref.n_ctx_train,
      embeddingSize: outInfo.ref.n_embd,
      numLayers: outInfo.ref.n_layer,
      numHeads: outInfo.ref.n_head,
      numKvHeads: outInfo.ref.n_head_kv,
      name: outInfo.ref.name != nullptr ? outInfo.ref.name.toDartString() : '',
      architecture: outInfo.ref.architecture != nullptr ? outInfo.ref.architecture.toDartString() : '',
      numParams: outInfo.ref.n_params,
      sizeBytes: outInfo.ref.size_bytes,
      supportsEmbeddings: outInfo.ref.supports_embeddings,
      supportsMultimodal: outInfo.ref.supports_multimodal,
    );

    malloc.free(outInfo);
    return info;
  }

  /// Gets performance statistics.
  PerfStats getPerfStats() {
    final outStats = malloc<LlamafuPerfStatsStruct>();
    final result = _bindings.llamafuGetPerfStats(_llamafuInstance, outStats);

    if (result != 0) {
      malloc.free(outStats);
      throw Exception('Failed to get performance stats: $result');
    }

    final stats = PerfStats(
      startMs: outStats.ref.t_start_ms,
      endMs: outStats.ref.t_end_ms,
      loadMs: outStats.ref.t_load_ms,
      promptEvalMs: outStats.ref.t_p_eval_ms,
      evalMs: outStats.ref.t_eval_ms,
      promptTokens: outStats.ref.n_p_eval,
      evalTokens: outStats.ref.n_eval,
    );

    malloc.free(outStats);
    return stats;
  }

  /// Gets memory usage statistics.
  MemoryUsage getMemoryUsage() {
    final outUsage = malloc<LlamafuMemoryUsageStruct>();
    final result = _bindings.llamafuGetMemoryUsage(_llamafuInstance, outUsage);

    if (result != 0) {
      malloc.free(outUsage);
      throw Exception('Failed to get memory usage: $result');
    }

    final usage = MemoryUsage(
      modelSizeBytes: outUsage.ref.model_size_bytes,
      kvCacheSizeBytes: outUsage.ref.kv_cache_size_bytes,
      computeBufferSizeBytes: outUsage.ref.compute_buffer_size_bytes,
      totalSizeBytes: outUsage.ref.total_size_bytes,
    );

    malloc.free(outUsage);
    return usage;
  }

  /// Resets timing statistics.
  void resetTimings() => _bindings.llamafuResetTimings(_llamafuInstance);

  /// Warms up the model for better performance.
  void warmup() {
    final result = _bindings.llamafuWarmup(_llamafuInstance);
    if (result != 0) {
      throw Exception('Failed to warm up model: $result');
    }
  }

  /// Sets the number of threads for inference.
  void setThreads(int nThreads, {int? nThreadsBatch}) {
    final result = _bindings.llamafuSetNThreads(
      _llamafuInstance, nThreads, nThreadsBatch ?? nThreads);
    if (result != 0) {
      throw Exception('Failed to set threads: $result');
    }
  }

  /// Benchmarks the model.
  BenchmarkResult benchmark({int nThreads = 4, int nPredict = 128}) {
    final outResult = malloc<LlamafuBenchResultStruct>();
    final result = _bindings.llamafuBenchModel(_llamafuInstance, nThreads, nPredict, outResult);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to benchmark model: $result');
    }

    final benchResult = BenchmarkResult(
      promptTokens: outResult.ref.prompt_tokens,
      promptTimeMs: outResult.ref.prompt_time_ms,
      generationTokens: outResult.ref.generation_tokens,
      generationTimeMs: outResult.ref.generation_time_ms,
      totalTimeMs: outResult.ref.total_time_ms,
      promptSpeedTps: outResult.ref.prompt_speed_tps,
      generationSpeedTps: outResult.ref.generation_speed_tps,
    );

    malloc.free(outResult);
    return benchResult;
  }

  // ==========================================================================
  // TEXT ANALYSIS
  // ==========================================================================

  /// Detects the language of the given text.
  LanguageDetection detectLanguage(String text) {
    final textPtr = text.toNativeUtf8();
    final outLanguageCode = malloc<Pointer<Utf8>>();
    final outConfidence = malloc<Float>();

    final result = _bindings.llamafuDetectLanguage(
      _llamafuInstance, textPtr, outLanguageCode, outConfidence);

    malloc.free(textPtr);

    if (result != 0) {
      malloc.free(outLanguageCode);
      malloc.free(outConfidence);
      throw Exception('Failed to detect language: $result');
    }

    final detection = LanguageDetection(
      languageCode: outLanguageCode.value.toDartString(),
      confidence: outConfidence.value,
    );

    _bindings.llamafuFreeString(outLanguageCode.value);
    malloc.free(outLanguageCode);
    malloc.free(outConfidence);

    return detection;
  }

  /// Analyzes sentiment of the given text.
  SentimentAnalysis analyzeSentiment(String text) {
    final textPtr = text.toNativeUtf8();
    final outPositive = malloc<Float>();
    final outNegative = malloc<Float>();
    final outNeutral = malloc<Float>();

    final result = _bindings.llamafuAnalyzeSentiment(
      _llamafuInstance, textPtr, outPositive, outNegative, outNeutral);

    malloc.free(textPtr);

    if (result != 0) {
      malloc.free(outPositive);
      malloc.free(outNegative);
      malloc.free(outNeutral);
      throw Exception('Failed to analyze sentiment: $result');
    }

    final analysis = SentimentAnalysis(
      positive: outPositive.value,
      negative: outNegative.value,
      neutral: outNeutral.value,
    );

    malloc.free(outPositive);
    malloc.free(outNegative);
    malloc.free(outNeutral);

    return analysis;
  }

  /// Extracts keywords from the given text.
  String extractKeywords(String text, {int maxKeywords = 10}) {
    final textPtr = text.toNativeUtf8();
    final outKeywordsJson = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuExtractKeywords(
      _llamafuInstance, textPtr, maxKeywords, outKeywordsJson);

    malloc.free(textPtr);

    if (result != 0) {
      malloc.free(outKeywordsJson);
      throw Exception('Failed to extract keywords: $result');
    }

    final keywords = outKeywordsJson.value.toDartString();
    _bindings.llamafuFreeString(outKeywordsJson.value);
    malloc.free(outKeywordsJson);

    return keywords;
  }

  /// Summarizes the given text.
  String summarize(String text, {int maxLength = 100, String style = 'brief'}) {
    final textPtr = text.toNativeUtf8();
    final stylePtr = style.toNativeUtf8();
    final outSummary = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuTextSummarize(
      _llamafuInstance, textPtr, maxLength, stylePtr, outSummary);

    malloc.free(textPtr);
    malloc.free(stylePtr);

    if (result != 0) {
      malloc.free(outSummary);
      throw Exception('Failed to summarize text: $result');
    }

    final summary = outSummary.value.toDartString();
    _bindings.llamafuFreeString(outSummary.value);
    malloc.free(outSummary);

    return summary;
  }

  // ==========================================================================
  // STRUCTURED OUTPUT
  // ==========================================================================

  /// Generates structured output based on a schema.
  String generateStructured(String prompt, {
    OutputFormat format = OutputFormat.json,
    String? schema,
    bool strictValidation = false,
    bool prettyPrint = false,
  }) {
    final promptPtr = prompt.toNativeUtf8();
    final outConfig = malloc<LlamafuStructuredOutputStruct>();

    outConfig.ref.format = format.index;
    outConfig.ref.schema = schema?.toNativeUtf8() ?? nullptr;
    outConfig.ref.strict_validation = strictValidation;
    outConfig.ref.pretty_print = prettyPrint;
    outConfig.ref.max_depth = 10;
    outConfig.ref.field_separator = nullptr;
    outConfig.ref.custom_template = nullptr;

    final outResult = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuGenerateStructured(
      _llamafuInstance, promptPtr, outConfig, outResult);

    malloc.free(promptPtr);
    if (schema != null) malloc.free(outConfig.ref.schema);
    malloc.free(outConfig);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to generate structured output: $result');
    }

    final output = outResult.value.toDartString();
    _bindings.llamafuFreeString(outResult.value);
    malloc.free(outResult);

    return output;
  }

  /// Validates JSON against a schema.
  JsonValidationResult validateJsonSchema(String jsonString, String schema) {
    final jsonPtr = jsonString.toNativeUtf8();
    final schemaPtr = schema.toNativeUtf8();
    final outIsValid = malloc<Bool>();
    final outErrorMessage = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuValidateJsonSchema(
      jsonPtr, schemaPtr, outIsValid, outErrorMessage);

    malloc.free(jsonPtr);
    malloc.free(schemaPtr);

    if (result != 0) {
      malloc.free(outIsValid);
      malloc.free(outErrorMessage);
      throw Exception('Failed to validate JSON schema: $result');
    }

    final validationResult = JsonValidationResult(
      isValid: outIsValid.value,
      errorMessage: outErrorMessage.value != nullptr
          ? outErrorMessage.value.toDartString()
          : null,
    );

    if (outErrorMessage.value != nullptr) {
      _bindings.llamafuFreeString(outErrorMessage.value);
    }
    malloc.free(outIsValid);
    malloc.free(outErrorMessage);

    return validationResult;
  }

  /// Applies a chat template to messages.
  String applyChatTemplate(String template, List<String> messages, {bool addAssistant = true}) {
    final tmplPtr = template.toNativeUtf8();
    final messagesArray = malloc<Pointer<Utf8>>(messages.length);

    for (int i = 0; i < messages.length; i++) {
      messagesArray[i] = messages[i].toNativeUtf8();
    }

    final outFormatted = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuChatApplyTemplate(
      _llamafuInstance, tmplPtr, messagesArray, messages.length, addAssistant, outFormatted);

    malloc.free(tmplPtr);
    for (int i = 0; i < messages.length; i++) {
      malloc.free(messagesArray[i]);
    }
    malloc.free(messagesArray);

    if (result != 0) {
      malloc.free(outFormatted);
      throw Exception('Failed to apply chat template: $result');
    }

    final formatted = outFormatted.value.toDartString();
    _bindings.llamafuFreeString(outFormatted.value);
    malloc.free(outFormatted);

    return formatted;
  }

  /// Gets system information.
  String getSystemInfo() {
    final info = _bindings.llamafuPrintSystemInfo();
    return info.toDartString();
  }

  // ==========================================================================
  // CUSTOM SAMPLER CHAINS
  // ==========================================================================

  /// Creates a new sampler chain.
  SamplerChain createSamplerChain() {
    final chain = _bindings.llamafuSamplerChainInit();
    return SamplerChain._(_bindings, chain, _llamafuInstance);
  }

  /// Creates a greedy sampler.
  Sampler createGreedySampler() {
    final sampler = _bindings.llamafuSamplerInitGreedy();
    return Sampler._(_bindings, sampler);
  }

  /// Creates a distribution sampler with the given seed.
  Sampler createDistSampler(int seed) {
    final sampler = _bindings.llamafuSamplerInitDist(seed);
    return Sampler._(_bindings, sampler);
  }

  /// Creates a top-k sampler.
  Sampler createTopKSampler(int k) {
    final sampler = _bindings.llamafuSamplerInitTopK(k);
    return Sampler._(_bindings, sampler);
  }

  /// Creates a top-p (nucleus) sampler.
  Sampler createTopPSampler(double p, {int minKeep = 1}) {
    final sampler = _bindings.llamafuSamplerInitTopP(p, minKeep);
    return Sampler._(_bindings, sampler);
  }

  /// Creates a min-p sampler.
  Sampler createMinPSampler(double p, {int minKeep = 1}) {
    final sampler = _bindings.llamafuSamplerInitMinP(p, minKeep);
    return Sampler._(_bindings, sampler);
  }

  /// Creates a temperature sampler.
  Sampler createTempSampler(double temperature) {
    final sampler = _bindings.llamafuSamplerInitTemp(temperature);
    return Sampler._(_bindings, sampler);
  }

  // ==========================================================================
  // BATCH PROCESSING
  // ==========================================================================

  /// Creates a new batch for token processing.
  Batch createBatch({int nTokensMax = 512, int embd = 0, int nSeqMax = 1}) {
    final batch = _bindings.llamafuBatchInit(nTokensMax, embd, nSeqMax);
    return Batch._(_bindings, batch, _llamafuInstance);
  }

  // ==========================================================================
  // LOGITS ACCESS
  // ==========================================================================

  /// Gets the logits for the last token.
  Float32List getLogits() {
    final logitsPtr = _bindings.llamafuGetLogits(_llamafuInstance);
    if (logitsPtr == nullptr) {
      throw Exception('Failed to get logits');
    }
    // Get vocab size from model info to know array length
    final info = getModelInfo();
    final logits = Float32List(info.vocabSize);
    for (int i = 0; i < info.vocabSize; i++) {
      logits[i] = logitsPtr[i];
    }
    return logits;
  }

  /// Gets the logits for a specific token index.
  Float32List getLogitsAt(int index) {
    final logitsPtr = _bindings.llamafuGetLogitsIth(_llamafuInstance, index);
    if (logitsPtr == nullptr) {
      throw Exception('Failed to get logits at index $index');
    }
    final info = getModelInfo();
    final logits = Float32List(info.vocabSize);
    for (int i = 0; i < info.vocabSize; i++) {
      logits[i] = logitsPtr[i];
    }
    return logits;
  }

  // ==========================================================================
  // CHAT SESSION MANAGEMENT
  // ==========================================================================

  /// Creates a new chat session with an optional system prompt.
  ChatSession createChatSession({String? systemPrompt}) {
    final systemPromptPtr = systemPrompt?.toNativeUtf8() ?? nullptr;
    final outSession = malloc<Pointer<Void>>();

    final result = _bindings.llamafuChatSessionCreate(
      _llamafuInstance, systemPromptPtr, outSession);

    if (systemPrompt != null) malloc.free(systemPromptPtr);

    if (result != 0) {
      malloc.free(outSession);
      throw Exception('Failed to create chat session: $result');
    }

    final session = ChatSession._(_bindings, outSession.value);
    malloc.free(outSession);
    return session;
  }

  // ==========================================================================
  // IMAGE PROCESSING UTILITIES
  // ==========================================================================

  /// Validates an image input.
  ImageValidationResult validateImage(MediaInput input) {
    final inputStruct = malloc<LlamafuMediaInput>();
    inputStruct.ref.type = input.type.index;
    inputStruct.ref.data = input.data.toNativeUtf8();
    inputStruct.ref.data_size = input.data.length;

    final outValidation = malloc<LlamafuImageValidationStruct>();

    final result = _bindings.llamafuImageValidate(inputStruct, outValidation);

    malloc.free(inputStruct.ref.data);
    malloc.free(inputStruct);

    if (result != 0) {
      malloc.free(outValidation);
      throw Exception('Failed to validate image: $result');
    }

    final validationResult = ImageValidationResult(
      isValid: outValidation.ref.is_valid,
      detectedFormat: ImageFormat.values[outValidation.ref.detected_format],
      width: outValidation.ref.width,
      height: outValidation.ref.height,
      fileSizeBytes: outValidation.ref.file_size_bytes,
      supportedByModel: outValidation.ref.supported_by_model,
      requiresPreprocessing: outValidation.ref.requires_preprocessing,
    );

    malloc.free(outValidation);
    return validationResult;
  }

  /// Processes an image and returns embeddings.
  ImageProcessResult processImage(MediaInput input) {
    final inputStruct = malloc<LlamafuMediaInput>();
    inputStruct.ref.type = input.type.index;
    inputStruct.ref.data = input.data.toNativeUtf8();
    inputStruct.ref.data_size = input.data.length;

    final outResult = malloc<LlamafuImageProcessResultStruct>();

    final result = _bindings.llamafuImageProcess(_llamafuInstance, inputStruct, outResult);

    malloc.free(inputStruct.ref.data);
    malloc.free(inputStruct);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to process image: $result');
    }

    final nEmbeddings = outResult.ref.n_embeddings;
    final embeddings = Float32List(nEmbeddings);
    for (int i = 0; i < nEmbeddings; i++) {
      embeddings[i] = outResult.ref.embeddings[i];
    }

    final processResult = ImageProcessResult(
      embeddings: embeddings,
      nTokens: outResult.ref.n_tokens,
      processedWidth: outResult.ref.processed_width,
      processedHeight: outResult.ref.processed_height,
      wasResized: outResult.ref.was_resized,
      wasPadded: outResult.ref.was_padded,
      processingTimeMs: outResult.ref.processing_time_ms,
    );

    malloc.free(outResult);
    return processResult;
  }

  /// Converts an image to base64 encoding.
  String imageToBase64(MediaInput input, {ImageFormat format = ImageFormat.png}) {
    final inputStruct = malloc<LlamafuMediaInput>();
    inputStruct.ref.type = input.type.index;
    inputStruct.ref.data = input.data.toNativeUtf8();
    inputStruct.ref.data_size = input.data.length;

    final outBase64 = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuImageToBase64(inputStruct, format.index, outBase64);

    malloc.free(inputStruct.ref.data);
    malloc.free(inputStruct);

    if (result != 0) {
      malloc.free(outBase64);
      throw Exception('Failed to convert image to base64: $result');
    }

    final base64 = outBase64.value.toDartString();
    _bindings.llamafuFreeString(outBase64.value);
    malloc.free(outBase64);

    return base64;
  }

  // ==========================================================================
  // AUDIO PROCESSING UTILITIES
  // ==========================================================================

  /// Processes audio and returns features.
  AudioProcessResult processAudio(MediaInput input) {
    final inputStruct = malloc<LlamafuMediaInput>();
    inputStruct.ref.type = input.type.index;
    inputStruct.ref.data = input.data.toNativeUtf8();
    inputStruct.ref.data_size = input.data.length;

    final outResult = malloc<LlamafuAudioProcessResultStruct>();

    final result = _bindings.llamafuAudioProcess(_llamafuInstance, inputStruct, outResult);

    malloc.free(inputStruct.ref.data);
    malloc.free(inputStruct);

    if (result != 0) {
      malloc.free(outResult);
      throw Exception('Failed to process audio: $result');
    }

    final nFeatures = outResult.ref.n_features;
    final features = Float32List(nFeatures);
    for (int i = 0; i < nFeatures; i++) {
      features[i] = outResult.ref.audio_features[i];
    }

    final processResult = AudioProcessResult(
      audioFeatures: features,
      nFrames: outResult.ref.n_frames,
      processedSampleRate: outResult.ref.processed_sample_rate,
      processedChannels: outResult.ref.processed_channels,
      processedDurationMs: outResult.ref.processed_duration_ms,
      wasResampled: outResult.ref.was_resampled,
      wasNormalized: outResult.ref.was_normalized,
      processingTimeMs: outResult.ref.processing_time_ms,
    );

    malloc.free(outResult);
    return processResult;
  }

  /// Resamples audio to a target sample rate.
  Float32List resampleAudio(Float32List samples, int inputRate, int targetRate) {
    final inputPtr = malloc<Float>(samples.length);
    for (int i = 0; i < samples.length; i++) {
      inputPtr[i] = samples[i];
    }

    final outSamples = malloc<Pointer<Float>>();
    final outNSamples = malloc<IntPtr>();

    final result = _bindings.llamafuAudioResample(
      inputPtr, samples.length, inputRate, targetRate, outSamples, outNSamples);

    malloc.free(inputPtr);

    if (result != 0) {
      malloc.free(outSamples);
      malloc.free(outNSamples);
      throw Exception('Failed to resample audio: $result');
    }

    final nSamples = outNSamples.value;
    final resampled = Float32List(nSamples);
    for (int i = 0; i < nSamples; i++) {
      resampled[i] = outSamples.value[i];
    }

    _bindings.llamafuFreeEmbeddings(outSamples.value);
    malloc.free(outSamples);
    malloc.free(outNSamples);

    return resampled;
  }

  // ==========================================================================
  // ENHANCED LORA MANAGEMENT
  // ==========================================================================

  /// Gets information about a LoRA adapter.
  LoraAdapterInfo getLoraAdapterInfo(LoraAdapter adapter) {
    final outInfo = malloc<LlamafuLoraAdapterInfoStruct>();

    final result = _bindings.llamafuGetLoraAdapterInfo(
      _llamafuInstance, adapter._nativeAdapter, outInfo);

    if (result != 0) {
      malloc.free(outInfo);
      throw Exception('Failed to get LoRA adapter info: $result');
    }

    final info = LoraAdapterInfo(
      name: outInfo.ref.name != nullptr ? outInfo.ref.name.toDartString() : '',
      filePath: outInfo.ref.file_path != nullptr ? outInfo.ref.file_path.toDartString() : '',
      scale: outInfo.ref.scale,
      isActive: outInfo.ref.is_active,
    );

    malloc.free(outInfo);
    return info;
  }

  /// Validates LoRA adapter compatibility with the current model.
  LoraCompatibilityResult validateLoraCompatibility(String loraPath) {
    if (!_isValidFilePath(loraPath)) {
      throw ArgumentError('Invalid LoRA path: $loraPath');
    }

    final pathPtr = loraPath.toNativeUtf8();
    final outIsCompatible = malloc<Bool>();
    final outErrorMessage = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuValidateLoraCompatibility(
      _llamafuInstance, pathPtr, outIsCompatible, outErrorMessage);

    malloc.free(pathPtr);

    if (result != 0) {
      malloc.free(outIsCompatible);
      malloc.free(outErrorMessage);
      throw Exception('Failed to validate LoRA compatibility: $result');
    }

    final compatResult = LoraCompatibilityResult(
      isCompatible: outIsCompatible.value,
      errorMessage: outErrorMessage.value != nullptr
          ? outErrorMessage.value.toDartString()
          : null,
    );

    if (outErrorMessage.value != nullptr) {
      _bindings.llamafuFreeString(outErrorMessage.value);
    }
    malloc.free(outIsCompatible);
    malloc.free(outErrorMessage);

    return compatResult;
  }

  /// Cleans up resources and frees memory used by the Llamafu instance.
  ///
  /// This method should be called when the Llamafu instance is no longer needed
  /// to prevent memory leaks.
  void close() {
    // Free all LoRA adapters
    for (final adapter in _loraAdapters) {
      _bindings.llamafuLoraAdapterFree(adapter._nativeAdapter);
    }
    _loraAdapters.clear();
    
    // Free all grammar samplers
    for (final sampler in _grammarSamplers) {
      _bindings.llamafuGrammarSamplerFree(sampler._nativeSampler);
    }
    _grammarSamplers.clear();
    
    _bindings.llamafuFree(_llamafuInstance);
    malloc.free(_modelParams);
  }
}

/// Media input types for multi-modal inference.
enum MediaType {
  /// Text input type.
  text,

  /// Image input type.
  image,

  /// Audio input type.
  audio,

  /// Video input type (future support).
  video,
}

/// Represents a media input for multi-modal inference.
class MediaInput {
  /// The type of media input.
  final MediaType type;

  /// The data for the media input, either a file path or base64 encoded data.
  final String data;

  /// The source type of the data.
  final DataSource sourceType;

  /// Image format (for image inputs).
  final ImageFormat? format;

  /// Image width (for image inputs).
  final int? width;

  /// Image height (for image inputs).
  final int? height;

  /// Audio format (for audio inputs).
  final AudioFormat? audioFormat;

  /// Sample rate (for audio inputs).
  final int? sampleRate;

  /// Number of channels (for audio inputs).
  final int? channels;

  /// Duration in milliseconds (for audio inputs).
  final int? durationMs;

  /// Raw audio samples (for rawSamples source type).
  final Float32List? _samples;

  /// Creates a new media input.
  ///
  /// [type] is the type of media input.
  /// [data] is the data for the media input, either a file path or base64 encoded data.
  MediaInput({
    required this.type,
    required this.data,
    this.sourceType = DataSource.filePath,
    this.format,
    this.width,
    this.height,
    this.audioFormat,
    this.sampleRate,
    this.channels,
    this.durationMs,
  }) : _samples = null;

  MediaInput._internal({
    required this.type,
    required this.data,
    required this.sourceType,
    required this.format,
    required this.width,
    required this.height,
    required this.audioFormat,
    required this.sampleRate,
    required this.channels,
    required this.durationMs,
    required Float32List? samples,
  }) : _samples = samples;

  /// Creates a media input from raw audio samples.
  factory MediaInput.fromAudioSamples({
    required Float32List samples,
    required int sampleRate,
    required int channels,
  }) {
    return MediaInput._internal(
      type: MediaType.audio,
      data: '',
      sourceType: DataSource.rawSamples,
      format: null,
      width: null,
      height: null,
      audioFormat: AudioFormat.pcmFloat,
      sampleRate: sampleRate,
      channels: channels,
      durationMs: null,
      samples: samples,
    );
  }

  /// Gets the raw audio samples if available.
  Float32List? get samples => _samples;
}

/// Represents a LoRA adapter that can be applied to a Llamafu model.
class LoraAdapter {
  final LlamafuBindings _bindings;
  final Pointer<Void> _nativeAdapter;

  LoraAdapter._(this._bindings, this._nativeAdapter);

  void dispose() {
    _bindings.llamafuLoraAdapterFree(_nativeAdapter);
  }
}

/// Represents a grammar sampler for constrained generation.
class GrammarSampler {
  final LlamafuBindings _bindings;
  final Pointer<Void> _nativeSampler;

  GrammarSampler._(this._bindings, this._nativeSampler);

  void dispose() {
    _bindings.llamafuGrammarSamplerFree(_nativeSampler);
  }
}

// =============================================================================
// DATA CLASSES FOR API RETURN TYPES
// =============================================================================

/// Model information.
class ModelInfo {
  final int vocabSize;
  final int contextLength;
  final int embeddingSize;
  final int numLayers;
  final int numHeads;
  final int numKvHeads;
  final String name;
  final String architecture;
  final int numParams;
  final int sizeBytes;
  final bool supportsEmbeddings;
  final bool supportsMultimodal;

  const ModelInfo({
    required this.vocabSize,
    required this.contextLength,
    required this.embeddingSize,
    required this.numLayers,
    required this.numHeads,
    required this.numKvHeads,
    required this.name,
    required this.architecture,
    required this.numParams,
    required this.sizeBytes,
    required this.supportsEmbeddings,
    required this.supportsMultimodal,
  });
}

/// Performance statistics.
class PerfStats {
  final double startMs;
  final double endMs;
  final double loadMs;
  final double promptEvalMs;
  final double evalMs;
  final int promptTokens;
  final int evalTokens;

  const PerfStats({
    required this.startMs,
    required this.endMs,
    required this.loadMs,
    required this.promptEvalMs,
    required this.evalMs,
    required this.promptTokens,
    required this.evalTokens,
  });

  double get promptSpeedTps => promptTokens > 0 ? (promptTokens / promptEvalMs * 1000) : 0;
  double get evalSpeedTps => evalTokens > 0 ? (evalTokens / evalMs * 1000) : 0;
}

/// Memory usage statistics.
class MemoryUsage {
  final int modelSizeBytes;
  final int kvCacheSizeBytes;
  final int computeBufferSizeBytes;
  final int totalSizeBytes;

  const MemoryUsage({
    required this.modelSizeBytes,
    required this.kvCacheSizeBytes,
    required this.computeBufferSizeBytes,
    required this.totalSizeBytes,
  });

  double get modelSizeMb => modelSizeBytes / (1024 * 1024);
  double get kvCacheSizeMb => kvCacheSizeBytes / (1024 * 1024);
  double get totalSizeMb => totalSizeBytes / (1024 * 1024);
}

/// Benchmark result.
class BenchmarkResult {
  final int promptTokens;
  final double promptTimeMs;
  final int generationTokens;
  final double generationTimeMs;
  final double totalTimeMs;
  final double promptSpeedTps;
  final double generationSpeedTps;

  const BenchmarkResult({
    required this.promptTokens,
    required this.promptTimeMs,
    required this.generationTokens,
    required this.generationTimeMs,
    required this.totalTimeMs,
    required this.promptSpeedTps,
    required this.generationSpeedTps,
  });
}

/// Language detection result.
class LanguageDetection {
  final String languageCode;
  final double confidence;

  const LanguageDetection({
    required this.languageCode,
    required this.confidence,
  });
}

/// Sentiment analysis result.
class SentimentAnalysis {
  final double positive;
  final double negative;
  final double neutral;

  const SentimentAnalysis({
    required this.positive,
    required this.negative,
    required this.neutral,
  });

  String get dominantSentiment {
    if (positive >= negative && positive >= neutral) return 'positive';
    if (negative >= positive && negative >= neutral) return 'negative';
    return 'neutral';
  }
}

/// JSON validation result.
class JsonValidationResult {
  final bool isValid;
  final String? errorMessage;

  const JsonValidationResult({
    required this.isValid,
    this.errorMessage,
  });
}

// =============================================================================
// SAMPLER CLASSES
// =============================================================================

/// Represents a sampler for token selection.
class Sampler {
  final LlamafuBindings _bindings;
  final Pointer<Void> _nativeSampler;

  Sampler._(this._bindings, this._nativeSampler);

  /// Resets the sampler state.
  void reset() => _bindings.llamafuSamplerReset(_nativeSampler);

  /// Accepts a token, updating internal state.
  void accept(int token) => _bindings.llamafuSamplerAccept(_nativeSampler, token);

  /// Disposes of the sampler.
  void dispose() => _bindings.llamafuSamplerFree(_nativeSampler);
}

/// Represents a chain of samplers.
class SamplerChain {
  final LlamafuBindings _bindings;
  final Pointer<Void> _nativeChain;
  final Pointer<Void> _llamafuInstance;

  SamplerChain._(this._bindings, this._nativeChain, this._llamafuInstance);

  /// Adds a sampler to the chain.
  void add(Sampler sampler) {
    _bindings.llamafuSamplerChainAdd(_nativeChain, sampler._nativeSampler);
  }

  /// Samples a token using the chain.
  int sample(int idx) {
    return _bindings.llamafuSamplerSample(_nativeChain, _llamafuInstance, idx);
  }

  /// Resets the chain state.
  void reset() => _bindings.llamafuSamplerReset(_nativeChain);

  /// Accepts a token, updating internal state.
  void accept(int token) => _bindings.llamafuSamplerAccept(_nativeChain, token);

  /// Disposes of the chain.
  void dispose() => _bindings.llamafuSamplerFree(_nativeChain);
}

// =============================================================================
// BATCH CLASS
// =============================================================================

/// Represents a batch for token processing.
class Batch {
  final LlamafuBindings _bindings;
  final Pointer<Void> _nativeBatch;
  final Pointer<Void> _llamafuInstance;

  Batch._(this._bindings, this._nativeBatch, this._llamafuInstance);

  /// Clears the batch.
  void clear() => _bindings.llamafuBatchClear(_nativeBatch);

  /// Decodes the batch.
  void decode() {
    final result = _bindings.llamafuDecode(_llamafuInstance, _nativeBatch);
    if (result != 0) {
      throw Exception('Failed to decode batch: $result');
    }
  }

  /// Disposes of the batch.
  void dispose() => _bindings.llamafuBatchFree(_nativeBatch);
}

// =============================================================================
// CHAT SESSION CLASS
// =============================================================================

/// Represents a chat session with conversation history.
class ChatSession {
  final LlamafuBindings _bindings;
  final Pointer<Void> _nativeSession;

  ChatSession._(this._bindings, this._nativeSession);

  /// Sends a message and gets a response.
  String complete(String userMessage, {List<MediaInput>? mediaInputs}) {
    final messagePtr = userMessage.toNativeUtf8();
    final outResponse = malloc<Pointer<Utf8>>();

    Pointer<LlamafuMediaInput>? mediaArray;
    final nMedia = mediaInputs?.length ?? 0;

    if (mediaInputs != null && mediaInputs.isNotEmpty) {
      mediaArray = malloc<LlamafuMediaInput>(mediaInputs.length);
      for (int i = 0; i < mediaInputs.length; i++) {
        mediaArray[i].type = mediaInputs[i].type.index;
        mediaArray[i].data = mediaInputs[i].data.toNativeUtf8();
        mediaArray[i].data_size = mediaInputs[i].data.length;
      }
    }

    final result = _bindings.llamafuChatSessionComplete(
      _nativeSession, messagePtr, mediaArray ?? nullptr, nMedia, outResponse);

    malloc.free(messagePtr);
    if (mediaArray != null) {
      for (int i = 0; i < nMedia; i++) {
        malloc.free(mediaArray[i].data);
      }
      malloc.free(mediaArray);
    }

    if (result != 0) {
      malloc.free(outResponse);
      throw Exception('Failed to complete chat: $result');
    }

    final response = outResponse.value.toDartString();
    _bindings.llamafuFreeString(outResponse.value);
    malloc.free(outResponse);

    return response;
  }

  /// Gets the conversation history as JSON.
  String getHistory() {
    final outHistory = malloc<Pointer<Utf8>>();

    final result = _bindings.llamafuChatSessionGetHistory(_nativeSession, outHistory);

    if (result != 0) {
      malloc.free(outHistory);
      throw Exception('Failed to get chat history: $result');
    }

    final history = outHistory.value.toDartString();
    _bindings.llamafuFreeString(outHistory.value);
    malloc.free(outHistory);

    return history;
  }

  /// Disposes of the chat session.
  void dispose() => _bindings.llamafuChatSessionFree(_nativeSession);
}

// =============================================================================
// IMAGE/AUDIO RESULT CLASSES
// =============================================================================

/// Image validation result.
class ImageValidationResult {
  final bool isValid;
  final ImageFormat detectedFormat;
  final int width;
  final int height;
  final int fileSizeBytes;
  final bool supportedByModel;
  final bool requiresPreprocessing;

  const ImageValidationResult({
    required this.isValid,
    required this.detectedFormat,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    required this.supportedByModel,
    required this.requiresPreprocessing,
  });
}

/// Image processing result.
class ImageProcessResult {
  final Float32List embeddings;
  final int nTokens;
  final int processedWidth;
  final int processedHeight;
  final bool wasResized;
  final bool wasPadded;
  final double processingTimeMs;

  const ImageProcessResult({
    required this.embeddings,
    required this.nTokens,
    required this.processedWidth,
    required this.processedHeight,
    required this.wasResized,
    required this.wasPadded,
    required this.processingTimeMs,
  });
}

/// Audio processing result.
class AudioProcessResult {
  final Float32List audioFeatures;
  final int nFrames;
  final int processedSampleRate;
  final int processedChannels;
  final int processedDurationMs;
  final bool wasResampled;
  final bool wasNormalized;
  final double processingTimeMs;

  const AudioProcessResult({
    required this.audioFeatures,
    required this.nFrames,
    required this.processedSampleRate,
    required this.processedChannels,
    required this.processedDurationMs,
    required this.wasResampled,
    required this.wasNormalized,
    required this.processingTimeMs,
  });
}

/// LoRA compatibility result.
class LoraCompatibilityResult {
  final bool isCompatible;
  final String? errorMessage;

  const LoraCompatibilityResult({
    required this.isCompatible,
    this.errorMessage,
  });
}