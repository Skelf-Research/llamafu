# Samplers API

API reference for sampling configuration.

## SamplerChain

A chain of samplers applied in sequence.

```dart
class SamplerChain {
  void add(Sampler sampler);
  void remove(int index);
  void clear();
  int get length;
  void dispose();
}
```

### Creating a Chain

```dart
final chain = llamafu.createSamplerChain();
chain.add(llamafu.createTopKSampler(40));
chain.add(llamafu.createTempSampler(0.8));
```

### Using a Chain

```dart
final response = await llamafu.completeWithSampler(
  prompt,
  sampler: chain,
  maxTokens: 100,
);
```

### Disposing

```dart
chain.dispose();  // Free native resources
```

## Sampler Factory Methods

All samplers are created through `Llamafu` instance methods.

### Temperature Sampler

Scales logits before softmax.

```dart
Sampler createTempSampler(double temperature)
```

**Parameters:**
- `temperature`: 0.0 (greedy) to 2.0+ (random)

### Top-K Sampler

Keeps only top K tokens.

```dart
Sampler createTopKSampler(int k)
```

**Parameters:**
- `k`: Number of tokens to keep (1 to vocab size)

### Top-P Sampler

Nucleus sampling - keeps tokens until cumulative probability exceeds p.

```dart
Sampler createTopPSampler(double p, {int minKeep = 1})
```

**Parameters:**
- `p`: Probability threshold (0.0 to 1.0)
- `minKeep`: Minimum tokens to keep

### Min-P Sampler

Filters tokens below minimum probability threshold.

```dart
Sampler createMinPSampler(double p, {int minKeep = 1})
```

**Parameters:**
- `p`: Minimum probability relative to top token
- `minKeep`: Minimum tokens to keep

### Typical Sampler

Selects tokens with entropy close to expected.

```dart
Sampler createTypicalSampler(double p, {int minKeep = 1})
```

**Parameters:**
- `p`: Typical probability mass
- `minKeep`: Minimum tokens to keep

### Mirostat Sampler

Maintains target perplexity.

```dart
Sampler createMirostatSampler({
  required double tau,
  required double eta,
  int m = 100,
})
```

**Parameters:**
- `tau`: Target entropy (typically 3.0-5.0)
- `eta`: Learning rate (typically 0.1)
- `m`: Mirostat parameter

### Mirostat V2 Sampler

Improved Mirostat algorithm.

```dart
Sampler createMirostatV2Sampler({
  required double tau,
  required double eta,
})
```

**Parameters:**
- `tau`: Target entropy
- `eta`: Learning rate

### Penalties Sampler

Applies repetition penalties.

```dart
Sampler createPenaltySampler({
  int penaltyLastN = 64,
  double penaltyRepeat = 1.1,
  double penaltyFreq = 0.0,
  double penaltyPresent = 0.0,
})
```

**Parameters:**
- `penaltyLastN`: Tokens to look back
- `penaltyRepeat`: Repeat penalty multiplier
- `penaltyFreq`: Frequency-based penalty
- `penaltyPresent`: Presence-based penalty

### Greedy Sampler

Always selects most likely token.

```dart
Sampler createGreedySampler()
```

## Sampler Order

Samplers are applied in the order added to the chain:

```dart
final chain = llamafu.createSamplerChain();

// Order matters!
chain.add(llamafu.createTopKSampler(50));     // 1. Filter to top 50
chain.add(llamafu.createTopPSampler(0.9));    // 2. Apply nucleus
chain.add(llamafu.createTempSampler(0.8));    // 3. Apply temperature
chain.add(llamafu.createPenaltySampler());    // 4. Apply penalties
```

Recommended order:
1. Top-K (filter by count)
2. Top-P (filter by probability)
3. Min-P (filter by threshold)
4. Temperature (scale)
5. Penalties (adjust for repetition)

## Preset Chains

### Balanced

```dart
SamplerChain createBalancedChain() {
  final chain = llamafu.createSamplerChain();
  chain.add(llamafu.createTopKSampler(40));
  chain.add(llamafu.createTopPSampler(0.9));
  chain.add(llamafu.createTempSampler(0.7));
  chain.add(llamafu.createPenaltySampler(penaltyRepeat: 1.1));
  return chain;
}
```

### Creative

```dart
SamplerChain createCreativeChain() {
  final chain = llamafu.createSamplerChain();
  chain.add(llamafu.createTopPSampler(0.95));
  chain.add(llamafu.createTempSampler(1.0));
  chain.add(llamafu.createPenaltySampler(penaltyRepeat: 1.2));
  return chain;
}
```

### Deterministic

```dart
SamplerChain createDeterministicChain() {
  final chain = llamafu.createSamplerChain();
  chain.add(llamafu.createGreedySampler());
  return chain;
}
```

### Mirostat (Consistent Quality)

```dart
SamplerChain createMirostatChain() {
  final chain = llamafu.createSamplerChain();
  chain.add(llamafu.createMirostatV2Sampler(tau: 5.0, eta: 0.1));
  return chain;
}
```

## Individual Sampler Usage

For simple cases, use built-in parameters:

```dart
// Instead of creating a chain:
await llamafu.complete(
  prompt,
  temperature: 0.8,
  topK: 40,
  topP: 0.9,
  repeatPenalty: 1.1,
);
```

Use sampler chains for:
- Custom sampler combinations
- Mirostat sampling
- Advanced penalty configurations
- Reusable sampling configurations

## Performance

Sampler overhead is generally minimal:

| Sampler | Relative Cost |
|---------|--------------|
| Greedy | 1x (baseline) |
| Temperature | 1.1x |
| Top-K | 1.2x |
| Top-P | 1.3x |
| Mirostat | 1.4x |
| Penalties | 1.5x |

Chain with multiple samplers: costs are additive.
