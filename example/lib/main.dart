import 'package:flutter/material.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Llamafu Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Llamafu Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Llamafu _llamafu;
  String _result = '';
  bool _isLoading = false;
  LoraAdapter? _loadedLoraAdapter;
  GrammarSampler? _grammarSampler;

  @override
  void initState() {
    super.initState();
    _initLlamafu();
  }

  Future<void> _initLlamafu() async {
    try {
      // TODO: Replace with actual model path
      _llamafu = await Llamafu.init(
        modelPath: '/path/to/your/model.gguf',
        mmprojPath: '/path/to/your/mmproj.gguf', // Multi-modal projector file
        threads: 4,
        contextSize: 512,
        useGpu: false,
      );
    } catch (e) {
      setState(() {
        _result = 'Failed to initialize Llamafu: $e';
      });
    }
  }

  Future<void> _generateText() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final result = await _llamafu.complete(
        prompt: 'The quick brown fox',
        maxTokens: 128,
        temperature: 0.8,
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
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // Example of multi-modal inference with an image
      final mediaInputs = [
        MediaInput(
          type: MediaType.image,
          data: '/path/to/your/image.jpg', // Path to image file
        ),
      ];

      final result = await _llamafu.multimodalComplete(
        prompt: 'Describe this image: <image>',
        mediaInputs: mediaInputs,
        maxTokens: 128,
        temperature: 0.8,
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
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // Load a LoRA adapter
      _loadedLoraAdapter = await _llamafu.loadLoraAdapter('/path/to/your/lora.gguf');
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
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      if (_loadedLoraAdapter != null) {
        await _llamafu.applyLoraAdapter(_loadedLoraAdapter!, scale: 0.5);
        setState(() {
          _result = 'LoRA adapter applied with scale 0.5';
          _isLoading = false;
        });
      } else {
        setState(() {
          _result = 'No LoRA adapter loaded';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error applying LoRA adapter: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeLoraAdapter() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      if (_loadedLoraAdapter != null) {
        await _llamafu.removeLoraAdapter(_loadedLoraAdapter!);
        setState(() {
          _result = 'LoRA adapter removed';
          _isLoading = false;
        });
      } else {
        setState(() {
          _result = 'No LoRA adapter loaded';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error removing LoRA adapter: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateWithJsonGrammar() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      // Example JSON grammar
      final jsonGrammar = '''
root   ::= object
value  ::= object | array | string | number | ("true" | "false" | "null") ws

object ::=
  "{" ws (
            string ":" ws value
    ("," ws string ":" ws value)*
  )? "}" ws

array  ::=
  "[" ws (
            value
    ("," ws value)*
  )? "]" ws

string ::=
  "\\"" (
    [^\\"\\\\\x7F\x00-\x1F] |
    "\\\\" (["\\\\bfnrt] | "u" [0-9a-fA-F]{4}) # escapes
  )* "\\"" ws

number ::= ("-"? ([0-9] | [1-9] [0-9]{0,15})) ("." [0-9]+)? ([eE] [-+]? [0-9] [1-9]{0,15})? ws

# Optional space: by convention, applied in this grammar after literal chars when allowed
ws ::= | " " | "\n" [ \t]{0,20}
''';

      final result = await _llamafu.completeWithGrammar(
        prompt: 'Generate a JSON object describing a person:',
        grammarStr: jsonGrammar,
        grammarRoot: 'root',
        maxTokens: 256,
        temperature: 0.8,
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
  void dispose() {
    _llamafu.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Select an operation:',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateText,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Generate Text'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateMultimodal,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Multi-modal'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _loadLoraAdapter,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Load LoRA'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _applyLoraAdapter,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Apply LoRA'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _removeLoraAdapter,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Remove LoRA'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateWithJsonGrammar,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('JSON Grammar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}