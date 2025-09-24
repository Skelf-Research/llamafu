# Integration Guide

This guide covers common integration patterns and best practices for using Llamafu in Flutter applications.

## Architecture Patterns

### Service Layer Pattern

Create a dedicated service class to manage model lifecycle:

```dart
class LlamaService {
  static LlamaService? _instance;
  Llamafu? _llamafu;

  LlamaService._();

  static LlamaService get instance {
    _instance ??= LlamaService._();
    return _instance!;
  }

  Future<void> initialize({
    required String modelPath,
    int threads = 4,
    int contextSize = 2048,
  }) async {
    if (_llamafu != null) return;

    _llamafu = await Llamafu.init(
      modelPath: modelPath,
      threads: threads,
      contextSize: contextSize,
    );
  }

  Future<String> generateText({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.7,
  }) async {
    if (_llamafu == null) throw StateError('Service not initialized');

    return await _llamafu!.complete(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
    );
  }

  void dispose() {
    _llamafu?.close();
    _llamafu = null;
  }
}
```

### Repository Pattern

For applications with multiple models or configurations:

```dart
abstract class ModelRepository {
  Future<Llamafu> loadModel(String modelId);
  Future<void> unloadModel(String modelId);
  List<String> get availableModels;
}

class LocalModelRepository implements ModelRepository {
  final Map<String, Llamafu> _models = {};
  final Map<String, String> _modelPaths = {
    'chat': '/models/llama-7b-chat.gguf',
    'code': '/models/codellama-13b.gguf',
    'vision': '/models/llava-7b.gguf',
  };

  @override
  Future<Llamafu> loadModel(String modelId) async {
    if (_models.containsKey(modelId)) {
      return _models[modelId]!;
    }

    final path = _modelPaths[modelId];
    if (path == null) throw ArgumentError('Model not found: $modelId');

    final model = await Llamafu.init(
      modelPath: path,
      mmprojPath: modelId == 'vision' ? '/models/mmproj.gguf' : null,
    );

    _models[modelId] = model;
    return model;
  }

  @override
  Future<void> unloadModel(String modelId) async {
    final model = _models.remove(modelId);
    model?.close();
  }

  @override
  List<String> get availableModels => _modelPaths.keys.toList();
}
```

## Chat Applications

### Chat Message Handling

```dart
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class ChatService {
  final Llamafu _llamafu;
  final List<ChatMessage> _messages = [];

  ChatService(this._llamafu);

  String _buildPrompt() {
    final buffer = StringBuffer();

    for (final message in _messages) {
      if (message.role == 'user') {
        buffer.writeln('<|im_start|>user');
        buffer.writeln(message.content);
        buffer.writeln('<|im_end|>');
      } else {
        buffer.writeln('<|im_start|>assistant');
        buffer.writeln(message.content);
        buffer.writeln('<|im_end|>');
      }
    }

    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  Future<String> sendMessage(String content) async {
    _messages.add(ChatMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    ));

    final prompt = _buildPrompt();
    final response = await _llamafu.complete(
      prompt: prompt,
      maxTokens: 200,
      temperature: 0.7,
      topP: 0.9,
    );

    final cleanResponse = response.replaceFirst(prompt, '').trim();

    _messages.add(ChatMessage(
      role: 'assistant',
      content: cleanResponse,
      timestamp: DateTime.now(),
    ));

    return cleanResponse;
  }

  void clearHistory() => _messages.clear();
}
```

### Flutter UI Integration

```dart
class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatService _chatService;
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      final llamafu = await Llamafu.init(
        modelPath: await _getModelPath(),
        threads: Platform.numberOfProcessors,
        contextSize: 4096,
      );
      _chatService = ChatService(llamafu);
    } catch (e) {
      _showError('Failed to initialize chat: $e');
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
        role: 'user',
        content: text,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _textController.clear();

    try {
      final response = await _chatService.sendMessage(text);
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: response,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      _showError('Failed to send message: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ChatMessageWidget(message: message);
              },
            ),
          ),
          if (_isLoading) LinearProgressIndicator(),
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _sendMessage,
                  child: Text('Send'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## Document Analysis

### PDF/Image Text Extraction

```dart
class DocumentAnalyzer {
  final Llamafu _llamafu;

