# High-Level APIs

Llamafu provides clean, intuitive high-level APIs for common use cases. These abstractions simplify working with chat, LoRA adapters, and multimodal inputs.

## Chat API

The Chat API provides a simple interface for multi-turn conversations with automatic history management.

### Basic Usage

```dart
import 'package:llamafu/llamafu.dart';

// Initialize model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/model.gguf',
  threads: 4,
  contextSize: 4096,
);

// Create chat with system prompt
final chat = Chat(llamafu, config: ChatConfig(
  systemPrompt: 'You are a helpful coding assistant.',
  maxHistory: 50,
  maxTokens: 512,
  temperature: 0.7,
));

// Send messages
final response = await chat.send('How do I sort an array in Dart?');
print(response);

// Follow-up (context is maintained)
final followUp = await chat.send('Can you show me a more efficient way?');
print(followUp);
```

### Streaming Responses

```dart
// Stream tokens as they're generated
final stream = chat.sendStream('Write a short story');

await for (final token in stream) {
  stdout.write(token);
}
```

### History Management

```dart
// Get conversation history
for (final msg in chat.history) {
  print('${msg.role}: ${msg.content}');
}

// Clear history (keeps system prompt)
chat.clear();

// Undo last exchange
chat.undoLast();

// Edit and regenerate
final newResponse = await chat.editLast('Updated question');

// Regenerate last response
final regenerated = await chat.regenerate();
```

### Export/Import

```dart
// Export to JSON
final json = chat.toJson();

// Import from JSON
chat.fromJson(savedHistory);
```

### Configuration Builder

```dart
final config = ChatConfigBuilder()
    .systemPrompt('You are a helpful assistant')
    .maxHistory(100)
    .maxTokens(1024)
    .temperature(0.8)
    .topP(0.9)
    .repeatPenalty(1.1)
    .build();

final chat = Chat(llamafu, config: config);
```

## LoRA API

The LoRA API provides clean adapter lifecycle management for model fine-tuning.

### Loading Adapters

```dart
// Create LoRA manager
final lora = Lora(llamafu);

// Load an adapter
final codeAdapter = await lora.load(
  'adapters/code-expert.gguf',
  name: 'Code Expert',
  description: 'Optimized for code generation',
);

// Load with auto-apply
final styleAdapter = await lora.load(
  'adapters/creative.gguf',
  autoApply: true,
  scale: 0.8,
);
```

### Applying Adapters

```dart
// Apply single adapter
await codeAdapter.apply(scale: 0.8);

// Adjust scale dynamically
await codeAdapter.setScale(0.5);

// Check status
print('Active: ${codeAdapter.isActive}');
print('Scale: ${codeAdapter.scale}');

// Remove
await codeAdapter.remove();
```

### Multiple Adapters

```dart
// Apply multiple adapters with different scales
await lora.applyMultiple([
  (codeAdapter, 0.6),
  (styleAdapter, 0.4),
]);

// List active adapters
for (final adapter in lora.active) {
  print('${adapter.name}: scale ${adapter.scale}');
}

// Remove all
await lora.removeAll();
```

### Adapter Management

```dart
// Find adapter by name
final adapter = lora.findByName('Code Expert');

// Check compatibility before loading
if (await lora.isCompatible('new-adapter.gguf')) {
  await lora.load('new-adapter.gguf');
}

// Get info for all adapters
for (final info in lora.getInfo()) {
  print('${info.name}: ${info.parameterCount} params');
}

// Unload specific adapter
await lora.unload(codeAdapter);

// Clear all adapters
await lora.clearAll();
```

### Complete Example

```dart
final lora = Lora(llamafu);

// Load adapters for different tasks
final code = await lora.load('code.gguf', name: 'Code');
final creative = await lora.load('creative.gguf', name: 'Creative');

// Use code adapter for programming tasks
await code.apply(scale: 0.9);
final codeResult = await llamafu.complete(
  prompt: 'Write a binary search function',
  maxTokens: 500,
);
await code.remove();

// Switch to creative for writing
await creative.apply(scale: 0.7);
final story = await llamafu.complete(
  prompt: 'Write a short story',
  maxTokens: 500,
);
await creative.remove();

// Clean up
await lora.clearAll();
```

## Multimodal API

The Multimodal API provides unified interfaces for vision, audio, and combined media processing.

### Vision API

```dart
// Create vision interface
final vision = Vision(llamafu, config: VisionConfig(
  maxTokens: 512,
  temperature: 0.7,
  useCache: true,
));

// Describe an image
final description = await vision.describe('photo.jpg');
print(description);

// Ask questions about an image
final answer = await vision.ask(
  'What breed is this dog?',
  image: 'dog.jpg',
);

// Extract text (OCR)
final text = await vision.extractText('document.png');

// Identify objects
final objects = await vision.identifyObjects('scene.jpg');

// Compare images
final comparison = await vision.compare([
  'before.jpg',
  'after.jpg',
], aspect: 'visual changes');

// Analyze for specific attributes
final analysis = await vision.analyze(
  'product.jpg',
  attributes: ['color', 'brand', 'condition'],
);
```

