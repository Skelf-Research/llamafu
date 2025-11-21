import 'dart:async';

/// Role of a message in a chat conversation.
enum Role {
  system,
  user,
  assistant,
}

/// A message in a chat conversation.
class ChatMessage {
  /// Role of the message sender.
  final Role role;

  /// Content of the message.
  final String content;

  /// Timestamp when message was created.
  final DateTime timestamp;

  /// Optional metadata.
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a system message.
  factory ChatMessage.system(String content) => ChatMessage(
        role: Role.system,
        content: content,
      );

  /// Create a user message.
  factory ChatMessage.user(String content) => ChatMessage(
        role: Role.user,
        content: content,
      );

  /// Create an assistant message.
  factory ChatMessage.assistant(String content) => ChatMessage(
        role: Role.assistant,
        content: content,
      );

  Map<String, dynamic> toJson() => {
        'role': role.name,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  @override
  String toString() => '${role.name}: $content';
}

/// Configuration for chat behavior.
class ChatConfig {
  /// System prompt to set assistant behavior.
  final String? systemPrompt;

  /// Maximum messages to keep in history.
  final int maxHistory;

  /// Maximum tokens to generate per response.
  final int maxTokens;

  /// Sampling temperature.
  final double temperature;

  /// Top-k sampling.
  final int topK;

  /// Nucleus sampling threshold.
  final double topP;

  /// Repetition penalty.
  final double repeatPenalty;

  const ChatConfig({
    this.systemPrompt,
    this.maxHistory = 50,
    this.maxTokens = 512,
    this.temperature = 0.7,
    this.topK = 40,
    this.topP = 0.9,
    this.repeatPenalty = 1.1,
  });

  /// Create config with custom system prompt.
  ChatConfig withSystemPrompt(String prompt) => ChatConfig(
        systemPrompt: prompt,
        maxHistory: maxHistory,
        maxTokens: maxTokens,
        temperature: temperature,
        topK: topK,
        topP: topP,
        repeatPenalty: repeatPenalty,
      );

  /// Create config with custom temperature.
  ChatConfig withTemperature(double temp) => ChatConfig(
        systemPrompt: systemPrompt,
        maxHistory: maxHistory,
        maxTokens: maxTokens,
        temperature: temp,
        topK: topK,
        topP: topP,
        repeatPenalty: repeatPenalty,
      );
}

/// High-level chat interface for conversational AI.
///
/// Provides a simple API for multi-turn conversations with automatic
/// history management and context handling.
///
/// Example:
/// ```dart
/// final chat = Chat(llamafu, config: ChatConfig(
///   systemPrompt: 'You are a helpful assistant.',
/// ));
///
/// final response = await chat.send('Hello!');
/// print(response);
///
/// final followUp = await chat.send('Tell me more');
/// print(followUp);
///
/// // Get full history
/// for (final msg in chat.history) {
///   print('${msg.role}: ${msg.content}');
/// }
///
/// // Clear and start fresh
/// chat.clear();
/// ```
class Chat {
  final dynamic _llamafu; // Llamafu instance
  final ChatConfig config;
  final List<ChatMessage> _history = [];

  /// Create a new chat session.
  Chat(this._llamafu, {this.config = const ChatConfig()}) {
    if (config.systemPrompt != null) {
      _history.add(ChatMessage.system(config.systemPrompt!));
    }
  }

  /// Get the conversation history.
  List<ChatMessage> get history => List.unmodifiable(_history);

  /// Get the number of messages in history.
  int get messageCount => _history.length;

  /// Check if conversation is empty.
  bool get isEmpty => _history.isEmpty;

  /// Send a message and get a response.
  ///
  /// The message is added to history, sent to the model with context,
  /// and the response is added to history before being returned.
  Future<String> send(String message) async {
    // Add user message
    _history.add(ChatMessage.user(message));

    // Build prompt with history
    final prompt = _buildPrompt();

    // Generate response
    final response = await _llamafu.complete(
      prompt: prompt,
      maxTokens: config.maxTokens,
      temperature: config.temperature,
      topK: config.topK,
      topP: config.topP,
      repeatPenalty: config.repeatPenalty,
    );

    // Add assistant response
    _history.add(ChatMessage.assistant(response));

    // Trim history if needed
    _trimHistory();

    return response;
  }