  DocumentAnalyzer(this._llamafu);

  Future<DocumentAnalysis> analyzeDocument({
    required String imagePath,
    DocumentType type = DocumentType.general,
  }) async {
    final prompt = _buildAnalysisPrompt(type);

    final result = await _llamafu.multimodalComplete(
      prompt: prompt,
      mediaInputs: [
        MediaInput(type: MediaType.image, data: imagePath),
      ],
      maxTokens: 500,
      temperature: 0.3, // Lower temperature for factual extraction
    );

    return DocumentAnalysis.fromText(result, type);
  }

  String _buildAnalysisPrompt(DocumentType type) {
    switch (type) {
      case DocumentType.invoice:
        return '''
        Analyze this invoice image and extract the following information in JSON format:
        - invoice_number
        - date
        - vendor_name
        - total_amount
        - line_items (array of {description, quantity, unit_price, total})

        Provide only the JSON response:
        ''';

      case DocumentType.receipt:
        return '''
        Extract receipt information in JSON format:
        - merchant_name
        - date
        - total_amount
        - items (array of {name, price})
        - payment_method

        JSON response:
        ''';

      case DocumentType.general:
      default:
        return '''
        Analyze this document and extract key information:
        - Document type
        - Main content summary
        - Key dates, numbers, or entities mentioned
        - Overall purpose or context
        ''';
    }
  }
}

enum DocumentType { general, invoice, receipt, contract }

class DocumentAnalysis {
  final String rawText;
  final DocumentType type;
  final Map<String, dynamic> extractedData;

  DocumentAnalysis({
    required this.rawText,
    required this.type,
    required this.extractedData,
  });

  factory DocumentAnalysis.fromText(String text, DocumentType type) {
    Map<String, dynamic> extracted = {};

    try {
      // Try to parse as JSON if it looks like structured data
      if (text.trim().startsWith('{')) {
        extracted = json.decode(text);
      }
    } catch (e) {
      // If parsing fails, store as plain text
      extracted = {'content': text};
    }

    return DocumentAnalysis(
      rawText: text,
      type: type,
      extractedData: extracted,
    );
  }
}
```

## Code Generation

### AI-Powered Code Assistant

```dart
class CodeAssistant {
  final Llamafu _llamafu;

  CodeAssistant(this._llamafu);

  Future<CodeSuggestion> generateCode({
    required String specification,
    CodeLanguage language = CodeLanguage.dart,
    CodeStyle style = CodeStyle.clean,
  }) async {
    final grammar = _getCodeGrammar(language);
    final prompt = _buildCodePrompt(specification, language, style);

    final result = await _llamafu.completeWithGrammar(
      prompt: prompt,
      grammarStr: grammar,
      grammarRoot: 'root',
      maxTokens: 1000,
      temperature: 0.4, // Lower temperature for more consistent code
    );

    return CodeSuggestion.parse(result, language);
  }

  Future<String> explainCode(String code) async {
    final prompt = '''
    Explain the following code in detail, including:
    1. What it does
    2. How it works
    3. Any potential issues or improvements

    Code:
    ```
    $code
    ```

    Explanation:
    ''';

    return await _llamafu.complete(
      prompt: prompt,
      maxTokens: 400,
      temperature: 0.6,
    );
  }

