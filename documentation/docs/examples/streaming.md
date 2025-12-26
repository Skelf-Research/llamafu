# Example: Streaming Output

Real-time token streaming for responsive user interfaces.

## Overview

This example demonstrates:
- Streaming text generation
- Progress indication
- Cancellation handling
- Token counting

## Basic Streaming

### Simple Stream

```dart
await for (final token in llamafu.completeStream(
  'Tell me a story about a robot:',
  maxTokens: 200,
)) {
  stdout.write(token);  // Print each token immediately
}
```

### Flutter Widget Integration

```dart
class StreamingText extends StatefulWidget {
  final Llamafu llamafu;
  final String prompt;

  const StreamingText({
    super.key,
    required this.llamafu,
    required this.prompt,
  });

  @override
  State<StreamingText> createState() => _StreamingTextState();
}

class _StreamingTextState extends State<StreamingText> {
  String _text = '';
  bool _isStreaming = false;
  int _tokenCount = 0;

  Future<void> _startStreaming() async {
    setState(() {
      _text = '';
      _isStreaming = true;
      _tokenCount = 0;
    });

    await for (final token in widget.llamafu.completeStream(
      widget.prompt,
      maxTokens: 200,
    )) {
      setState(() {
        _text += token;
        _tokenCount++;
      });
    }

    setState(() => _isStreaming = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: _isStreaming ? null : _startStreaming,
          child: Text(_isStreaming ? 'Generating...' : 'Generate'),
        ),
        const SizedBox(height: 16),
        Text('Tokens: $_tokenCount'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _text.isEmpty ? 'Output will appear here...' : _text,
          ),
        ),
      ],
    );
  }
}
```

## With Cancellation

```dart
class CancellableStream extends StatefulWidget {
  final Llamafu llamafu;

  const CancellableStream({super.key, required this.llamafu});

  @override
  State<CancellableStream> createState() => _CancellableStreamState();
}

class _CancellableStreamState extends State<CancellableStream> {
  String _output = '';
  bool _isGenerating = false;
  bool _shouldCancel = false;

  @override
  void initState() {
    super.initState();
    // Set up abort callback
    widget.llamafu.setAbortCallback(() => _shouldCancel);
  }

  Future<void> _generate() async {
    setState(() {
      _output = '';
      _isGenerating = true;
      _shouldCancel = false;
    });

    try {
      await for (final token in widget.llamafu.completeStream(
        'Write a long story:',
        maxTokens: 500,
      )) {
        if (_shouldCancel) break;
        setState(() => _output += token);
      }
    } catch (e) {
      if (!_shouldCancel) {
        // Real error, not cancellation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _cancel() {
    _shouldCancel = true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _isGenerating ? null : _generate,
              child: const Text('Generate'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _isGenerating ? _cancel : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Text(_output),
          ),
        ),
      ],
    );
  }
}
```

## With Progress Indicator

```dart
class StreamWithProgress extends StatefulWidget {
  final Llamafu llamafu;
  final int maxTokens;

  const StreamWithProgress({
    super.key,
    required this.llamafu,
    this.maxTokens = 200,
  });

  @override
  State<StreamWithProgress> createState() => _StreamWithProgressState();
}

class _StreamWithProgressState extends State<StreamWithProgress> {
  String _output = '';
  int _generatedTokens = 0;
  bool _isGenerating = false;
  Duration _elapsed = Duration.zero;
  final _stopwatch = Stopwatch();

  Future<void> _generate() async {
    setState(() {
      _output = '';
      _generatedTokens = 0;
      _isGenerating = true;
    });

    _stopwatch.reset();
    _stopwatch.start();

    await for (final token in widget.llamafu.completeStream(
      'Write about artificial intelligence:',
      maxTokens: widget.maxTokens,
    )) {
      setState(() {
        _output += token;
        _generatedTokens++;
        _elapsed = _stopwatch.elapsed;
      });
    }

    _stopwatch.stop();
    setState(() => _isGenerating = false);
  }

  double get _progress => _generatedTokens / widget.maxTokens;
  double get _tokensPerSecond =>
      _elapsed.inMilliseconds > 0
          ? _generatedTokens / (_elapsed.inMilliseconds / 1000)
          : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isGenerating ? null : _generate,
          child: Text(_isGenerating ? 'Generating...' : 'Generate'),
        ),
        const SizedBox(height: 16),

        // Progress bar
        LinearProgressIndicator(value: _progress),
        const SizedBox(height: 8),

        // Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatChip(
              label: 'Tokens',
              value: '$_generatedTokens / ${widget.maxTokens}',
            ),
            _StatChip(
              label: 'Speed',
              value: '${_tokensPerSecond.toStringAsFixed(1)} tok/s',
            ),
            _StatChip(
              label: 'Time',
              value: '${_elapsed.inSeconds}s',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Output
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: Text(_output),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
```

## Typewriter Effect

```dart
class TypewriterText extends StatefulWidget {
  final Llamafu llamafu;
  final String prompt;
  final Duration charDelay;

  const TypewriterText({
    super.key,
    required this.llamafu,
    required this.prompt,
    this.charDelay = const Duration(milliseconds: 30),
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  String _fullText = '';
  bool _isGenerating = false;

  Future<void> _generate() async {
    setState(() {
      _displayedText = '';
      _fullText = '';
      _isGenerating = true;
    });

    // Collect tokens in background
    await for (final token in widget.llamafu.completeStream(
      widget.prompt,
      maxTokens: 200,
    )) {
      _fullText += token;
    }

    // Typewriter animation
    for (int i = 0; i < _fullText.length; i++) {
      await Future.delayed(widget.charDelay);
      setState(() {
        _displayedText = _fullText.substring(0, i + 1);
      });
    }

    setState(() => _isGenerating = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isGenerating ? null : _generate,
          child: const Text('Generate'),
        ),
        const SizedBox(height: 16),
        Text(
          _displayedText,
          style: const TextStyle(fontSize: 18),
        ),
        if (_isGenerating)
          const Text('|', style: TextStyle(fontSize: 18)),  // Cursor
      ],
    );
  }
}
```

## Best Practices

### 1. Update UI Efficiently

```dart
// Batch updates for better performance
int _updateCounter = 0;

await for (final token in llamafu.completeStream(prompt)) {
  _buffer += token;
  _updateCounter++;

  // Update UI every 5 tokens
  if (_updateCounter % 5 == 0) {
    setState(() {
      _output = _buffer;
    });
  }
}

// Final update
setState(() {
  _output = _buffer;
});
```

### 2. Handle Errors Gracefully

```dart
try {
  await for (final token in llamafu.completeStream(prompt)) {
    // ...
  }
} on LlamafuInferenceError catch (e) {
  if (e.code == ErrorCode.generationAborted) {
    // User cancelled - not an error
  } else {
    // Real error
    showError(e.message);
  }
}
```

### 3. Clean Up on Dispose

```dart
@override
void dispose() {
  _shouldCancel = true;  // Cancel any ongoing generation
  super.dispose();
}
```

### 4. Auto-Scroll

```dart
final _scrollController = ScrollController();

void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  });
}

// Call after each token
setState(() {
  _output += token;
});
_scrollToBottom();
```