### Streaming Vision

```dart
// Stream description as it's generated
final stream = vision.describeStream('complex-image.jpg');

await for (final token in stream) {
  stdout.write(token);
}
```

### Audio API

```dart
// Create audio interface
final audio = Audio(llamafu, config: AudioConfig(
  maxTokens: 512,
  sampleRate: 16000,
  autoResample: true,
));

// Transcribe audio
final transcript = await audio.transcribe('recording.wav');

// Analyze audio
final analysis = await audio.analyze(
  'speech.mp3',
  focus: 'speaker emotion and tone',
);

// Summarize
final summary = await audio.summarize('lecture.wav');

// Ask questions
final answer = await audio.ask(
  'What is the main topic discussed?',
  audio: 'podcast.mp3',
);
```

### Combined Multimodal

```dart
// Create multimodal interface
final multimodal = Multimodal(llamafu, maxTokens: 1024);

// Combine text with images
final result = await multimodal.complete(
  prompt: 'Compare these product photos and recommend the better option',
  media: [
    Media.image('product1.jpg'),
    Media.image('product2.jpg'),
  ],
);

// Mix images and audio
final analysis = await multimodal.complete(
  prompt: 'Describe the relationship between the image and audio',
  media: [
    Media.image('diagram.png'),
    Media.audio('explanation.wav'),
  ],
);

// Analyze multiple sources
final combined = await multimodal.analyze(
  media: [
    Media.image('chart.png'),
    Media.image('graph.png'),
    Media.audio('narration.mp3'),
  ],
  focus: 'data trends and insights',
);
```

### Multimodal Builder

```dart
// Fluent builder pattern
final result = await MultimodalBuilder(llamafu)
    .prompt('Analyze these items and provide a summary')
    .addImage('photo1.jpg')
    .addImage('photo2.jpg')
    .addAudio('context.wav')
    .maxTokens(1024)
    .temperature(0.7)
    .execute();

// Or stream
final stream = MultimodalBuilder(llamafu)
    .prompt('Describe in detail')
    .addImage('complex-scene.jpg')
    .maxTokens(2048)
    .stream();

await for (final token in stream) {
  stdout.write(token);
}
```

### Media Input Types

```dart
// From file path
final image = Media.image('photo.jpg');
final audio = Media.audio('sound.wav');

// From base64
final imageB64 = Media.base64(base64String, type: MediaType.image);

// From bytes
final imageBytes = Media.bytes(uint8List, type: MediaType.image);

// With caption
final captioned = Media.image('photo.jpg', caption: 'User uploaded photo');

// Auto-detect type from extension
final auto = Media.file('document.png'); // Detected as image
```

## Best Practices

### Chat

1. **Set appropriate context size** - Match to conversation length needs
2. **Use system prompts** - Guide model behavior consistently
3. **Manage history** - Clear or trim for long conversations
4. **Handle errors** - Wrap in try-catch for robustness

### LoRA

1. **Scale appropriately** - Sum of scales should be <= 1.0 for multiple adapters
2. **Load once, apply many** - Reuse loaded adapters
3. **Clean up** - Always call clearAll() when done
4. **Test compatibility** - Validate adapters before loading

### Multimodal

1. **Use appropriate models** - Ensure model supports vision/audio
2. **Optimize images** - Resize large images before processing
3. **Batch when possible** - Process multiple images together
4. **Cache results** - Enable caching for repeated analysis

## Complete Application Example

```dart
import 'package:llamafu/llamafu.dart';

Future<void> main() async {
  // Initialize with vision support
  final llamafu = await Llamafu.init(
    modelPath: 'model.gguf',
    mmprojPath: 'mmproj.gguf',
    threads: 4,
    contextSize: 4096,
  );

  // Setup APIs
  final chat = Chat(llamafu, config: ChatConfig(
    systemPrompt: 'You are a helpful visual assistant.',
  ));
  final lora = Lora(llamafu);
  final vision = Vision(llamafu);

  // Load specialized adapter
  final photoAdapter = await lora.load('photo-analysis.gguf');
  await photoAdapter.apply(scale: 0.8);

  // Analyze image
  final description = await vision.describe('user-photo.jpg');

  // Chat about it
  await chat.send('I uploaded a photo. Here\'s what I see: $description');
  final response = await chat.send('What can you tell me about this?');
  print(response);

  // Clean up
  await lora.clearAll();
  llamafu.close();
}
```

## Related Documentation

- [Getting Started](getting-started.md) - Basic setup
- [Tool Calling](tool-calling.md) - Function calling and JSON output
- [API Reference](api-reference.md) - Complete API documentation
- [Performance Guide](performance-guide.md) - Optimization tips
