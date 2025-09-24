# Model Guide

This guide covers model selection, optimization, and best practices for using different types of models with Llamafu.

## Model Types and Selection

### Text-Only Models

#### General Purpose Models

**Llama 2 & 3 Series**
- **Best for**: General conversation, reasoning, knowledge tasks
- **Sizes**: 7B, 13B, 70B parameters
- **Context**: 2048-8192 tokens
- **Memory**: 4-32GB RAM required
- **Use cases**: Chatbots, content generation, question answering

```dart
final llamafu = await Llamafu.init(
  modelPath: '/models/llama-2-7b-chat.Q4_K_M.gguf',
  contextSize: 4096,
  threads: 6,
);
```

**Mistral Series**
- **Best for**: Multilingual tasks, efficient inference
- **Sizes**: 7B, 8x7B (MoE) parameters
- **Context**: 8192-32768 tokens
- **Memory**: 4-16GB RAM required
- **Use cases**: Code assistance, multilingual chat, instruction following

```dart
final llamafu = await Llamafu.init(
  modelPath: '/models/mistral-7b-instruct-v0.2.Q4_K_M.gguf',
  contextSize: 8192,
  threads: 4,
);
```

**Qwen Series**
- **Best for**: Chinese-English bilingual tasks
- **Sizes**: 1.8B, 7B, 14B, 72B parameters
- **Context**: 8192-32768 tokens
- **Memory**: 2-32GB RAM required
- **Use cases**: Multilingual applications, Asian market deployment

#### Specialized Models

**Code Llama**
- **Best for**: Code generation and analysis
- **Sizes**: 7B, 13B, 34B parameters
- **Context**: 4096-16384 tokens
- **Languages**: Python, JavaScript, C++, Java, and more

```dart
final codeAssistant = await Llamafu.init(
  modelPath: '/models/codellama-13b-instruct.Q4_K_M.gguf',
  contextSize: 16384, // Larger context for code files
  threads: 8,
);

// Example: Code generation with constraints
const codeGrammar = '''
root ::= function_def
function_def ::= "def " identifier "(" params "):" "\\n" body
identifier ::= [a-zA-Z_][a-zA-Z0-9_]*
params ::= (identifier ("," identifier)*)?
body ::= ("    " line "\\n")+
line ::= [^\\n]*
''';

final result = await codeAssistant.completeWithGrammar(
  prompt: 'Create a Python function to calculate fibonacci numbers:',
  grammarStr: codeGrammar,
  grammarRoot: 'root',
  maxTokens: 200,
);
```

**Phi-3 Series**
- **Best for**: Efficient small-scale deployment
- **Sizes**: 3.8B, 7B, 14B parameters
- **Context**: 4096-131072 tokens
- **Memory**: 2-8GB RAM required
- **Use cases**: Mobile-first applications, edge deployment

### Multi-Modal Models

#### Vision-Language Models

**LLaVA (Large Language and Vision Assistant)**
- **Best for**: Image understanding and description
- **Sizes**: 7B, 13B, 34B parameters
- **Supported formats**: JPEG, PNG, BMP
- **Use cases**: Image captioning, visual question answering, document analysis

```dart
final visionModel = await Llamafu.init(
  modelPath: '/models/llava-v1.6-13b.Q4_K_M.gguf',
  mmprojPath: '/models/llava-v1.6-13b-mmproj-f16.gguf',
  contextSize: 4096,
  useGpu: true, // Enable GPU for vision processing
);

final analysis = await visionModel.multimodalComplete(
  prompt: 'Describe this image in detail, focusing on objects, colors, and composition:',
  mediaInputs: [
    MediaInput(type: MediaType.image, data: '/path/to/image.jpg'),
  ],
  maxTokens: 300,
  temperature: 0.7,
);
```

**Qwen2-VL**
- **Best for**: High-resolution image analysis
- **Sizes**: 2B, 7B, 72B parameters
- **Features**: Variable image resolution, video understanding
- **Use cases**: Document OCR, complex visual reasoning

