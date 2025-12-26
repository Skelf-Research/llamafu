# Example: Simple Chatbot

A complete Flutter chatbot application using Llamafu.

## Overview

This example demonstrates:
- Model initialization
- Chat session management
- Streaming responses
- UI integration

## Full Source Code

```dart
import 'package:flutter/material.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Llamafu Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Llamafu? _llamafu;
  final List<ChatMessage> _messages = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = true;
  bool _isGenerating = false;
  String _currentResponse = '';

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      _llamafu = await Llamafu.init(
        modelPath: 'assets/models/smollm-135m-instruct-q8_0.gguf',
        contextSize: 2048,
        threads: 4,
      );
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load model: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _llamafu == null || _isGenerating) return;

    _textController.clear();

    // Add user message
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isGenerating = true;
      _currentResponse = '';
    });

    _scrollToBottom();

    try {
      // Format conversation for the model
      final prompt = _formatPrompt();

      // Stream the response
      await for (final token in _llamafu!.completeStream(
        prompt,
        maxTokens: 256,
        temperature: 0.7,
      )) {
        setState(() {
          _currentResponse += token;
        });
        _scrollToBottom();
      }

      // Add assistant message
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: _currentResponse,
        ));
        _currentResponse = '';
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      _showError('Generation failed: $e');
    }
  }

  String _formatPrompt() {
    final buffer = StringBuffer();

    // System prompt
    buffer.writeln('<|im_start|>system');
    buffer.writeln('You are a helpful assistant.<|im_end|>');

    // Conversation history (last 10 messages)
    final recentMessages = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;

    for (final msg in recentMessages) {
      buffer.writeln('<|im_start|>${msg.role}');
      buffer.writeln('${msg.content}<|im_end|>');
    }

    // Prompt for assistant response
    buffer.write('<|im_start|>assistant\n');

    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
    });
    _llamafu?.clearKvCache();
  }

  @override
  void dispose() {
    _llamafu?.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Llamafu Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearChat,
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildMessageList()),
                if (_isGenerating && _currentResponse.isNotEmpty)
                  _buildTypingIndicator(),
                _buildInputArea(),
              ],
            ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _MessageBubble(message: message);
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          _currentResponse,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isGenerating,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(_isGenerating ? Icons.stop : Icons.send),
            onPressed: _isGenerating ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? Theme.of(context).colorScheme.primary
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: message.isUser ? Colors.white : Colors.black,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
```

## Key Concepts

### Model Initialization

```dart
_llamafu = await Llamafu.init(
  modelPath: 'assets/models/model.gguf',
  contextSize: 2048,
  threads: 4,
);
```

### Streaming Responses

```dart
await for (final token in _llamafu!.completeStream(prompt)) {
  setState(() {
    _currentResponse += token;
  });
}
```

### Context Management

```dart
// Keep only recent messages to fit in context
final recentMessages = _messages.length > 10
    ? _messages.sublist(_messages.length - 10)
    : _messages;
```

### Chat Template

```dart
// ChatML format (adjust for your model)
'<|im_start|>user\n$message<|im_end|>\n<|im_start|>assistant\n'
```

## Customization

### Different Models

Change the model path and adjust the chat template:

```dart
// For Llama 3
String _formatPromptLlama3() {
  return '''<|begin_of_text|><|start_header_id|>system<|end_header_id|>
You are a helpful assistant.<|eot_id|>
<|start_header_id|>user<|end_header_id|>
$userMessage<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>
''';
}
```

### Abort Handling

```dart
bool _shouldAbort = false;

_llamafu.setAbortCallback(() => _shouldAbort);

// Stop button
IconButton(
  icon: const Icon(Icons.stop),
  onPressed: () => _shouldAbort = true,
)
```

### Persistence

Save and restore chat history:

```dart
Future<void> _saveHistory() async {
  final json = jsonEncode(_messages.map((m) => {
    'role': m.role,
    'content': m.content,
  }).toList());
  await File('chat_history.json').writeAsString(json);
}
```
