# Quick Start

Get up and running with Llamafu in under 5 minutes.

## Step 1: Initialize the Model

```dart
import 'package:llamafu/llamafu.dart';

final llamafu = await Llamafu.init(
  modelPath: 'models/smollm-135m-instruct-q8_0.gguf',
  contextSize: 2048,
);
```

## Step 2: Generate Text

```dart
final response = await llamafu.complete(
  'What is the capital of France?',
  maxTokens: 100,
);

print(response);
// Output: The capital of France is Paris...
```

## Step 3: Clean Up

```dart
llamafu.dispose();
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Llamafu? _llamafu;
  String _response = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    _llamafu = await Llamafu.init(
      modelPath: 'assets/models/smollm-135m-instruct-q8_0.gguf',
      contextSize: 2048,
    );
    setState(() => _loading = false);
  }

  Future<void> _generate() async {
    if (_llamafu == null) return;

    setState(() => _loading = true);

    final response = await _llamafu!.complete(
      'Write a haiku about programming:',
      maxTokens: 50,
      temperature: 0.8,
    );

    setState(() {
      _response = response;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _llamafu?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Llamafu Demo')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: _loading ? null : _generate,
                child: Text(_loading ? 'Loading...' : 'Generate'),
              ),
              const SizedBox(height: 16),
              Text(_response),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Streaming Output

For real-time token output:

```dart
await for (final token in llamafu.completeStream(
  'Tell me a story:',
  maxTokens: 200,
)) {
  stdout.write(token); // Print each token as it arrives
}
```

## Using Chat Templates

For instruction-tuned models:

```dart
final messages = [
  'user: What is 2 + 2?',
  'assistant: 2 + 2 equals 4.',
  'user: And what is 4 + 4?',
];

final formatted = llamafu.applyChatTemplate('', messages);
final response = await llamafu.complete(formatted, maxTokens: 100);
```

## What's Next?

- [Basic Usage](basic-usage.md) - Understand core concepts
- [Text Generation](text-generation.md) - All generation options
- [Chat Sessions](chat-sessions.md) - Build conversational apps
- [Multimodal](multimodal.md) - Add vision and audio capabilities
