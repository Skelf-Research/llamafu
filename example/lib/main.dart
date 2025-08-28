import 'package:flutter/material.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  runApp(const LlamafuExampleApp());
}

class LlamafuExampleApp extends StatelessWidget {
  const LlamafuExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Llamafu Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LlamafuExampleHomePage(),
    );
  }
}

class LlamafuExampleHomePage extends StatefulWidget {
  const LlamafuExampleHomePage({super.key});

  @override
  State<LlamafuExampleHomePage> createState() => _LlamafuExampleHomePageState();
}

class _LlamafuExampleHomePageState extends State<LlamafuExampleHomePage> {
  Llamafu? _llamafu;
  String _result = 'Please initialize the model first';
  bool _isLoading = false;
  bool _isModelLoaded = false;
  LoraAdapter? _loadedLoraAdapter;

  // Text controllers for input fields
  final TextEditingController _modelPathController = TextEditingController();
  final TextEditingController _mmprojPathController = TextEditingController();
  final TextEditingController _promptController = TextEditingController(text: 'The quick brown fox');
  final TextEditingController _maxTokensController = TextEditingController(text: '128');
  final TextEditingController _temperatureController = TextEditingController(text: '0.8');
  final TextEditingController _loraPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _promptController.text = 'The quick brown fox';
  }

  @override
  void dispose() {
    _modelPathController.dispose();
    _mmprojPathController.dispose();
    _promptController.dispose();
    _maxTokensController.dispose();
    _temperatureController.dispose();
    _loraPathController.dispose();
    _llamafu?.close();
    super.dispose();
  }

  Future<void> _initLlamafu() async {
    if (_modelPathController.text.isEmpty) {
      setState(() {
        _result = 'Please enter a model path';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Initializing model...';
    });

    try {
      _llamafu = await Llamafu.init(
        modelPath: _modelPathController.text,
        mmprojPath: _mmprojPathController.text.isNotEmpty ? _mmprojPathController.text : null,
        threads: 4,
        contextSize: 512,
        useGpu: false,
      );

      setState(() {
        _result = 'Model initialized successfully!';
        _isLoading = false;
        _isModelLoaded = true;
      });
    } catch (e) {
      setState(() {
        _result = 'Failed to initialize Llamafu: $e';
        _isLoading = false;
        _isModelLoaded = false;
      });
    }
  }

  Future<void> _generateText() async {
    if (_llamafu == null) {
      setState(() {
        _result = 'Please initialize the model first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Generating text...';
    });

    try {
      final result = await _llamafu!.complete(
        prompt: _promptController.text,
        maxTokens: int.tryParse(_maxTokensController.text) ?? 128,
        temperature: double.tryParse(_temperatureController.text) ?? 0.8,
      );

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateMultimodal() async {
    if (_llamafu == null) {
      setState(() {
        _result = 'Please initialize the model first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Generating multi-modal response...';
    });

    try {
      // Example of multi-modal inference - in a real app, you would provide actual media files
      final result = await _llamafu!.multimodalComplete(
        prompt: _promptController.text,
        mediaInputs: [], // In a real app, you would add MediaInput objects here
        maxTokens: int.tryParse(_maxTokensController.text) ?? 128,
        temperature: double.tryParse(_temperatureController.text) ?? 0.8,
      );

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLoraAdapter() async {
    if (_llamafu == null) {
      setState(() {
        _result = 'Please initialize the model first';
      });
      return;
    }

    if (_loraPathController.text.isEmpty) {
      setState(() {
        _result = 'Please enter a LoRA adapter path';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Loading LoRA adapter...';
    });

    try {
      _loadedLoraAdapter = await _llamafu!.loadLoraAdapter(_loraPathController.text);
      setState(() {
        _result = 'LoRA adapter loaded successfully';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error loading LoRA adapter: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _applyLoraAdapter() async {
    if (_llamafu == null) {
      setState(() {
        _result = 'Please initialize the model first';
      });
      return;
    }

    if (_loadedLoraAdapter == null) {
      setState(() {
        _result = 'No LoRA adapter loaded';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Applying LoRA adapter...';
    });

    try {
      await _llamafu!.applyLoraAdapter(_loadedLoraAdapter!);
      setState(() {
        _result = 'LoRA adapter applied successfully';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error applying LoRA adapter: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeLoraAdapter() async {
    if (_llamafu == null) {
      setState(() {
        _result = 'Please initialize the model first';
      });
      return;
    }

    if (_loadedLoraAdapter == null) {
      setState(() {
        _result = 'No LoRA adapter loaded';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Removing LoRA adapter...';
    });

    try {
      await _llamafu!.removeLoraAdapter(_loadedLoraAdapter!);
      _loadedLoraAdapter = null;
      setState(() {
        _result = 'LoRA adapter removed';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error removing LoRA adapter: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateWithJsonGrammar() async {
    if (_llamafu == null) {
      setState(() {
        _result = 'Please initialize the model first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _result = 'Generating with JSON grammar...';
    });

    try {
      // Example JSON grammar
      final jsonGrammar = '''
root   ::= object
value  ::= object | array | string | number | (\"true\" | \"false\" | \"null\") ws

object ::=
  \"{\" ws (
            string \":\" ws value
    (\",\" ws string \":\" ws value)*
  )? \"}\" ws

array  ::=
  \"[\" ws (
            value
    (\",\" ws value)*
  )? \"]\" ws

string ::=
  \"\\\"\" (
    [^\\\"\\\\\\x7F\\x00-\\x1F] |
    \"\\\\\" ([\"\\\\bfnrt] | \"u\" [0-9a-fA-F]{4}) # escapes
  )* \"\\\"\" ws

number ::= (\"-\"? ([0-9] | [1-9] [0-9]{0,15})) (\".\" [0-9]+)? ([eE] [-+]? [0-9] [1-9]{0,15})? ws

# Optional space: by convention, applied in this grammar after literal chars when allowed
ws ::= | \" \" | \"\\n\" [ \\t]{0,20}
''';

      final result = await _llamafu!.completeWithGrammar(
        prompt: 'Generate a JSON object describing a person:',
        grammarStr: jsonGrammar,
        grammarRoot: 'root',
        maxTokens: int.tryParse(_maxTokensController.text) ?? 256,
        temperature: double.tryParse(_temperatureController.text) ?? 0.8,
      );

      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = 'Error generating with JSON grammar: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Llamafu Example'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Model Configuration',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _modelPathController,
                      decoration: const InputDecoration(
                        labelText: 'Model Path (.gguf)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mmprojPathController,
                      decoration: const InputDecoration(
                        labelText: 'Multi-modal Projector Path (.gguf) (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _initLlamafu,
                      child: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Initialize Model'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isModelLoaded)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Generation Parameters',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _promptController,
                        decoration: const InputDecoration(
                          labelText: 'Prompt',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _maxTokensController,
                              decoration: const InputDecoration(
                                labelText: 'Max Tokens',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _temperatureController,
                              decoration: const InputDecoration(
                                labelText: 'Temperature',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : _generateText,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Generate Text'),
                          ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _generateMultimodal,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Multi-modal'),
                          ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _generateWithJsonGrammar,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('JSON Grammar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_isModelLoaded)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'LoRA Adapter',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _loraPathController,
                        decoration: const InputDecoration(
                          labelText: 'LoRA Adapter Path (.gguf)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ElevatedButton(
                            onPressed: _isLoading ? null : _loadLoraAdapter,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Load LoRA'),
                          ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _applyLoraAdapter,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Apply LoRA'),
                          ),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _removeLoraAdapter,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('Remove LoRA'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Output',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _result,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}