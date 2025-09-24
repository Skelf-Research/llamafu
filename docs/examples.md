# Examples

This document provides complete, runnable examples for common Llamafu use cases.

## Basic Text Generation

### Simple Completion

```dart
import 'package:flutter/material.dart';
import 'package:llamafu/llamafu.dart';

class SimpleCompletionExample extends StatefulWidget {
  @override
  _SimpleCompletionExampleState createState() => _SimpleCompletionExampleState();
}

class _SimpleCompletionExampleState extends State<SimpleCompletionExample> {
  Llamafu? _llamafu;
  String _result = '';
  bool _loading = false;
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      _llamafu = await Llamafu.init(
        modelPath: await _getModelPath(),
        threads: 4,
        contextSize: 2048,
      );
    } catch (e) {
      _showError('Failed to initialize model: $e');
    }
  }

  Future<void> _generate() async {
    if (_llamafu == null || _promptController.text.isEmpty) return;

    setState(() => _loading = true);

    try {
      final result = await _llamafu!.complete(
        prompt: _promptController.text,
        maxTokens: 128,
        temperature: 0.7,
      );

      setState(() => _result = result);
    } catch (e) {
      _showError('Generation failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Simple Text Generation')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _promptController,
              decoration: InputDecoration(
                labelText: 'Enter your prompt',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _generate,
              child: _loading ? CircularProgressIndicator() : Text('Generate'),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? 'Generated text will appear here...' : _result,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getModelPath() async {
    // Implementation depends on your asset management strategy
    return '/path/to/your/model.gguf';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _llamafu?.close();
    _promptController.dispose();
    super.dispose();
  }
}
```

## Chat Application

### Complete Chat Interface

```dart
import 'package:flutter/material.dart';
import 'package:llamafu/llamafu.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Llamafu? _llamafu;
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() => _isLoading = true);

      _llamafu = await Llamafu.init(
        modelPath: await _getModelPath(),
        threads: Platform.numberOfProcessors,
        contextSize: 4096,
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      _showError('Failed to initialize chat: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _buildChatPrompt() {
    final buffer = StringBuffer();

    // System prompt
    buffer.writeln('<|im_start|>system');
    buffer.writeln('You are a helpful, harmless, and honest AI assistant.');
    buffer.writeln('<|im_end|>');

    // Conversation history
    for (final message in _messages) {
      buffer.writeln('<|im_start|>${message.role}');
      buffer.writeln(message.content);
      buffer.writeln('<|im_end|>');
    }

    buffer.write('<|im_start|>assistant\n');
    return buffer.toString();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading || !_isInitialized) return;

    final userMessage = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      final prompt = _buildChatPrompt();
      final response = await _llamafu!.complete(
        prompt: prompt,
        maxTokens: 200,
        temperature: 0.7,
        topP: 0.9,
        repeatPenalty: 1.1,
      );

      // Extract just the assistant's response
      final cleanResponse = response.replaceFirst(prompt, '').trim();

      final assistantMessage = ChatMessage(
        role: 'assistant',
        content: cleanResponse,
        timestamp: DateTime.now(),
      );

      setState(() => _messages.add(assistantMessage));
      _scrollToBottom();
    } catch (e) {
      _showError('Failed to send message: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized && _isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('AI Chat')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing AI model...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Chat'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () => setState(() => _messages.clear()),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'Start a conversation!',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return ChatMessageWidget(message: _messages[index]);
                    },
                  ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(8),
              child: Row(
                children: [
                  SizedBox(width: 16),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('AI is typing...'),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: (_isLoading || !_isInitialized) ? null : _sendMessage,
                  child: Icon(Icons.send),
                  mini: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getModelPath() async {
    // Your model path logic
    return '/path/to/chat-model.gguf';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _llamafu?.close();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatMessageWidget({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.blue : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}
```

## Multi-Modal Applications

### Image Analysis App

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:llamafu/llamafu.dart';
import 'dart:io';

class ImageAnalysisApp extends StatefulWidget {
  @override
  _ImageAnalysisAppState createState() => _ImageAnalysisAppState();
}

class _ImageAnalysisAppState extends State<ImageAnalysisApp> {
  Llamafu? _llamafu;
  File? _selectedImage;
  String _analysis = '';
  bool _isLoading = false;
  bool _isInitialized = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      setState(() => _isLoading = true);