**Moondream**
- **Best for**: Lightweight vision tasks
- **Size**: 1.7B parameters
- **Memory**: ~2GB RAM
- **Use cases**: Mobile vision applications, real-time image analysis

#### Audio-Language Models

**Qwen2-Audio**
- **Best for**: Speech and audio understanding
- **Sizes**: 7B parameters
- **Formats**: WAV, MP3, FLAC
- **Use cases**: Voice assistants, audio transcription, sound analysis

```dart
final audioModel = await Llamafu.init(
  modelPath: '/models/qwen2-audio-7b-instruct.Q4_K_M.gguf',
  mmprojPath: '/models/qwen2-audio-7b-instruct-mmproj.gguf',
  contextSize: 8192,
);

final transcription = await audioModel.multimodalComplete(
  prompt: 'Transcribe and summarize this audio:',
  mediaInputs: [
    MediaInput(type: MediaType.audio, data: '/path/to/audio.wav'),
  ],
  maxTokens: 500,
);
```

## Model Quantization

### Quantization Levels

**FP16 (16-bit floating point)**
- **Size**: Largest, highest quality
- **Memory**: Full model size
- **Use case**: When quality is paramount and memory is abundant

**Q8_0 (8-bit quantization)**
- **Size**: ~50% reduction
- **Quality**: Very high, minimal loss
- **Use case**: Good balance for desktop applications

**Q4_K_M (4-bit with K-quants, medium)**
- **Size**: ~75% reduction
- **Quality**: Good, recommended for most use cases
- **Use case**: Standard mobile deployment

```dart
// Recommended quantization for mobile
final llamafu = await Llamafu.init(
  modelPath: '/models/llama-2-7b-chat.Q4_K_M.gguf', // 4-bit quantized
  contextSize: 2048,
);
```

**Q2_K (2-bit quantization)**
- **Size**: ~90% reduction
- **Quality**: Lower, but usable for simple tasks
- **Use case**: Very memory-constrained environments

### Quantization Trade-offs

| Quantization | File Size | RAM Usage | Quality | Speed |
|--------------|-----------|-----------|---------|--------|
| FP16         | 100%      | 100%      | 100%    | Baseline |
| Q8_0         | ~55%      | ~60%      | 98%     | 10% faster |
| Q4_K_M       | ~40%      | ~45%      | 95%     | 20% faster |
| Q2_K         | ~25%      | ~30%      | 85%     | 30% faster |

## Mobile Optimization

### Device-Specific Configuration

**High-End Devices (8GB+ RAM)**
```dart
final llamafu = await Llamafu.init(
  modelPath: '/models/llama-2-13b-chat.Q4_K_M.gguf', // Larger model
  contextSize: 8192, // Larger context
  threads: Platform.numberOfProcessors, // Use all cores
);
```

**Mid-Range Devices (4-8GB RAM)**
```dart
final llamafu = await Llamafu.init(
  modelPath: '/models/llama-2-7b-chat.Q4_K_M.gguf',
  contextSize: 4096,
  threads: max(2, Platform.numberOfProcessors - 1), // Leave one core free
);
```

**Budget Devices (2-4GB RAM)**
```dart
final llamafu = await Llamafu.init(
  modelPath: '/models/phi-3-mini-4k-instruct.Q4_K_M.gguf', // Smaller model
  contextSize: 2048, // Smaller context
  threads: min(4, Platform.numberOfProcessors), // Conservative threading
);
```

### Memory Management Strategies

**Lazy Loading**
```dart
class LazyModelManager {
  Llamafu? _model;
  final String _modelPath;
  Timer? _unloadTimer;

  LazyModelManager(this._modelPath);

  Future<Llamafu> _getModel() async {
    if (_model == null) {
      _model = await Llamafu.init(modelPath: _modelPath);
    }

    // Reset unload timer
    _unloadTimer?.cancel();
    _unloadTimer = Timer(Duration(minutes: 5), _unloadModel);

    return _model!;
  }

  void _unloadModel() {
    _model?.close();
    _model = null;
  }

  Future<String> generate(String prompt) async {
    final model = await _getModel();
    return await model.complete(prompt: prompt);
  }
}
```