  /// Send a message and stream the response.
  ///
  /// Returns a stream of tokens as they are generated.
  /// The complete response is added to history when done.
  Stream<String> sendStream(String message) {
    final controller = StreamController<String>();
    final buffer = StringBuffer();

    // Add user message
    _history.add(ChatMessage.user(message));

    // Build prompt
    final prompt = _buildPrompt();

    // Start streaming
    _llamafu
        .completeStream(
      prompt: prompt,
      maxTokens: config.maxTokens,
      temperature: config.temperature,
    )
        .listen(
      (token) {
        buffer.write(token);
        controller.add(token);
      },
      onDone: () {
        // Add complete response to history
        _history.add(ChatMessage.assistant(buffer.toString()));
        _trimHistory();
        controller.close();
      },
      onError: (e) {
        controller.addError(e);
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Clear conversation history.
  ///
  /// Optionally keep the system prompt.
  void clear({bool keepSystemPrompt = true}) {
    if (keepSystemPrompt && config.systemPrompt != null) {
      _history.clear();
      _history.add(ChatMessage.system(config.systemPrompt!));
    } else {
      _history.clear();
    }
  }

  /// Remove the last exchange (user message + assistant response).
  void undoLast() {
    if (_history.length >= 2) {
      final last = _history.last;
      if (last.role == Role.assistant) {
        _history.removeLast(); // Remove assistant
        if (_history.isNotEmpty && _history.last.role == Role.user) {
          _history.removeLast(); // Remove user
        }
      }
    }
  }

  /// Edit the last user message and regenerate response.
  Future<String> editLast(String newMessage) async {
    undoLast();
    return send(newMessage);
  }

  /// Regenerate the last assistant response.
  Future<String> regenerate() async {
    if (_history.isEmpty) {
      throw StateError('No messages to regenerate');
    }

    // Find and remove last assistant message
    if (_history.last.role == Role.assistant) {
      _history.removeLast();
    }

    // Find last user message
    String? lastUserMessage;
    for (int i = _history.length - 1; i >= 0; i--) {
      if (_history[i].role == Role.user) {
        lastUserMessage = _history[i].content;
        _history.removeAt(i);
        break;
      }
    }

    if (lastUserMessage == null) {
      throw StateError('No user message to regenerate from');
    }

    return send(lastUserMessage);
  }

  /// Get conversation as formatted string.
  String format({String separator = '\n\n'}) {
    return _history.map((m) => '${m.role.name}: ${m.content}').join(separator);
  }

  /// Export history as JSON.
  List<Map<String, dynamic>> toJson() => _history.map((m) => m.toJson()).toList();

  /// Import history from JSON.
  void fromJson(List<Map<String, dynamic>> json) {
    _history.clear();
    for (final item in json) {
      _history.add(ChatMessage(
        role: Role.values.firstWhere((r) => r.name == item['role']),
        content: item['content'] as String,
        timestamp: DateTime.parse(item['timestamp'] as String),
        metadata: item['metadata'] as Map<String, dynamic>?,
      ));
    }
  }

  /// Build prompt from history.
  String _buildPrompt() {
    final buffer = StringBuffer();

    for (final msg in _history) {
      switch (msg.role) {
        case Role.system:
          buffer.writeln('System: ${msg.content}');
          break;
        case Role.user:
          buffer.writeln('User: ${msg.content}');
          break;
        case Role.assistant:
          buffer.writeln('Assistant: ${msg.content}');
          break;
      }
    }

    buffer.write('Assistant:');
    return buffer.toString();
  }

  /// Trim history to max length.
  void _trimHistory() {
    while (_history.length > config.maxHistory) {
      // Keep system prompt if present
      if (_history.first.role == Role.system) {
        if (_history.length > 1) {
          _history.removeAt(1);
        }
      } else {
        _history.removeAt(0);
      }
    }
  }
}

/// Builder for creating chat configurations.
class ChatConfigBuilder {
  String? _systemPrompt;
  int _maxHistory = 50;
  int _maxTokens = 512;
  double _temperature = 0.7;
  int _topK = 40;
  double _topP = 0.9;
  double _repeatPenalty = 1.1;

  /// Set system prompt.
  ChatConfigBuilder systemPrompt(String prompt) {
    _systemPrompt = prompt;
    return this;
  }

  /// Set max history length.
  ChatConfigBuilder maxHistory(int max) {
    _maxHistory = max;
    return this;
  }

  /// Set max tokens per response.
  ChatConfigBuilder maxTokens(int max) {
    _maxTokens = max;
    return this;
  }

  /// Set temperature.
  ChatConfigBuilder temperature(double temp) {
    _temperature = temp;
    return this;
  }

  /// Set top-k sampling.
  ChatConfigBuilder topK(int k) {
    _topK = k;
    return this;
  }

  /// Set top-p sampling.
  ChatConfigBuilder topP(double p) {
    _topP = p;
    return this;
  }

  /// Set repetition penalty.
  ChatConfigBuilder repeatPenalty(double penalty) {
    _repeatPenalty = penalty;
    return this;
  }

  /// Build the configuration.
  ChatConfig build() => ChatConfig(
        systemPrompt: _systemPrompt,
        maxHistory: _maxHistory,
        maxTokens: _maxTokens,
        temperature: _temperature,
        topK: _topK,
        topP: _topP,
        repeatPenalty: _repeatPenalty,
      );
}
