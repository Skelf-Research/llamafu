# Error Handling

API reference for error types and handling.

## Exception Hierarchy

```
LlamafuError (base)
├── LlamafuModelLoadError
├── LlamafuInferenceError
├── LlamafuMultimodalError
├── LlamafuLoraError
└── LlamafuStateError
```

## LlamafuError

Base class for all Llamafu exceptions.

```dart
class LlamafuError implements Exception {
  final String message;
  final ErrorCode code;
  final String? details;
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `message` | `String` | Human-readable error message |
| `code` | `ErrorCode` | Specific error code |
| `details` | `String?` | Additional details (optional) |

## Error Codes

```dart
enum ErrorCode {
  // General
  success,
  unknown,
  invalidParam,
  outOfMemory,

  // Model Loading
  modelNotFound,
  modelInvalidFormat,
  modelLoadFailed,
  modelAlreadyLoaded,

  // Inference
  inferenceFailed,
  contextOverflow,
  generationAborted,

  // Multimodal
  multimodalNotSupported,
  visionInitFailed,
  imageProcessFailed,
  audioProcessFailed,
  invalidMediaFormat,

  // LoRA
  loraFileNotFound,
  loraIncompatible,
  loraLoadFailed,
  loraNotFound,

  // State
  stateSaveFailed,
  stateLoadFailed,
  invalidState,
}
```

## LlamafuModelLoadError

Thrown when model loading fails.

```dart
class LlamafuModelLoadError extends LlamafuError {
  final String modelPath;
}
```

### Common Causes

| Code | Cause | Solution |
|------|-------|----------|
| `modelNotFound` | File doesn't exist | Check path |
| `modelInvalidFormat` | Not a valid GGUF | Use GGUF format |
| `outOfMemory` | Insufficient RAM | Use smaller model/quantization |
| `modelLoadFailed` | Generic load failure | Check file integrity |

### Example

```dart
try {
  await Llamafu.init(modelPath: 'model.gguf');
} on LlamafuModelLoadError catch (e) {
  if (e.code == ErrorCode.modelNotFound) {
    print('Model not found at: ${e.modelPath}');
  } else if (e.code == ErrorCode.outOfMemory) {
    print('Not enough memory. Try a smaller model.');
  }
}
```

## LlamafuInferenceError

Thrown during text generation.

```dart
class LlamafuInferenceError extends LlamafuError {
  final int? tokenPosition;
}
```

### Common Causes

| Code | Cause | Solution |
|------|-------|----------|
| `contextOverflow` | Prompt too long | Reduce prompt or increase context |
| `generationAborted` | Abort callback returned true | Intentional abort |
| `inferenceFailed` | Generic inference failure | Check model and parameters |

### Example

```dart
try {
  await llamafu.complete(veryLongPrompt);
} on LlamafuInferenceError catch (e) {
  if (e.code == ErrorCode.contextOverflow) {
    print('Prompt too long. Max tokens: ${llamafu.contextSize}');
  }
}
```

## LlamafuMultimodalError

Thrown during vision/audio processing.

```dart
class LlamafuMultimodalError extends LlamafuError {
  final MediaType? mediaType;
}
```

### Common Causes

| Code | Cause | Solution |
|------|-------|----------|
| `multimodalNotSupported` | Model lacks vision/audio | Use multimodal model |
| `visionInitFailed` | mmproj not loaded | Provide mmprojPath |
| `imageProcessFailed` | Invalid image | Check format and data |
| `audioProcessFailed` | Invalid audio | Check format and sample rate |
| `invalidMediaFormat` | Unsupported format | Use JPEG/PNG/WAV |

### Example

```dart
try {
  await llamafu.multimodalComplete(
    prompt: 'Describe:',
    mediaInputs: [imageInput],
  );
} on LlamafuMultimodalError catch (e) {
  if (e.code == ErrorCode.visionInitFailed) {
    print('Vision not initialized. Load model with mmprojPath.');
  } else if (e.code == ErrorCode.imageProcessFailed) {
    print('Could not process image: ${e.details}');
  }
}
```

## LlamafuLoraError

Thrown during LoRA operations.

```dart
class LlamafuLoraError extends LlamafuError {
  final String? adapterPath;
  final int? adapterId;
}
```

### Common Causes

| Code | Cause | Solution |
|------|-------|----------|
| `loraFileNotFound` | Adapter file missing | Check path |
| `loraIncompatible` | Wrong model architecture | Use compatible adapter |
| `loraLoadFailed` | Generic load failure | Check file integrity |
| `loraNotFound` | Adapter ID not found | Check adapter ID |

### Example

```dart
try {
  await llamafu.loadLoraAdapter('adapter.gguf');
} on LlamafuLoraError catch (e) {
  if (e.code == ErrorCode.loraIncompatible) {
    print('Adapter not compatible with this model.');
  }
}
```

## LlamafuStateError

Thrown during state save/load operations.

```dart
class LlamafuStateError extends LlamafuError {
  final String? statePath;
}
```

### Common Causes

| Code | Cause | Solution |
|------|-------|----------|
| `stateSaveFailed` | Cannot write state | Check permissions |
| `stateLoadFailed` | Cannot read state | Check file exists |
| `invalidState` | Corrupted state file | Regenerate state |

## Handling Patterns

### Catch All Llamafu Errors

```dart
try {
  await llamafu.complete(prompt);
} on LlamafuError catch (e) {
  print('Llamafu error: ${e.message}');
  print('Code: ${e.code}');
}
```

### Catch Specific Errors

```dart
try {
  await Llamafu.init(modelPath: path);
} on LlamafuModelLoadError catch (e) {
  // Handle model loading errors
} on LlamafuError catch (e) {
  // Handle other Llamafu errors
} catch (e) {
  // Handle non-Llamafu errors
}
```

### Error Recovery

```dart
Future<String> safeComplete(String prompt) async {
  try {
    return await llamafu.complete(prompt);
  } on LlamafuInferenceError catch (e) {
    if (e.code == ErrorCode.contextOverflow) {
      // Truncate and retry
      return await llamafu.complete(prompt.substring(0, 1000));
    }
    rethrow;
  }
}
```

### Logging Errors

```dart
void logLlamafuError(LlamafuError e) {
  print('[Llamafu Error]');
  print('  Code: ${e.code}');
  print('  Message: ${e.message}');
  if (e.details != null) {
    print('  Details: ${e.details}');
  }
  if (e is LlamafuModelLoadError) {
    print('  Path: ${e.modelPath}');
  }
}
```

## Debug Mode

Enable verbose logging for debugging:

```dart
// Set log level
Llamafu.setLogLevel(LogLevel.debug);

// Or capture logs
Llamafu.setLogCallback((level, message) {
  print('[$level] $message');
});
```