**Context Sliding Window**
```dart
class SlidingContextManager {
  final Llamafu llamafu;
  final int maxContext;
  final List<String> _history = [];
  int _currentTokens = 0;

  SlidingContextManager(this.llamafu, this.maxContext);

  Future<String> addMessage(String message) async {
    final tokens = await llamafu.tokenize(message);
    _currentTokens += tokens.length;

    // Slide window if needed
    while (_currentTokens > maxContext * 0.8 && _history.isNotEmpty) {
      final removed = _history.removeAt(0);
      final removedTokens = await llamafu.tokenize(removed);
      _currentTokens -= removedTokens.length;
    }

    _history.add(message);

    final context = _history.join('\n');
    return await llamafu.complete(prompt: context);
  }
}
```

## Performance Optimization

### Thread Configuration

```dart
class OptimalThreadCalculator {
  static int calculateThreads({
    required int availableCores,
    required int modelSize, // in GB
    required bool isBackground,
  }) {
    int baseThreads;

    // Base calculation on model size
    if (modelSize <= 4) {
      baseThreads = min(4, availableCores);
    } else if (modelSize <= 8) {
      baseThreads = min(6, availableCores);
    } else {
      baseThreads = min(8, availableCores);
    }

    // Adjust for background processing
    if (isBackground) {
      baseThreads = max(1, baseThreads - 1);
    }

    // Leave at least one core free for UI
    return min(baseThreads, availableCores - 1);
  }
}

// Usage
final optimalThreads = OptimalThreadCalculator.calculateThreads(
  availableCores: Platform.numberOfProcessors,
  modelSize: 7, // 7B parameter model
  isBackground: true,
);
```

### Batch Processing

```dart
class BatchProcessor {
  final Llamafu llamafu;
  final Queue<BatchRequest> _queue = Queue();
  bool _processing = false;

  BatchProcessor(this.llamafu);

  Future<String> process(String prompt) async {
    final completer = Completer<String>();
    _queue.add(BatchRequest(prompt, completer));

    if (!_processing) {
      _processBatch();
    }

    return completer.future;
  }

  Future<void> _processBatch() async {
    _processing = true;

    while (_queue.isNotEmpty) {
      final batch = _queue.removeFirst();
      try {
        final result = await llamafu.complete(prompt: batch.prompt);
        batch.completer.complete(result);
      } catch (e) {
        batch.completer.completeError(e);
      }
    }

    _processing = false;
  }
}

class BatchRequest {
  final String prompt;
  final Completer<String> completer;

  BatchRequest(this.prompt, this.completer);
}
```

## Model Deployment

### Asset Bundling

**For small models (< 100MB):**
```yaml
flutter:
  assets:
    - assets/models/phi-3-mini.Q4_K_M.gguf
```

**For large models:**
Use external storage or download on first run:

```dart
class ModelDownloader {
  static Future<String> downloadModel({
    required String modelName,
    required String downloadUrl,
  }) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final modelPath = '${documentsDir.path}/models/$modelName';
    final modelFile = File(modelPath);

    if (await modelFile.exists()) {
      return modelPath; // Already downloaded
    }

    await Directory('${documentsDir.path}/models').create(recursive: true);

    final response = await HttpClient().getUrl(Uri.parse(downloadUrl));
    final downloadResponse = await response.close();

    final sink = modelFile.openWrite();
    await downloadResponse.pipe(sink);

    return modelPath;
  }
}

// Usage
final modelPath = await ModelDownloader.downloadModel(
  modelName: 'llama-2-7b-chat.Q4_K_M.gguf',
  downloadUrl: 'https://huggingface.co/models/...',
);
```

### Model Validation

