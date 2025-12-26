# Samplers & Parameters

Advanced sampling configuration for fine-grained control over text generation.

## Sampling Overview

Sampling determines how the next token is selected from the model's probability distribution:

```
Model Output → Logits → Sampling Chain → Selected Token
```

Llamafu supports building custom sampler chains for precise control.

## Built-in Samplers

### Temperature

Scales logits before softmax. Higher values increase randomness.

```dart
final sampler = llamafu.createTempSampler(0.8);
```

| Value | Effect |
|-------|--------|
| 0.0 | Greedy (deterministic) |
| 0.1-0.5 | Focused, predictable |
| 0.7-0.9 | Balanced |
| 1.0+ | Creative, random |

### Top-K

Keeps only the K most likely tokens.

```dart
final sampler = llamafu.createTopKSampler(40);
```

### Top-P (Nucleus)

Keeps tokens until cumulative probability exceeds P.

```dart
final sampler = llamafu.createTopPSampler(0.9);
```

### Min-P

Filters tokens below a minimum probability threshold (relative to top token).

```dart
final sampler = llamafu.createMinPSampler(0.05);
```

### Typical

Selects tokens with entropy close to the expected entropy.

```dart
final sampler = llamafu.createTypicalSampler(0.95);
```

### Mirostat

Maintains a target perplexity for consistent output quality.

```dart
// Mirostat v1
final sampler = llamafu.createMirostatSampler(
  tau: 5.0,    // Target entropy
  eta: 0.1,    // Learning rate
);

// Mirostat v2 (recommended)
final sampler = llamafu.createMirostatV2Sampler(
  tau: 5.0,
  eta: 0.1,
);
```

## Repetition Control

### Penalties Sampler

```dart
final sampler = llamafu.createPenaltySampler(
  penaltyLastN: 64,        // Tokens to look back
  penaltyRepeat: 1.1,      // Repeat penalty
  penaltyFreq: 0.0,        // Frequency penalty
  penaltyPresent: 0.0,     // Presence penalty
);
```

| Parameter | Effect |
|-----------|--------|
| `penaltyRepeat` | Penalizes exact token repetition |
| `penaltyFreq` | Penalizes based on frequency count |
| `penaltyPresent` | Penalizes any occurrence |

## Sampler Chains

Combine multiple samplers for custom behavior:

```dart
final chain = llamafu.createSamplerChain();

// Add samplers in order of application
chain.add(llamafu.createTopKSampler(50));      // Filter to top 50
chain.add(llamafu.createTopPSampler(0.9));     // Then nucleus sampling
chain.add(llamafu.createTempSampler(0.8));     // Then temperature

// Use the chain
final response = await llamafu.completeWithSampler(
  'Write a story:',
  sampler: chain,
  maxTokens: 200,
);

// Clean up
chain.dispose();
```

### Recommended Chains

=== "Balanced (General Purpose)"
    ```dart
    final chain = llamafu.createSamplerChain();
    chain.add(llamafu.createTopKSampler(40));
    chain.add(llamafu.createTopPSampler(0.9));
    chain.add(llamafu.createTempSampler(0.7));
    chain.add(llamafu.createPenaltySampler(penaltyRepeat: 1.1));
    ```

=== "Creative Writing"
    ```dart
    final chain = llamafu.createSamplerChain();
    chain.add(llamafu.createTopPSampler(0.95));
    chain.add(llamafu.createTempSampler(1.0));
    chain.add(llamafu.createPenaltySampler(penaltyRepeat: 1.2));
    ```

=== "Factual/Deterministic"
    ```dart
    final chain = llamafu.createSamplerChain();
    chain.add(llamafu.createTopKSampler(10));
    chain.add(llamafu.createTempSampler(0.1));
    ```

=== "Mirostat (Consistent Quality)"
    ```dart
    final chain = llamafu.createSamplerChain();
    chain.add(llamafu.createMirostatV2Sampler(tau: 5.0, eta: 0.1));
    ```

## Sampling Parameters Explained

### Temperature vs Top-P vs Top-K

```
Original distribution: [0.4, 0.3, 0.15, 0.1, 0.05]

Top-K=3:              [0.4, 0.3, 0.15, 0, 0] → renormalized
Top-P=0.85:           [0.4, 0.3, 0.15, 0, 0] → cumsum stops at 0.85
Temperature=2.0:      [0.25, 0.22, 0.19, 0.17, 0.17] → flattened
```

### When to Use Each

| Scenario | Recommended Settings |
|----------|---------------------|
| Code generation | temp=0.2, top_k=10 |
| Factual Q&A | temp=0.3, top_p=0.9 |
| Chat/dialogue | temp=0.7, top_p=0.9, rep_pen=1.1 |
| Creative writing | temp=0.9, top_p=0.95, rep_pen=1.2 |
| Brainstorming | temp=1.2, top_p=0.95 |

## Seed for Reproducibility

```dart
final response1 = await llamafu.complete(
  prompt,
  seed: 42,
  temperature: 0.7,
);

final response2 = await llamafu.complete(
  prompt,
  seed: 42,
  temperature: 0.7,
);

// response1 == response2 (same seed = same output)
```

!!! note
    Reproducibility requires identical: seed, temperature, all sampler parameters, and model state.

## Grammar Sampling

Constrain output to match a grammar:

```dart
// JSON grammar
final grammar = '''
root ::= object
object ::= "{" ws pair ("," ws pair)* ws "}"
pair ::= string ":" ws value
string ::= "\\"" [^"\\\\]* "\\""
value ::= string | number | object
number ::= [0-9]+
ws ::= [ \\t\\n]*
''';

final response = await llamafu.completeWithGrammar(
  'Generate a JSON object:',
  grammar: grammar,
);
// Guaranteed valid JSON output
```

### Common Grammars

=== "JSON"
    ```
    root ::= object | array
    object ::= "{" (pair ("," pair)*)? "}"
    array ::= "[" (value ("," value)*)? "]"
    pair ::= string ":" value
    value ::= string | number | object | array | "true" | "false" | "null"
    string ::= "\"" [^"\\]* "\""
    number ::= "-"? [0-9]+ ("." [0-9]+)?
    ```

=== "Yes/No"
    ```
    root ::= "yes" | "no"
    ```

=== "Rating (1-5)"
    ```
    root ::= [1-5]
    ```

## Performance Impact

Sampler overhead by type:

| Sampler | Overhead | Notes |
|---------|----------|-------|
| Temperature | Minimal | Simple scaling |
| Top-K | Low | Sorting required |
| Top-P | Low | Cumsum + filter |
| Min-P | Minimal | Simple threshold |
| Mirostat | Low | State tracking |
| Penalties | Medium | Token lookup |
| Grammar | High | Parse at each step |

## Debugging Samplers

### Get Token Probabilities

```dart
final probs = llamafu.getTokenProbabilities(prompt);
for (final (token, prob) in probs.take(10)) {
  print('${llamafu.tokenToPiece(token)}: ${(prob * 100).toStringAsFixed(2)}%');
}
```

### Visualize Sampling Effect

```dart
// Compare outputs with different settings
for (final temp in [0.1, 0.5, 0.9, 1.2]) {
  final response = await llamafu.complete(
    prompt,
    temperature: temp,
    seed: 42,
  );
  print('temp=$temp: $response');
}
```

## Next Steps

- [Performance Tuning](performance.md)
- [API: Samplers](../api/samplers.md)
- [Text Generation](text-generation.md)