  Future<List<String>> suggestImprovements(String code) async {
    final prompt = '''
    Review this code and suggest specific improvements:

    ```
    $code
    ```

    Provide suggestions as a numbered list:
    1.
    ''';

    final result = await _llamafu.complete(
      prompt: prompt,
      maxTokens: 300,
      temperature: 0.5,
    );

    return result
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), ''))
        .toList();
  }

  String _buildCodePrompt(String spec, CodeLanguage lang, CodeStyle style) {
    final langName = lang.name.toLowerCase();
    final styleDesc = _getStyleDescription(style);

    return '''
    Generate clean, well-documented $langName code for: $spec

    Requirements:
    - Follow $styleDesc coding practices
    - Include appropriate comments
    - Handle edge cases
    - Use meaningful variable names

    Code:
    ''';
  }

  String _getStyleDescription(CodeStyle style) {
    switch (style) {
      case CodeStyle.clean:
        return 'clean code';
      case CodeStyle.functional:
        return 'functional programming';
      case CodeStyle.objectOriented:
        return 'object-oriented';
      default:
        return 'standard';
    }
  }

  String _getCodeGrammar(CodeLanguage language) {
    // Return appropriate GBNF grammar for the language
    // This is simplified - real implementation would have full grammars
    switch (language) {
      case CodeLanguage.dart:
        return '''
        root ::= code_block
        code_block ::= "```dart\\n" dart_code "\\n```"
        dart_code ::= (line "\\n")*
        line ::= [^\\n]*
        ''';

      case CodeLanguage.python:
        return '''
        root ::= code_block
        code_block ::= "```python\\n" python_code "\\n```"
        python_code ::= (line "\\n")*
        line ::= [^\\n]*
        ''';

      default:
        return '''
        root ::= code_block
        code_block ::= "```\\n" code "\\n```"
        code ::= (line "\\n")*
        line ::= [^\\n]*
        ''';
    }
  }
}

enum CodeLanguage { dart, python, javascript, java, swift, kotlin }
enum CodeStyle { clean, functional, objectOriented, minimal }

class CodeSuggestion {
  final String code;
  final CodeLanguage language;
  final String? explanation;

  CodeSuggestion({
    required this.code,
    required this.language,
    this.explanation,
  });

  factory CodeSuggestion.parse(String text, CodeLanguage language) {
    // Extract code from markdown blocks
    final codeMatch = RegExp(r'```[\w]*\n(.*?)\n```', dotAll: true).firstMatch(text);
    final code = codeMatch?.group(1) ?? text;

    return CodeSuggestion(
      code: code.trim(),
      language: language,
      explanation: text.contains('```') ? text.split('```').first.trim() : null,
    );
  }
}
```

## Background Processing

### Isolate-Based Processing

```dart
class BackgroundLlamaService {
  SendPort? _sendPort;
  Isolate? _isolate;

  Future<void> start(String modelPath) async {
    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _isolateEntry,
      IsolateData(
        sendPort: receivePort.sendPort,
        modelPath: modelPath,
      ),
    );

    _sendPort = await receivePort.first as SendPort;
  }

  Future<String> generateText(String prompt) async {
    if (_sendPort == null) throw StateError('Service not started');

    final responsePort = ReceivePort();
    _sendPort!.send(GenerateRequest(
      prompt: prompt,
      responsePort: responsePort.sendPort,
    ));

    final result = await responsePort.first;
    if (result is Exception) throw result;
    return result as String;
  }

  void stop() {
    _isolate?.kill();
    _isolate = null;
    _sendPort = null;
  }

  static void _isolateEntry(IsolateData data) async {
    final llamafu = await Llamafu.init(modelPath: data.modelPath);
    data.sendPort.send(ReceivePort().sendPort);

    await for (final message in ReceivePort().cast<GenerateRequest>()) {
      try {
        final result = await llamafu.complete(prompt: message.prompt);
        message.responsePort.send(result);
      } catch (e) {
        message.responsePort.send(e);
      }
    }

    llamafu.close();
  }
}

class IsolateData {
  final SendPort sendPort;
  final String modelPath;

  IsolateData({required this.sendPort, required this.modelPath});
}

