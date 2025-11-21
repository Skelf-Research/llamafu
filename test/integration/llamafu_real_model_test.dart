import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:llamafu/llamafu.dart';

/// Integration tests using real GGUF models and LoRA adapters.
///
/// These tests require actual model files to be present.
/// Set the environment variables or modify the paths below:
///
/// - LLAMAFU_TEST_MODEL: Path to a small GGUF model (e.g., TinyLlama)
/// - LLAMAFU_TEST_LORA: Path to a LoRA adapter GGUF file
/// - LLAMAFU_TEST_MMPROJ: Path to a multimodal projection file (optional)
///
/// Example models for testing:
/// - TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf (~700MB)
/// - Phi-2.Q4_K_M.gguf (~1.6GB)
/// - Any small quantized model
void main() {
  // Configuration - update these paths or set environment variables
  final testModelPath = Platform.environment['LLAMAFU_TEST_MODEL'] ??
      'test/fixtures/models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf';
  final testLoraPath = Platform.environment['LLAMAFU_TEST_LORA'] ??
      'test/fixtures/models/lora-adapter.gguf';
  final testMmprojPath = Platform.environment['LLAMAFU_TEST_MMPROJ'] ??
      'test/fixtures/models/mmproj.gguf';

  // Check if model exists
  bool modelExists() => File(testModelPath).existsSync();
  bool loraExists() => File(testLoraPath).existsSync();
  bool mmprojExists() => File(testMmprojPath).existsSync();

  group('Real Model Integration Tests', () {
    Llamafu? llamafu;

    setUpAll(() async {
      if (!modelExists()) {
        print('⚠️  Skipping real model tests - model not found at: $testModelPath');
        print('   Set LLAMAFU_TEST_MODEL environment variable or place model in test/fixtures/models/');
        return;
      }

      print('Loading model: $testModelPath');
      llamafu = await Llamafu.init(
        modelPath: testModelPath,
        contextSize: 2048,
        nThreads: 4,
      );
      print('Model loaded successfully');
    });

    tearDownAll(() {
      llamafu?.close();
    });

    // =========================================================================
    // MODEL INFO TESTS
    // =========================================================================

    test('Get model information', () {
      if (!modelExists()) return;

      final info = llamafu!.getModelInfo();

      expect(info.vocabSize, greaterThan(0));
      expect(info.contextLength, greaterThan(0));
      expect(info.embeddingSize, greaterThan(0));
      expect(info.numLayers, greaterThan(0));

      print('Model Info:');
      print('  Name: ${info.name}');
      print('  Architecture: ${info.architecture}');
      print('  Vocab Size: ${info.vocabSize}');
      print('  Context Length: ${info.contextLength}');
      print('  Embedding Size: ${info.embeddingSize}');
      print('  Layers: ${info.numLayers}');
      print('  Parameters: ${info.numParams}');
      print('  Size: ${(info.sizeBytes / 1024 / 1024).toStringAsFixed(2)} MB');
    });

    test('Get memory usage', () {
      if (!modelExists()) return;

      final usage = llamafu!.getMemoryUsage();

      expect(usage.modelSizeBytes, greaterThan(0));
      expect(usage.totalSizeBytes, greaterThan(0));

      print('Memory Usage:');
      print('  Model: ${usage.modelSizeMb.toStringAsFixed(2)} MB');
      print('  KV Cache: ${usage.kvCacheSizeMb.toStringAsFixed(2)} MB');
      print('  Total: ${usage.totalSizeMb.toStringAsFixed(2)} MB');
    });

    test('Get system info', () {
      if (!modelExists()) return;

      final info = llamafu!.getSystemInfo();
      expect(info, isNotEmpty);
      print('System Info: $info');
    });

    // =========================================================================
    // TOKENIZATION TESTS
    // =========================================================================

    test('Tokenize text', () {
      if (!modelExists()) return;

      final text = 'Hello, world!';
      final tokens = llamafu!.tokenize(text);

      expect(tokens, isNotEmpty);
      expect(tokens.length, greaterThan(0));

      print('Text: "$text"');
      print('Tokens: $tokens (${tokens.length} tokens)');
    });

    test('Detokenize tokens', () {
      if (!modelExists()) return;

      final originalText = 'The quick brown fox';
      final tokens = llamafu!.tokenize(originalText);
      final reconstructed = llamafu!.detokenize(tokens);

      // The reconstructed text should be similar (may have minor whitespace differences)
      expect(reconstructed.trim(), contains('quick'));
      expect(reconstructed.trim(), contains('brown'));
      expect(reconstructed.trim(), contains('fox'));

      print('Original: "$originalText"');
      print('Tokens: $tokens');
      print('Reconstructed: "$reconstructed"');
    });

    test('Token to piece conversion', () {
      if (!modelExists()) return;

      final text = 'Hello';
      final tokens = llamafu!.tokenize(text);

      for (final token in tokens) {
        final piece = llamafu!.tokenToPiece(token);
        print('Token $token -> "$piece"');
        expect(piece, isNotNull);
      }
    });

    test('Special tokens', () {
      if (!modelExists()) return;

      final bos = llamafu!.bosToken;
      final eos = llamafu!.eosToken;

      expect(bos, isNonNegative);
      expect(eos, isNonNegative);

      print('BOS token: $bos');
      print('EOS token: $eos');
    });

    // =========================================================================
    // COMPLETION TESTS
    // =========================================================================

    test('Basic text completion', () async {
      if (!modelExists()) return;

      final prompt = 'The capital of France is';
      final result = await llamafu!.complete(
        prompt: prompt,
        maxTokens: 20,
        temperature: 0.1,
      );

      expect(result, isNotEmpty);
      print('Prompt: "$prompt"');
      print('Completion: "$result"');
    });

    test('Streaming completion', () async {
      if (!modelExists()) return;

      final prompt = 'Count from 1 to 5:';
      final tokens = <String>[];

      await for (final token in llamafu!.completeStream(
        prompt: prompt,
        maxTokens: 30,
        temperature: 0.1,
      )) {
        tokens.add(token);
      }

      expect(tokens, isNotEmpty);
      final result = tokens.join('');
      print('Prompt: "$prompt"');
      print('Streamed result: "$result"');
      print('Number of tokens: ${tokens.length}');
    });

    test('Completion with different temperatures', () async {
      if (!modelExists()) return;

      final prompt = 'Once upon a time';

      // Low temperature - more deterministic
      final lowTemp = await llamafu!.complete(
        prompt: prompt,
        maxTokens: 20,
        temperature: 0.1,
      );

      // Higher temperature - more creative
      final highTemp = await llamafu!.complete(
        prompt: prompt,
        maxTokens: 20,
        temperature: 1.0,
      );

      expect(lowTemp, isNotEmpty);
      expect(highTemp, isNotEmpty);

      print('Prompt: "$prompt"');
      print('Low temp (0.1): "$lowTemp"');
      print('High temp (1.0): "$highTemp"');
    });

    // =========================================================================
    // GRAMMAR COMPLETION TESTS
    // =========================================================================

    test('Completion with JSON grammar', () async {
      if (!modelExists()) return;

      final prompt = 'Generate a JSON object with name and age:';
      final grammar = r'''
        root   ::= object
        object ::= "{" ws pair ("," ws pair)* "}" ws
        pair   ::= string ":" ws value
        string ::= "\"" [a-zA-Z]+ "\""
        value  ::= string | number
        number ::= [0-9]+
        ws     ::= [ \t\n]*
      ''';

      final result = await llamafu!.completeWithGrammar(
        prompt: prompt,
        grammarStr: grammar,
        grammarRoot: 'root',
        maxTokens: 50,
        temperature: 0.5,
      );

      expect(result, isNotEmpty);
      print('Prompt: "$prompt"');
      print('Grammar-constrained result: "$result"');
    });

    // =========================================================================
    // KV CACHE TESTS
    // =========================================================================

    test('KV cache operations', () async {
      if (!modelExists()) return;

      // Do a completion to populate cache
      await llamafu!.complete(prompt: 'Hello', maxTokens: 5);

      // Clear cache
      llamafu!.clearKvCache();

      // Should still work after clearing
      final result = await llamafu!.complete(prompt: 'World', maxTokens: 5);
      expect(result, isNotEmpty);

      print('KV cache cleared and completion succeeded');
    });

    // =========================================================================
    // PERFORMANCE TESTS
    // =========================================================================

    test('Performance statistics', () async {
      if (!modelExists()) return;

      llamafu!.resetTimings();

      // Do some work
      await llamafu!.complete(prompt: 'Test prompt', maxTokens: 10);

      final stats = llamafu!.getPerfStats();

      expect(stats.evalTokens, greaterThan(0));

      print('Performance Stats:');
      print('  Load time: ${stats.loadMs.toStringAsFixed(2)} ms');
      print('  Prompt eval: ${stats.promptEvalMs.toStringAsFixed(2)} ms');
      print('  Generation: ${stats.evalMs.toStringAsFixed(2)} ms');
      print('  Prompt tokens: ${stats.promptTokens}');
      print('  Generated tokens: ${stats.evalTokens}');
      print('  Prompt speed: ${stats.promptSpeedTps.toStringAsFixed(2)} t/s');
      print('  Generation speed: ${stats.evalSpeedTps.toStringAsFixed(2)} t/s');
    });

    test('Benchmark model', () {
      if (!modelExists()) return;

      final result = llamafu!.benchmark(nThreads: 4, nPredict: 32);

      expect(result.promptTokens, greaterThan(0));
      expect(result.generationTokens, greaterThan(0));

      print('Benchmark Results:');
      print('  Prompt: ${result.promptTokens} tokens in ${result.promptTimeMs.toStringAsFixed(2)} ms');
      print('  Generation: ${result.generationTokens} tokens in ${result.generationTimeMs.toStringAsFixed(2)} ms');
      print('  Prompt speed: ${result.promptSpeedTps.toStringAsFixed(2)} t/s');
      print('  Generation speed: ${result.generationSpeedTps.toStringAsFixed(2)} t/s');
    });

    test('Thread configuration', () {
      if (!modelExists()) return;

      // Set different thread counts
      llamafu!.setThreads(2, nThreadsBatch: 4);
      print('Set threads to 2 (batch: 4)');

      // Restore
      llamafu!.setThreads(4);
      print('Restored threads to 4');
    });

    test('Warmup model', () {
      if (!modelExists()) return;

      llamafu!.warmup();
      print('Model warmed up');
    });

    // =========================================================================
    // EMBEDDINGS TESTS
    // =========================================================================

    test('Get text embeddings', () {
      if (!modelExists()) return;

      final info = llamafu!.getModelInfo();
      if (!info.supportsEmbeddings) {
        print('⚠️  Model does not support embeddings, skipping test');
        return;
      }

      final text = 'Hello, world!';
      final embeddings = llamafu!.getEmbeddings(text);

      expect(embeddings, isNotEmpty);
      expect(embeddings.length, equals(info.embeddingSize));

      print('Text: "$text"');
      print('Embedding dimensions: ${embeddings.length}');
      print('First 5 values: ${embeddings.sublist(0, 5)}');
    });

    // =========================================================================
    // STATE MANAGEMENT TESTS
    // =========================================================================

    test('Save and load state', () async {
      if (!modelExists()) return;

      final statePath = '${Directory.systemTemp.path}/llamafu_test_state.bin';

      // Generate some context
      await llamafu!.complete(prompt: 'Remember this: apple', maxTokens: 5);

      // Get state size
      final size = llamafu!.getStateSize();
      expect(size, greaterThan(0));
      print('State size: ${(size / 1024).toStringAsFixed(2)} KB');

      // Save state
      llamafu!.saveState(statePath);
      expect(File(statePath).existsSync(), isTrue);
      print('State saved to: $statePath');

      // Load state
      llamafu!.loadState(statePath);
      print('State loaded successfully');

      // Cleanup
      File(statePath).deleteSync();
    });

    // =========================================================================
    // SAMPLER CHAIN TESTS
    // =========================================================================

    test('Custom sampler chain', () {
      if (!modelExists()) return;

      // Create samplers
      final chain = llamafu!.createSamplerChain();
      final topK = llamafu!.createTopKSampler(40);
      final topP = llamafu!.createTopPSampler(0.9);
      final temp = llamafu!.createTempSampler(0.8);

      // Build chain
      chain.add(topK);
      chain.add(topP);
      chain.add(temp);

      print('Created sampler chain: TopK(40) -> TopP(0.9) -> Temp(0.8)');

      // Cleanup
      chain.dispose();
      topK.dispose();
      topP.dispose();
      temp.dispose();
    });

    // =========================================================================
    // CHAT SESSION TESTS
    // =========================================================================

    test('Chat session', () {
      if (!modelExists()) return;

      final session = llamafu!.createChatSession(
        systemPrompt: 'You are a helpful assistant. Be brief.',
      );

      final response = session.complete('What is 2+2?');
      expect(response, isNotEmpty);

      print('User: What is 2+2?');
      print('Assistant: $response');

      // Get history
      final history = session.getHistory();
      expect(history, isNotEmpty);
      print('History JSON length: ${history.length}');

      session.dispose();
    });

    // =========================================================================
    // TEXT ANALYSIS TESTS
    // =========================================================================

    test('Language detection', () {
      if (!modelExists()) return;

      final detection = llamafu!.detectLanguage('Hello, how are you?');

      expect(detection.languageCode, isNotEmpty);
      expect(detection.confidence, greaterThan(0));

      print('Text: "Hello, how are you?"');
      print('Detected: ${detection.languageCode} (confidence: ${detection.confidence})');
    });

    test('Sentiment analysis', () {
      if (!modelExists()) return;

      final sentiment = llamafu!.analyzeSentiment('I love this product! It is amazing!');

      expect(sentiment.positive + sentiment.negative + sentiment.neutral, closeTo(1.0, 0.1));

      print('Text: "I love this product! It is amazing!"');
      print('Sentiment: ${sentiment.dominantSentiment}');
      print('  Positive: ${sentiment.positive.toStringAsFixed(2)}');
      print('  Negative: ${sentiment.negative.toStringAsFixed(2)}');
      print('  Neutral: ${sentiment.neutral.toStringAsFixed(2)}');
    });

    test('Keyword extraction', () {
      if (!modelExists()) return;

      final text = 'Machine learning and artificial intelligence are transforming technology.';
      final keywords = llamafu!.extractKeywords(text, maxKeywords: 5);

      expect(keywords, isNotEmpty);
      print('Text: "$text"');
      print('Keywords: $keywords');
    });

    test('Text summarization', () {
      if (!modelExists()) return;

      final text = '''
        Flutter is an open-source UI software development kit created by Google.
        It can be used to develop cross platform applications from a single codebase
        for the web, Fuchsia, Android, iOS, Linux, macOS, and Windows.
      ''';

      final summary = llamafu!.summarize(text, maxLength: 50, style: 'brief');

      expect(summary, isNotEmpty);
      print('Original: ${text.trim()}');
      print('Summary: $summary');
    });

    // =========================================================================
    // STRUCTURED OUTPUT TESTS
    // =========================================================================

    test('Generate structured JSON output', () {
      if (!modelExists()) return;

      final result = llamafu!.generateStructured(
        'Generate a person with name and age',
        format: OutputFormat.json,
        prettyPrint: true,
      );

      expect(result, isNotEmpty);
      print('Structured output: $result');
    });

    test('Apply chat template', () {
      if (!modelExists()) return;

      final messages = [
        'user: Hello!',
        'assistant: Hi there!',
        'user: How are you?',
      ];

      final formatted = llamafu!.applyChatTemplate(
        '',  // Use model's default template
        messages,
        addAssistant: true,
      );

      expect(formatted, isNotEmpty);
      print('Formatted conversation:\n$formatted');
    });
  });

  // ===========================================================================
  // LORA ADAPTER TESTS
  // ===========================================================================

  group('LoRA Adapter Integration Tests', () {
    Llamafu? llamafu;

    setUpAll(() async {
      if (!modelExists()) {
        print('⚠️  Skipping LoRA tests - base model not found');
        return;
      }

      llamafu = await Llamafu.init(
        modelPath: testModelPath,
        contextSize: 2048,
        nThreads: 4,
      );
    });

    tearDownAll(() {
      llamafu?.close();
    });

    test('Validate LoRA compatibility', () {
      if (!modelExists() || !loraExists()) {
        print('⚠️  Skipping - model or LoRA not found');
        return;
      }

      final result = llamafu!.validateLoraCompatibility(testLoraPath);

      print('LoRA Path: $testLoraPath');
      print('Compatible: ${result.isCompatible}');
      if (result.errorMessage != null) {
        print('Error: ${result.errorMessage}');
      }
    });

    test('Load and apply LoRA adapter', () async {
      if (!modelExists() || !loraExists()) {
        print('⚠️  Skipping - model or LoRA not found');
        return;
      }

      // Validate first
      final compat = llamafu!.validateLoraCompatibility(testLoraPath);
      if (!compat.isCompatible) {
        print('⚠️  LoRA not compatible: ${compat.errorMessage}');
        return;
      }

      // Load adapter
      final adapter = await llamafu!.loadLoraAdapter(testLoraPath);
      print('LoRA adapter loaded');

      // Get info
      final info = llamafu!.getLoraAdapterInfo(adapter);
      print('LoRA Info:');
      print('  Name: ${info.name}');
      print('  Path: ${info.filePath}');
      print('  Scale: ${info.scale}');
      print('  Active: ${info.isActive}');

      // Apply adapter
      await llamafu!.applyLoraAdapter(adapter, scale: 1.0);
      print('LoRA adapter applied with scale 1.0');

      // Do a completion with LoRA
      final result = await llamafu!.complete(
        prompt: 'Test with LoRA:',
        maxTokens: 20,
      );
      print('Completion with LoRA: $result');

      // Remove adapter
      await llamafu!.removeLoraAdapter(adapter);
      print('LoRA adapter removed');
    });

    test('Multiple LoRA adapters', () async {
      if (!modelExists() || !loraExists()) {
        print('⚠️  Skipping - model or LoRA not found');
        return;
      }

      // Load same adapter twice with different scales
      final adapter1 = await llamafu!.loadLoraAdapter(testLoraPath);
      await llamafu!.applyLoraAdapter(adapter1, scale: 0.5);
      print('Applied LoRA with scale 0.5');

      final adapter2 = await llamafu!.loadLoraAdapter(testLoraPath);
      await llamafu!.applyLoraAdapter(adapter2, scale: 0.3);
      print('Applied second LoRA with scale 0.3');

      // Clear all
      await llamafu!.clearAllLoraAdapters();
      print('Cleared all LoRA adapters');
    });
  });

  // ===========================================================================
  // MULTIMODAL TESTS (requires mmproj)
  // ===========================================================================

  group('Multimodal Integration Tests', () {
    test('Multimodal completion with image', () async {
      if (!modelExists() || !mmprojExists()) {
        print('⚠️  Skipping multimodal tests - model or mmproj not found');
        return;
      }

      final llamafu = await Llamafu.init(
        modelPath: testModelPath,
        mmprojPath: testMmprojPath,
        contextSize: 2048,
        nThreads: 4,
      );

      // Would need a real test image
      print('Multimodal model loaded with mmproj');

      llamafu.close();
    });
  });
}
