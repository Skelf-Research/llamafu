# Model Parameters

Parameters for model initialization and configuration.

## ModelParams

Parameters passed to `Llamafu.init()`.

```dart
class ModelParams {
  final String modelPath;
  final String? mmprojPath;
  final int contextSize;
  final int threads;
  final int threadsBatch;
  final int gpuLayers;
  final bool useMmap;
  final bool useMlock;
  final int seed;
}
```

### Parameter Details

#### `modelPath`

Path to the GGUF model file.

- **Type:** `String`
- **Required:** Yes
- **Example:** `'models/llama-3.2-1b-q4.gguf'`

Supports:
- Absolute paths: `/home/user/models/model.gguf`
- Relative paths: `models/model.gguf`
- Asset paths (Flutter): `assets/models/model.gguf`

#### `mmprojPath`

Path to multimodal projector file for vision/audio models.

- **Type:** `String?`
- **Default:** `null`
- **Example:** `'models/mmproj.gguf'`

Required for:
- LLaVA models
- nanoLLaVA
- Qwen2-VL
- Ultravox (audio)

#### `contextSize`

Maximum context window size in tokens.

- **Type:** `int`
- **Default:** `2048`
- **Range:** `64` to model maximum

| Use Case | Recommended Size |
|----------|-----------------|
| Short Q&A | 512 |
| Chat | 2048 |
| Long documents | 4096-8192 |
| Full context | Model maximum |

Memory usage scales with context size:
```
Memory ≈ contextSize × embeddingSize × 2 × layers × sizeof(float16)
```

#### `threads`

Number of CPU threads for inference.

- **Type:** `int`
- **Default:** `0` (auto-detect)
- **Range:** `1` to CPU core count

Recommendations:
- Mobile: `2-4`
- Desktop: `4-8`
- Auto (`0`): Uses physical core count

#### `threadsBatch`

Number of threads for batch operations.

- **Type:** `int`
- **Default:** `0` (same as `threads`)

Usually set equal to `threads` unless doing batch inference.

#### `gpuLayers`

Number of layers to offload to GPU.

- **Type:** `int`
- **Default:** `0` (CPU only)
- **Range:** `0` to layer count

| Value | Behavior |
|-------|----------|
| `0` | CPU only |
| `1-n` | Partial GPU offload |
| `99` | Full GPU offload (all layers) |

Requirements:
- macOS/iOS: Metal-capable device
- Linux/Windows: CUDA toolkit + NVIDIA GPU

#### `useMmap`

Use memory mapping for model file.

- **Type:** `bool`
- **Default:** `true`

Benefits:
- Faster model loading
- Reduced RAM usage (OS manages pages)
- Shared memory across processes

Disable if:
- Model is on network drive
- Experiencing stability issues

#### `useMlock`

Lock model in RAM (prevent swapping).

- **Type:** `bool`
- **Default:** `false`

Benefits:
- Consistent performance
- No page faults during inference

Requirements:
- Sufficient RAM for entire model
- May require elevated privileges

#### `seed`

Random seed for reproducibility.

- **Type:** `int`
- **Default:** `0` (random)

Same seed + same parameters = same output (for non-zero temperature).

## Configuration Examples

### Mobile (Low Memory)

```dart
final llamafu = await Llamafu.init(
  modelPath: 'models/smollm-135m-q4.gguf',
  contextSize: 512,
  threads: 2,
  useMmap: true,
  useMlock: false,
);
```

### Desktop (Balanced)

```dart
final llamafu = await Llamafu.init(
  modelPath: 'models/llama-3.2-1b-q4.gguf',
  contextSize: 4096,
  threads: 6,
  useMmap: true,
);
```

### Desktop (GPU)

```dart
final llamafu = await Llamafu.init(
  modelPath: 'models/llama-3.2-7b-q4.gguf',
  contextSize: 8192,
  gpuLayers: 99,
  threads: 4,
);
```

### Vision Model

```dart
final llamafu = await Llamafu.init(
  modelPath: 'models/nanollava.gguf',
  mmprojPath: 'models/nanollava-mmproj.gguf',
  contextSize: 2048,
);
```

### Reproducible Output

```dart
final llamafu = await Llamafu.init(
  modelPath: 'models/model.gguf',
  seed: 42,
);

// Same prompt + seed = same output
final response1 = await llamafu.complete(prompt, seed: 42);
final response2 = await llamafu.complete(prompt, seed: 42);
// response1 == response2
```

## Runtime Configuration

Some parameters can be adjusted after initialization:

```dart
// Adjust threads
llamafu.setThreadCount(threads: 4, threadsBatch: 2);

// Cannot change after init:
// - modelPath
// - mmprojPath
// - contextSize
// - gpuLayers
// - useMmap
// - useMlock
```

## Validation

Invalid parameters throw `LlamafuError`:

```dart
try {
  await Llamafu.init(
    modelPath: 'nonexistent.gguf',  // Throws
  );
} on LlamafuModelLoadError catch (e) {
  print('Failed to load: ${e.message}');
}
```

Common validation errors:

| Error | Cause |
|-------|-------|
| `INVALID_MODEL_PATH` | File doesn't exist |
| `INVALID_MODEL_FORMAT` | Not a valid GGUF file |
| `CONTEXT_TOO_LARGE` | Context exceeds model maximum |
| `OUT_OF_MEMORY` | Insufficient memory |