class GenerateRequest {
  final String prompt;
  final SendPort responsePort;

  GenerateRequest({required this.prompt, required this.responsePort});
}
```

## Performance Optimization

### Model Preloading

```dart
class ModelPreloader {
  final Map<String, Llamafu> _preloadedModels = {};

  Future<void> preloadModels(List<String> modelIds) async {
    final futures = modelIds.map((id) => _preloadModel(id));
    await Future.wait(futures);
  }

  Future<void> _preloadModel(String modelId) async {
    try {
      final path = await getModelPath(modelId);
      final model = await Llamafu.init(modelPath: path);
      _preloadedModels[modelId] = model;
    } catch (e) {
      debugPrint('Failed to preload model $modelId: $e');
    }
  }

  Llamafu? getModel(String modelId) => _preloadedModels[modelId];

  void disposeAll() {
    for (final model in _preloadedModels.values) {
      model.close();
    }
    _preloadedModels.clear();
  }
}
```

### Context Window Management

```dart
class ContextManager {
  final Llamafu llamafu;
  final int maxContext;
  int _currentTokens = 0;

  ContextManager({
    required this.llamafu,
    required this.maxContext,
  });

  Future<String> generateWithContext({
    required String prompt,
    int maxTokens = 128,
  }) async {
    final promptTokens = await _countTokens(prompt);
    final availableTokens = maxContext - _currentTokens - promptTokens;

    if (availableTokens < maxTokens) {
      // Truncate or clear context
      await _manageContext(promptTokens + maxTokens);
    }

    final result = await llamafu.complete(
      prompt: prompt,
      maxTokens: min(maxTokens, availableTokens),
    );

    _currentTokens += promptTokens + await _countTokens(result);
    return result;
  }

  Future<int> _countTokens(String text) async {
    final tokens = await llamafu.tokenize(text);
    return tokens.length;
  }

  Future<void> _manageContext(int requiredTokens) async {
    if (requiredTokens > maxContext) {
      throw ArgumentError('Required tokens exceed maximum context');
    }

    // Simple strategy: clear context if needed
    if (_currentTokens + requiredTokens > maxContext) {
      _currentTokens = 0;
      // In a real implementation, you might want to preserve
      // recent conversation history
    }
  }
}
```

## Testing Strategies

### Mock Implementation

```dart
class MockLlamafu extends Llamafu {
  final Map<String, String> _responses;

  MockLlamafu(this._responses);

  @override
  Future<String> complete({
    required String prompt,
    int maxTokens = 128,
    double temperature = 0.7,
    int? topK,
    double? topP,
    double? repeatPenalty,
    int? seed,
  }) async {
    // Simulate processing delay
    await Future.delayed(Duration(milliseconds: 100));

    // Return predefined response or generate simple one
    return _responses[prompt] ?? 'Mock response for: ${prompt.substring(0, 50)}...';
  }

  @override
  Future<List<int>> tokenize(String text) async {
    // Simple mock tokenization
    return text.split(' ').map((e) => e.hashCode).toList();
  }

  // Override other methods as needed for testing
}
```

### Integration Tests

```dart
group('Llamafu Integration Tests', () {
  late Llamafu llamafu;

  setUpAll(() async {
    llamafu = await Llamafu.init(
      modelPath: await getTestModelPath(),
      contextSize: 512,
    );
  });

  tearDownAll(() {
    llamafu.close();
  });

  test('should generate coherent text', () async {
    final result = await llamafu.complete(
      prompt: 'The capital of France is',
      maxTokens: 10,
    );

    expect(result, contains('Paris'));
  });

  test('should respect max tokens limit', () async {
    final result = await llamafu.complete(
      prompt: 'Write a long story',
      maxTokens: 5,
    );

    final tokens = await llamafu.tokenize(result);
    expect(tokens.length, lessThanOrEqualTo(5));
  });
});
```