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
        threads: 4,
        contextSize: 512,
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
              'Enter a prompt to generate text:',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateText,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Generate Text'),
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