      _llamafu = await Llamafu.init(
        modelPath: await _getVisionModelPath(),
        mmprojPath: await _getVisionProjectorPath(),
        threads: 4,
        contextSize: 2048,
        useGpu: true,
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      _showError('Failed to initialize vision model: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _analysis = '';
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _analyzeImage(String prompt) async {
    if (_selectedImage == null || !_isInitialized) return;

    setState(() => _isLoading = true);

    try {
      final result = await _llamafu!.multimodalComplete(
        prompt: prompt,
        mediaInputs: [
          MediaInput(
            type: MediaType.image,
            data: _selectedImage!.path,
          ),
        ],
        maxTokens: 300,
        temperature: 0.7,
      );

      setState(() => _analysis = result);
    } catch (e) {
      _showError('Analysis failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Analysis'),
        actions: [
          PopupMenuButton<ImageSource>(
            onSelected: _pickImage,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ImageSource.camera,
                child: ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Camera'),
                ),
              ),
              PopupMenuItem(
                value: ImageSource.gallery,
                child: ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: !_isInitialized && _isLoading
          ? _buildLoadingIndicator()
          : _buildMainContent(),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading vision model...'),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedImage != null) ...[
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: 16),
            _buildAnalysisButtons(),
          ] else ...[
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, style: BorderStyle.dashed),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No image selected'),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      child: Text('Choose Image'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_analysis.isNotEmpty) ...[
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Analysis',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _analysis,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_isLoading) ...[
            SizedBox(height: 16),
            Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisButtons() {
    final analyses = [
      {'label': 'Describe Image', 'prompt': 'Describe this image in detail:'},
      {'label': 'Find Objects', 'prompt': 'List all the objects you can see in this image:'},
      {'label': 'Read Text', 'prompt': 'Extract and transcribe any text visible in this image:'},
      {'label': 'Analyze Scene', 'prompt': 'Analyze the scene, mood, and context of this image:'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: analyses.map((analysis) {
        return ElevatedButton(
          onPressed: _isLoading ? null : () => _analyzeImage(analysis['prompt']!),
          child: Text(analysis['label']!),
        );
      }).toList(),
    );
  }

  Future<String> _getVisionModelPath() async {
    // Return path to your vision model
    return '/path/to/llava-model.gguf';
  }

  Future<String> _getVisionProjectorPath() async {
    // Return path to your vision projector
    return '/path/to/mmproj.gguf';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _llamafu?.close();
    super.dispose();
  }
}
```

## Code Assistant

### AI-Powered Code Generator

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:llamafu/llamafu.dart';

class CodeAssistantApp extends StatefulWidget {
  @override
  _CodeAssistantAppState createState() => _CodeAssistantAppState();
}

class _CodeAssistantAppState extends State<CodeAssistantApp>
    with SingleTickerProviderStateMixin {
  Llamafu? _llamafu;
  late TabController _tabController;

  final TextEditingController _specController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String _generatedCode = '';
  String _explanation = '';
  List<String> _suggestions = [];

  bool _isLoading = false;
  bool _isInitialized = false;
  CodeLanguage _selectedLanguage = CodeLanguage.dart;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      setState(() => _isLoading = true);

      _llamafu = await Llamafu.init(
        modelPath: await _getCodeModelPath(),
        threads: 6,
        contextSize: 8192, // Larger context for code
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      _showError('Failed to initialize code model: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateCode() async {
    if (!_isInitialized || _specController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final grammar = _getCodeGrammar(_selectedLanguage);
      final prompt = _buildCodePrompt(_specController.text, _selectedLanguage);

      final result = await _llamafu!.completeWithGrammar(
        prompt: prompt,
        grammarStr: grammar,
        grammarRoot: 'root',
        maxTokens: 800,
        temperature: 0.4,
      );

      final codeMatch = RegExp(r'```[\w]*\n(.*?)\n```', dotAll: true)
          .firstMatch(result);
      final code = codeMatch?.group(1) ?? result;

      setState(() => _generatedCode = code.trim());
    } catch (e) {
      _showError('Code generation failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _explainCode() async {
    if (!_isInitialized || _codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final prompt = '''
Explain the following code in detail, including:
1. What it does
2. How it works
3. Key concepts used
4. Any potential issues

Code:
```
${_codeController.text}
```

Explanation:
''';

      final result = await _llamafu!.complete(
        prompt: prompt,
        maxTokens: 400,
        temperature: 0.6,
      );

      setState(() => _explanation = result.replaceFirst(prompt, '').trim());
    } catch (e) {
      _showError('Code explanation failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getSuggestions() async {
    if (!_isInitialized || _codeController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final prompt = '''
Review this code and provide specific improvement suggestions:

```
${_codeController.text}
```

Provide numbered suggestions:
1.
''';

      final result = await _llamafu!.complete(
        prompt: prompt,
        maxTokens: 300,
        temperature: 0.5,
      );

      final suggestions = result
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), ''))
          .where((line) => line.isNotEmpty)
          .toList();

      setState(() => _suggestions = suggestions);
    } catch (e) {
      _showError('Failed to get suggestions: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized && _isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Code Assistant')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading code model...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('AI Code Assistant'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Generate'),
            Tab(text: 'Explain'),
            Tab(text: 'Improve'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGenerateTab(),
          _buildExplainTab(),
          _buildImproveTab(),
        ],
      ),
    );
  }

  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Code Specification',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<CodeLanguage>(
                    value: _selectedLanguage,
                    decoration: InputDecoration(
                      labelText: 'Language',
                      border: OutlineInputBorder(),
                    ),
                    items: CodeLanguage.values.map((lang) {
                      return DropdownMenuItem(
                        value: lang,
                        child: Text(lang.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedLanguage = value!);
                    },
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _specController,
                    decoration: InputDecoration(
                      labelText: 'What do you want to build?',
                      hintText: 'e.g., A function to calculate fibonacci numbers',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _generateCode,
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : Text('Generate Code'),
                  ),
                ],
              ),
            ),
          ),
          if (_generatedCode.isNotEmpty) ...[
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Generated Code',
                          style: Theme.of(context).textTheme.headline6,
                        ),
                        IconButton(
                          icon: Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _generatedCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Code copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Text(
                          _generatedCode,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExplainTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Code to Explain',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: 'Paste your code here...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _explainCode,
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : Text('Explain Code'),
                  ),
                ],
              ),
            ),
          ),
          if (_explanation.isNotEmpty) ...[
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explanation',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _explanation,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImproveTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Code to Review',
                    style: Theme.of(context).textTheme.headline6,
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: 'Paste your code here for suggestions...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 10,
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _getSuggestions,
                    child: _isLoading
                        ? CircularProgressIndicator()
                        : Text('Get Suggestions'),
                  ),
                ],
              ),
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            SizedBox(height: 16),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Improvement Suggestions',
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    SizedBox(height: 8),
                    ...(_suggestions.asMap().entries.map((entry) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${entry.key + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList()),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildCodePrompt(String spec, CodeLanguage language) {
    final langName = language.name.toLowerCase();

    return '''
Generate clean, well-documented $langName code for: $spec

Requirements:
- Follow best practices for $langName
- Include appropriate comments
- Handle edge cases
- Use meaningful variable names
- Write production-ready code

Code:
''';
  }

  String _getCodeGrammar(CodeLanguage language) {
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
      case CodeLanguage.javascript:
        return '''
root ::= code_block
code_block ::= "```javascript\\n" js_code "\\n```"
js_code ::= (line "\\n")*
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

  Future<String> _getCodeModelPath() async {
    // Return path to your code model
    return '/path/to/codellama-13b-instruct.gguf';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _llamafu?.close();
    _tabController.dispose();
    _specController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}

enum CodeLanguage { dart, python, javascript, java, swift, kotlin }
```

## Advanced Features

### LoRA Adapter Manager

```dart
import 'package:flutter/material.dart';
import 'package:llamafu/llamafu.dart';

class LoraManagerApp extends StatefulWidget {
  @override
  _LoraManagerAppState createState() => _LoraManagerAppState();
}

class _LoraManagerAppState extends State<LoraManagerApp> {
  Llamafu? _llamafu;
  final Map<String, LoraAdapter> _loadedAdapters = {};
  final Map<String, bool> _appliedAdapters = {};

  bool _isLoading = false;
  bool _isInitialized = false;

  final List<LoraAdapterInfo> _availableAdapters = [
    LoraAdapterInfo(
      name: 'Math Specialist',
      path: '/adapters/math-lora.gguf',
      description: 'Specialized for mathematical problem solving',
    ),
    LoraAdapterInfo(
      name: 'Creative Writing',
      path: '/adapters/creative-lora.gguf',
      description: 'Enhanced creative writing capabilities',
    ),
    LoraAdapterInfo(
      name: 'Code Assistant',
      path: '/adapters/code-lora.gguf',
      description: 'Improved code generation and debugging',
    ),
  ];

  final TextEditingController _promptController = TextEditingController();
  String _result = '';

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      setState(() => _isLoading = true);

      _llamafu = await Llamafu.init(
        modelPath: await _getBaseModelPath(),
        threads: 4,
        contextSize: 2048,
      );

      setState(() => _isInitialized = true);
    } catch (e) {
      _showError('Failed to initialize model: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAdapter(LoraAdapterInfo adapterInfo) async {
    if (!_isInitialized || _loadedAdapters.containsKey(adapterInfo.name)) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final adapter = await _llamafu!.loadLoraAdapter(adapterInfo.path);
      setState(() {
        _loadedAdapters[adapterInfo.name] = adapter;
        _appliedAdapters[adapterInfo.name] = false;
      });
    } catch (e) {
      _showError('Failed to load adapter ${adapterInfo.name}: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAdapter(String adapterName, bool apply) async {
    if (!_loadedAdapters.containsKey(adapterName)) return;

    setState(() => _isLoading = true);

    try {
      final adapter = _loadedAdapters[adapterName]!;

      if (apply) {
        await _llamafu!.applyLoraAdapter(adapter, scale: 0.8);
      } else {
        await _llamafu!.removeLoraAdapter(adapter);
      }

      setState(() => _appliedAdapters[adapterName] = apply);
    } catch (e) {
      _showError('Failed to ${apply ? 'apply' : 'remove'} adapter: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateWithAdapters() async {
    if (!_isInitialized || _promptController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final result = await _llamafu!.complete(
        prompt: _promptController.text,
        maxTokens: 200,
        temperature: 0.7,
      );

      setState(() => _result = result);
    } catch (e) {
      _showError('Generation failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized && _isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('LoRA Manager')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing model...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('LoRA Adapter Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.clear_all),
            onPressed: _clearAllAdapters,
            tooltip: 'Clear all adapters',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAdaptersList(),
            SizedBox(height: 16),
            _buildGenerationCard(),
            if (_result.isNotEmpty) ...[
              SizedBox(height: 16),
              _buildResultCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptersList() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available LoRA Adapters',
              style: Theme.of(context).textTheme.headline6,
            ),
            SizedBox(height: 16),
            ..._availableAdapters.map((adapter) {
              final isLoaded = _loadedAdapters.containsKey(adapter.name);
              final isApplied = _appliedAdapters[adapter.name] ?? false;

              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(adapter.name),
                  subtitle: Text(adapter.description),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isLoaded)
                        ElevatedButton(
                          onPressed: _isLoading ? null : () => _loadAdapter(adapter),
                          child: Text('Load'),
                        )
                      else ...[
                        Switch(
                          value: isApplied,
                          onChanged: _isLoading ? null : (value) => _toggleAdapter(adapter.name, value),
                        ),
                        SizedBox(width: 8),
                        Text(isApplied ? 'Applied' : 'Loaded'),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerationCard() {
    final appliedCount = _appliedAdapters.values.where((v) => v).length;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Text Generation',
                  style: Theme.of(context).textTheme.headline6,
                ),
                Chip(
                  label: Text('$appliedCount adapters active'),
                  backgroundColor: appliedCount > 0 ? Colors.green[100] : Colors.grey[200],
                ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              controller: _promptController,
              decoration: InputDecoration(
                labelText: 'Enter your prompt',
                border: OutlineInputBorder(),
                hintText: 'Try prompts that match your active adapters...',
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateWithAdapters,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Generate with Active Adapters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Generated Result',
              style: Theme.of(context).textTheme.headline6,
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                _result,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAllAdapters() async {
    if (!_isInitialized) return;

    setState(() => _isLoading = true);

    try {
      await _llamafu!.clearAllLoraAdapters();
      setState(() {
        _appliedAdapters.clear();
        _appliedAdapters.updateAll((key, value) => false);
      });
    } catch (e) {
      _showError('Failed to clear adapters: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getBaseModelPath() async {
    return '/path/to/base-model.gguf';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _llamafu?.close();
    _promptController.dispose();
    super.dispose();
  }
}

class LoraAdapterInfo {
  final String name;
  final String path;
  final String description;

  LoraAdapterInfo({
    required this.name,
    required this.path,
    required this.description,
  });
}
```

## Utility Functions

### Model Path Helper

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ModelPathHelper {
  static const Map<String, String> _modelFiles = {
    'chat': 'llama-2-7b-chat.Q4_K_M.gguf',
    'code': 'codellama-13b-instruct.Q4_K_M.gguf',
    'vision': 'llava-v1.6-13b.Q4_K_M.gguf',
    'vision_proj': 'llava-v1.6-13b-mmproj-f16.gguf',
  };

  static Future<String> getModelPath(String modelType) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${documentsDir.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final fileName = _modelFiles[modelType];
    if (fileName == null) {
      throw ArgumentError('Unknown model type: $modelType');
    }

    final filePath = '${modelsDir.path}/$fileName';
    final file = File(filePath);

    if (!await file.exists()) {
      throw FileSystemException('Model file not found: $filePath');
    }

    return filePath;
  }

  static Future<List<String>> getAvailableModels() async {
    final documentsDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${documentsDir.path}/models');

    if (!await modelsDir.exists()) {
      return [];
    }

    final files = await modelsDir
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.gguf'))
        .map((file) => file.path)
        .toList();

    return files;
  }
}
```

All examples include proper error handling, loading states, and resource management. They demonstrate real-world usage patterns and can serve as starting points for your own applications.