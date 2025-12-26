# Inference Options

Parameters for text generation and inference operations.

## InferParams

Parameters for `complete()` and `completeStream()`.

```dart
class InferParams {
  final String prompt;
  final int maxTokens;
  final double temperature;
  final int topK;
  final double topP;
  final double repeatPenalty;
  final int seed;
  final List<String>? stopSequences;
}
```

## Parameter Reference

### `prompt`

The input text to complete.

- **Type:** `String`
- **Required:** Yes

```dart
// Simple prompt
'What is the capital of France?'

// With context
'''Context: Paris is a city in France.
Question: What is the capital of France?
Answer:'''

// With chat format
'<|user|>Hello<|assistant|>'
```

### `maxTokens`

Maximum number of tokens to generate.

- **Type:** `int`
- **Default:** `256`
- **Range:** `1` to context size

| Use Case | Recommended |
|----------|-------------|
| Short answer | 50-100 |
| Paragraph | 150-300 |
| Long response | 500-1000 |
| Maximum | Context size - prompt tokens |

### `temperature`

Controls randomness of output.

- **Type:** `double`
- **Default:** `0.7`
- **Range:** `0.0` to `2.0`

```dart
// Deterministic (greedy)
temperature: 0.0

// Low creativity
temperature: 0.3

// Balanced
temperature: 0.7

// High creativity
temperature: 1.0

// Very random
temperature: 1.5
```

### `topK`

Limits token selection to top K candidates.

- **Type:** `int`
- **Default:** `40`
- **Range:** `1` to vocabulary size

| Value | Effect |
|-------|--------|
| 1 | Greedy (only top token) |
| 10-20 | Focused |
| 40-50 | Balanced |
| 100+ | Wide selection |
| 0 | Disabled |

### `topP`

Nucleus sampling - cumulative probability threshold.

- **Type:** `double`
- **Default:** `0.9`
- **Range:** `0.0` to `1.0`

```dart
// Very focused
topP: 0.5

// Balanced
topP: 0.9

// Wide (almost all tokens)
topP: 0.99

// Disabled
topP: 1.0
```

### `repeatPenalty`

Penalizes repeated tokens.

- **Type:** `double`
- **Default:** `1.1`
- **Range:** `1.0` to `2.0`

| Value | Effect |
|-------|--------|
| 1.0 | No penalty |
| 1.1 | Light penalty |
| 1.2 | Moderate penalty |
| 1.5+ | Strong penalty |

### `seed`

Random seed for reproducibility.

- **Type:** `int`
- **Default:** `0` (random)

```dart
// Reproducible output
final result1 = await llamafu.complete(prompt, seed: 42);
final result2 = await llamafu.complete(prompt, seed: 42);
// result1 == result2 (same seed)
```

### `stopSequences`

Stop generation when encountering these strings.

- **Type:** `List<String>?`
- **Default:** `null`

```dart
await llamafu.complete(
  'List three colors:\n1.',
  stopSequences: ['\n4.', '\n\n'],  // Stop after 3 items
);
```

## Preset Configurations

### Factual Q&A

```dart
await llamafu.complete(
  prompt,
  temperature: 0.1,
  topK: 10,
  topP: 0.9,
  maxTokens: 100,
);
```

### Creative Writing

```dart
await llamafu.complete(
  prompt,
  temperature: 0.9,
  topK: 50,
  topP: 0.95,
  repeatPenalty: 1.2,
  maxTokens: 500,
);
```

### Code Generation

```dart
await llamafu.complete(
  prompt,
  temperature: 0.2,
  topK: 20,
  topP: 0.9,
  repeatPenalty: 1.0,
  maxTokens: 300,
);
```

### Chat/Dialogue

```dart
await llamafu.complete(
  prompt,
  temperature: 0.7,
  topK: 40,
  topP: 0.9,
  repeatPenalty: 1.1,
  maxTokens: 200,
);
```

## Streaming Options

`completeStream()` accepts the same parameters:

```dart
final stream = llamafu.completeStream(
  prompt,
  maxTokens: 200,
  temperature: 0.8,
);

await for (final token in stream) {
  stdout.write(token);
}
```

## Grammar Constraints

For structured output:

```dart
await llamafu.completeWithGrammar(
  'Generate a number:',
  grammar: 'root ::= [0-9]+',
  maxTokens: 10,
  temperature: 0.5,
);
```

## Performance Considerations

### Token Generation Speed

Factors affecting speed:
1. Model size (smaller = faster)
2. Quantization (Q4 faster than Q8)
3. Context length (longer = slower)
4. Temperature (0.0 slightly faster)

### Memory Usage

Each generated token adds to KV cache:
```
Memory per token ≈ 2 × layers × embedding_size × sizeof(float16)
```

### Best Practices

1. Set `maxTokens` appropriately - don't over-allocate
2. Use lower temperature for factual content
3. Enable `stopSequences` when format is known
4. Clear KV cache between unrelated prompts