```dart
class ModelValidator {
  static Future<bool> validateModel(String modelPath) async {
    try {
      final file = File(modelPath);
      if (!await file.exists()) return false;

      final stat = await file.stat();
      if (stat.size < 1024) return false; // Too small to be valid

      // Try to initialize (quick validation)
      final llamafu = await Llamafu.init(
        modelPath: modelPath,
        contextSize: 128, // Minimal context for validation
        threads: 1,
      );

      // Try a simple generation
      await llamafu.complete(
        prompt: 'Test',
        maxTokens: 1,
      );

      llamafu.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

## Sampling Strategies

### Creative Writing
```dart
final creativeResult = await llamafu.complete(
  prompt: 'Write a creative story about space exploration:',
  maxTokens: 300,
  temperature: 0.9,    // High creativity
  topP: 0.95,         // Allow diverse vocabulary
  repeatPenalty: 1.1, // Reduce repetition
);
```

### Factual Q&A
```dart
final factualResult = await llamafu.complete(
  prompt: 'What is the capital of Japan?',
  maxTokens: 50,
  temperature: 0.1,    // Low creativity, more factual
  topK: 10,           // Focus on most likely answers
  repeatPenalty: 1.05, // Minimal repetition penalty
);
```

### Code Generation
```dart
final codeResult = await llamafu.complete(
  prompt: 'Write a Python function to sort a list:',
  maxTokens: 150,
  temperature: 0.3,    // Some creativity but structured
  topK: 40,           // Reasonable vocabulary
  repeatPenalty: 1.15, // Discourage repetitive code patterns
  seed: 42,           // Reproducible for testing
);
```

### Conversational Chat
```dart
final chatResult = await llamafu.complete(
  prompt: chatPrompt,
  maxTokens: 200,
  temperature: 0.7,    // Balanced creativity
  topP: 0.9,          // Natural language flow
  repeatPenalty: 1.1, // Avoid repetitive responses
);
```

## Troubleshooting

### Common Issues

**Out of Memory Errors**
```dart
// Solution: Use smaller model or reduce context
try {
  final llamafu = await Llamafu.init(
    modelPath: modelPath,
    contextSize: 1024, // Reduce context
  );
} on LlamafuException catch (e) {
  if (e.code == LlamafuErrorCode.outOfMemory) {
    // Fallback to even smaller configuration
    final llamafu = await Llamafu.init(
      modelPath: smallerModelPath,
      contextSize: 512,
    );
  }
}
```

**Slow Inference**
```dart
// Check thread configuration
final deviceInfo = DeviceInfoPlugin();
final androidInfo = await deviceInfo.androidInfo;

final threads = androidInfo.version.sdkInt >= 24
    ? Platform.numberOfProcessors
    : max(2, Platform.numberOfProcessors - 1);

final llamafu = await Llamafu.init(
  modelPath: modelPath,
  threads: threads,
);
```

**Model Loading Failures**
```dart
Future<Llamafu> loadModelWithRetry(String modelPath) async {
  const maxRetries = 3;

  for (int i = 0; i < maxRetries; i++) {
    try {
      return await Llamafu.init(modelPath: modelPath);
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: 1 << i)); // Exponential backoff
    }
  }

  throw StateError('Failed to load model after $maxRetries attempts');
}
```

### Performance Monitoring

```dart
class ModelPerformanceMonitor {
  final Stopwatch _stopwatch = Stopwatch();
  final List<int> _inferenceTimes = [];

  Future<String> timedGeneration(Llamafu llamafu, String prompt) async {
    _stopwatch.reset();
    _stopwatch.start();

    final result = await llamafu.complete(prompt: prompt);

    _stopwatch.stop();
    _inferenceTimes.add(_stopwatch.elapsedMilliseconds);

    return result;
  }

  double get averageInferenceTime {
    if (_inferenceTimes.isEmpty) return 0;
    return _inferenceTimes.reduce((a, b) => a + b) / _inferenceTimes.length;
  }

  Map<String, dynamic> getStats() {
    return {
      'total_inferences': _inferenceTimes.length,
      'average_time_ms': averageInferenceTime,
      'min_time_ms': _inferenceTimes.isNotEmpty ? _inferenceTimes.reduce(min) : 0,
      'max_time_ms': _inferenceTimes.isNotEmpty ? _inferenceTimes.reduce(max) : 0,
    };
  }
}
```