# LoRA Adapters

LoRA (Low-Rank Adaptation) adapters allow you to customize model behavior without modifying the base model weights.

## What is LoRA?

LoRA is a technique for fine-tuning large language models efficiently:

- **Small file size** - Adapters are typically 10-100MB vs multi-GB base models
- **Hot-swappable** - Load/unload adapters at runtime
- **Stackable** - Combine multiple adapters
- **Scalable** - Adjust adapter influence with scaling factor

## Loading an Adapter

### Basic Loading

```dart
final adapter = await llamafu.loadLoraAdapter(
  'adapters/coding-assistant.gguf',
  scale: 1.0,  // Full strength
);

print('Adapter loaded: ${adapter.id}');
```

### With Custom Scale

```dart
// Half strength
final adapter = await llamafu.loadLoraAdapter(
  'adapters/style.gguf',
  scale: 0.5,
);
```

## Managing Adapters

### List Loaded Adapters

```dart
final adapters = llamafu.getLoadedAdapters();
for (final adapter in adapters) {
  print('${adapter.name}: scale=${adapter.scale}');
}
```

### Adjust Scale at Runtime

```dart
llamafu.setLoraScale(adapter.id, 0.8);
```

### Unload Adapter

```dart
llamafu.unloadLoraAdapter(adapter.id);
```

### Unload All Adapters

```dart
llamafu.clearLoraAdapters();
```

## Multiple Adapters

### Stacking Adapters

Load multiple adapters for combined effects:

```dart
final styleAdapter = await llamafu.loadLoraAdapter(
  'adapters/formal-style.gguf',
  scale: 0.7,
);

final domainAdapter = await llamafu.loadLoraAdapter(
  'adapters/medical-knowledge.gguf',
  scale: 1.0,
);

// Both adapters are now active
final response = await llamafu.complete(
  'Explain the symptoms of flu',
);
// Uses medical knowledge with formal writing style
```

### Priority and Order

Adapters are applied in the order they were loaded:

```dart
// Loaded first = applied first
await llamafu.loadLoraAdapter('adapter1.gguf');
await llamafu.loadLoraAdapter('adapter2.gguf');
```

## Checking Compatibility

### Validate Before Loading

```dart
final isCompatible = await llamafu.validateLoraCompatibility(
  'adapters/my-adapter.gguf',
);

if (isCompatible) {
  await llamafu.loadLoraAdapter('adapters/my-adapter.gguf');
} else {
  print('Adapter is not compatible with this model');
}
```

### Compatibility Requirements

For an adapter to be compatible:

1. **Architecture match** - Adapter must be trained for the same model architecture
2. **Dimension match** - Hidden dimensions must match base model
3. **Layer compatibility** - Target layers must exist in base model

## Common Use Cases

### Style Transfer

```dart
// Switch between writing styles
final formalAdapter = await llamafu.loadLoraAdapter('formal.gguf');

final response1 = await llamafu.complete('Hello');
// "Greetings and salutations..."

llamafu.unloadLoraAdapter(formalAdapter.id);
final casualAdapter = await llamafu.loadLoraAdapter('casual.gguf');

final response2 = await llamafu.complete('Hello');
// "Hey there! What's up?"
```

### Domain Specialization

```dart
// Medical assistant
await llamafu.loadLoraAdapter('medical-qa.gguf');
final diagnosis = await llamafu.complete('Symptoms: fever, cough...');

// Legal assistant
llamafu.clearLoraAdapters();
await llamafu.loadLoraAdapter('legal-qa.gguf');
final advice = await llamafu.complete('Contract clause review...');
```

### Language Customization

```dart
// Add language support
await llamafu.loadLoraAdapter('japanese-fluency.gguf');
final response = await llamafu.complete('Translate to Japanese: Hello');
```

## Dynamic Scaling

Adjust adapter influence based on context:

```dart
class AdaptiveAssistant {
  late final int _styleAdapter;
  late final int _knowledgeAdapter;

  Future<String> respond(String prompt, {
    double creativity = 0.5,
    double expertise = 1.0,
  }) async {
    // Adjust style adapter based on desired creativity
    llamafu.setLoraScale(_styleAdapter, creativity);

    // Adjust knowledge adapter based on desired expertise
    llamafu.setLoraScale(_knowledgeAdapter, expertise);

    return llamafu.complete(prompt);
  }
}
```

## Creating Your Own Adapters

### Training Tools

LoRA adapters can be trained using:

- **PEFT** (Hugging Face) - Python library for efficient fine-tuning
- **Axolotl** - Easy-to-use fine-tuning framework
- **LLaMA-Factory** - Comprehensive training toolkit

### Converting to GGUF

After training, convert to GGUF format:

```bash
python llama.cpp/convert-lora-to-gguf.py \
  --base-model base-model/ \
  --lora-model lora-adapter/ \
  --outfile adapter.gguf
```

### Training Tips

1. **Use the same base model** - Train on the exact model you'll use for inference
2. **Keep adapter size reasonable** - Rank 8-64 is usually sufficient
3. **Validate before deploying** - Test adapter on representative prompts

## Performance Considerations

### Memory Impact

```dart
final memBefore = llamafu.getMemoryUsage().totalSize;
await llamafu.loadLoraAdapter('adapter.gguf');
final memAfter = llamafu.getMemoryUsage().totalSize;

print('Adapter memory: ${memAfter - memBefore} bytes');
```

### Inference Speed

LoRA adapters add minimal overhead:

- **First token**: ~5-10% slower due to adapter computation
- **Subsequent tokens**: Negligible impact

### Optimization Tips

```dart
// Preload adapters during app startup
await llamafu.loadLoraAdapter('default-adapter.gguf');

// Avoid frequent load/unload cycles
// Keep commonly used adapters loaded
```

## Error Handling

```dart
try {
  final adapter = await llamafu.loadLoraAdapter('adapter.gguf');
} on LlamafuLoraError catch (e) {
  switch (e.code) {
    case ErrorCode.loraFileNotFound:
      print('Adapter file not found');
      break;
    case ErrorCode.loraIncompatible:
      print('Adapter not compatible with model');
      break;
    case ErrorCode.loraLoadFailed:
      print('Failed to load adapter: ${e.message}');
      break;
  }
}
```

## Troubleshooting

### "Adapter not compatible"

Ensure the adapter was trained on the same base model architecture.

### "Tensor dimension mismatch"

The adapter targets layers that don't exist or have different sizes in the base model.

### "Out of memory when loading"

Try loading fewer adapters or use a smaller base model.

## Next Steps

- [Samplers](samplers.md) - Advanced sampling configuration
- [Performance](performance.md) - Optimization techniques
- [API Reference](../api/llamafu.md)
