# Text Generation

Comprehensive guide to text generation with Llamafu.

## Generation Parameters

### Temperature

Controls randomness in output. Higher values produce more creative but less predictable text.

```dart
// Deterministic output
final response = await llamafu.complete(prompt, temperature: 0.0);

// Balanced creativity
final response = await llamafu.complete(prompt, temperature: 0.7);

// Maximum creativity
final response = await llamafu.complete(prompt, temperature: 1.5);
```

| Value | Use Case |
|-------|----------|
| 0.0 | Factual Q&A, code generation |
| 0.3-0.5 | Summarization, translation |
| 0.7-0.9 | Creative writing, chat |
| 1.0+ | Brainstorming, poetry |

### Top-K Sampling

Limits token selection to the K most likely tokens.

```dart
final response = await llamafu.complete(
  prompt,
  topK: 40,  // Consider only top 40 tokens
);
```

### Top-P (Nucleus) Sampling

Selects from the smallest set of tokens whose cumulative probability exceeds P.

```dart
final response = await llamafu.complete(
  prompt,
  topP: 0.9,  // 90% probability mass
);
```

### Combining Samplers

Samplers are applied in order: Top-K → Top-P → Temperature

```dart
final response = await llamafu.complete(
  prompt,
  topK: 50,
  topP: 0.95,
  temperature: 0.8,
);
```

## Repetition Control

### Repeat Penalty

Penalizes tokens that have appeared recently.

```dart
final response = await llamafu.complete(
  prompt,
  repeatPenalty: 1.1,  // Slight penalty (1.0 = no penalty)
);
```

### Frequency and Presence Penalties

Fine-grained control over repetition:

```dart
final sampler = llamafu.createPenaltySampler(
  penaltyLastN: 64,       // Look back 64 tokens
  penaltyRepeat: 1.1,     // Repeat penalty
  penaltyFreq: 0.1,       // Frequency penalty
  penaltyPresent: 0.1,    // Presence penalty
);
```

## Structured Output

### JSON Output

```dart
final json = llamafu.generateStructured(
  'Generate a user profile with name and age',
  format: OutputFormat.json,
  prettyPrint: true,
);
// Output: {"name": "Alice", "age": 28}
```

### Grammar-Constrained Generation

Use GBNF grammar to constrain output format:

```dart
final grammar = '''
root ::= object
object ::= "{" pair ("," pair)* "}"
pair ::= string ":" value
string ::= "\\"" [a-zA-Z]+ "\\""
value ::= string | number
number ::= [0-9]+
''';

final response = await llamafu.completeWithGrammar(
  'Generate a key-value pair:',
  grammar: grammar,
  maxTokens: 50,
);
```

## Stop Sequences

Stop generation when specific sequences are encountered:

```dart
final response = await llamafu.complete(
  'List three fruits:\n1.',
  maxTokens: 100,
  stopSequences: ['\n4.', '\n\n'],  // Stop after 3 items
);
```

## Streaming Generation

### Basic Streaming

```dart
await for (final token in llamafu.completeStream(prompt)) {
  stdout.write(token);
}
```

### With Progress Callback

```dart
int tokenCount = 0;

await for (final token in llamafu.completeStream(prompt)) {
  tokenCount++;
  updateUI(token, tokenCount);
}
```

### Cancellable Streaming

```dart
bool cancelled = false;

llamafu.setAbortCallback(() => cancelled);

final stream = llamafu.completeStream(prompt);

// In UI
void onCancelPressed() {
  cancelled = true;
}
```

## Batch Processing

Generate multiple completions efficiently:

```dart
final prompts = [
  'Translate to French: Hello',
  'Translate to French: Goodbye',
  'Translate to French: Thank you',
];

final responses = <String>[];
for (final prompt in prompts) {
  responses.add(await llamafu.complete(prompt, maxTokens: 20));
}
```

## Embeddings

Extract text embeddings for similarity search:

```dart
final embeddings = llamafu.getEmbeddings('Hello, world!');
print('Embedding dimension: ${embeddings.length}');
print('First 5 values: ${embeddings.take(5)}');
```

## Performance Tips

### 1. Set Appropriate Max Tokens

```dart
// Don't set higher than needed
final response = await llamafu.complete(
  'What is 2+2?',
  maxTokens: 10,  // Short answer expected
);
```

### 2. Use Seed for Reproducibility

```dart
final response = await llamafu.complete(
  prompt,
  seed: 42,
  temperature: 0.7,
);
// Same seed + temperature = same output
```

### 3. Warm Up Before Benchmarking

```dart
await llamafu.warmup();
final stats = llamafu.benchmark(promptTokens: 128, generatedTokens: 128);
print('Tokens/second: ${stats.tokensPerSecond}');
```

## Common Patterns

### Question Answering

```dart
final qa = '''
Context: The Eiffel Tower is located in Paris, France.
Question: Where is the Eiffel Tower?
Answer:''';

final answer = await llamafu.complete(qa, maxTokens: 50, temperature: 0.1);
```

### Text Summarization

```dart
final summary = await llamafu.summarize(
  longText,
  maxLength: 100,
);
```

### Code Generation

```dart
final code = await llamafu.complete(
  '# Python function to calculate fibonacci\ndef fibonacci(n):',
  maxTokens: 200,
  temperature: 0.2,
  stopSequences: ['\n\n', '# '],
);
```

## Next Steps

- [Chat Sessions](chat-sessions.md) - Multi-turn conversations
- [Samplers](samplers.md) - Advanced sampling configuration
- [Performance](performance.md) - Optimization techniques
