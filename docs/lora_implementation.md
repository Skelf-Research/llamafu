# LoRA Support Implementation in Llamafu

## Overview

Llamafu now supports LoRA (Low-Rank Adaptation) adapters through integration with the native LoRA functionality in llama.cpp. This allows users to load, apply, and remove LoRA adapters to customize model behavior without modifying the base model weights.

## Implementation Details

### Native Layer (C++)

1. **Header File (`llamafu.h`)**:
   - Added new data structures for LoRA adapters:
     - `LlamafuLoraAdapter` opaque handle
   - Added new error codes for LoRA operations
   - Added new function signatures:
     - `llamafu_lora_adapter_init`
     - `llamafu_lora_adapter_apply`
     - `llamafu_lora_adapter_remove`
     - `llamafu_lora_adapter_clear_all`
     - `llamafu_lora_adapter_free`

2. **Implementation (`llamafu.cpp`)**:
   - Extended `Llamafu_s` struct to track LoRA adapters
   - Implemented `llamafu_lora_adapter_init` to load LoRA adapters using llama.cpp's native functionality
   - Implemented `llamafu_lora_adapter_apply` to apply LoRA adapters to the context
   - Implemented `llamafu_lora_adapter_remove` to remove specific LoRA adapters
   - Implemented `llamafu_lora_adapter_clear_all` to remove all LoRA adapters
   - Implemented `llamafu_lora_adapter_free` to free LoRA adapter resources
   - Modified `llamafu_free` to automatically free all LoRA adapters when the main instance is closed

### Dart Layer

1. **FFI Bindings (`llamafu_bindings.dart`)**:
   - Added new Dart function signatures for LoRA operations
   - Added error code constants for LoRA operations

2. **High-level API (`llamafu_base.dart`)**:
   - Added `LoraAdapter` class to represent LoRA adapters
   - Added `loadLoraAdapter` method to load LoRA adapters
   - Added `applyLoraAdapter` method to apply LoRA adapters
   - Added `removeLoraAdapter` method to remove specific LoRA adapters
   - Added `clearAllLoraAdapters` method to remove all LoRA adapters
   - Modified `close` method to automatically free all LoRA adapters

### Supported Operations

1. **Loading LoRA Adapters**: Load LoRA adapters from GGUF files
2. **Applying LoRA Adapters**: Apply LoRA adapters to the model context with configurable scale factors
3. **Removing LoRA Adapters**: Remove specific LoRA adapters or clear all adapters
4. **Multiple Adapters**: Support for loading and using multiple LoRA adapters simultaneously

## Usage Example

```dart
// Initialize the model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/your/model.gguf',
);

// Load a LoRA adapter
final loraAdapter = await llamafu.loadLoraAdapter('/path/to/your/lora.gguf');

// Apply the LoRA adapter with a scale factor
await llamafu.applyLoraAdapter(loraAdapter, scale: 0.5);

// Generate text with the LoRA adapter applied
final result = await llamafu.complete(
  prompt: 'Write a story about space exploration',
);

// Remove the LoRA adapter
await llamafu.removeLoraAdapter(loraAdapter);

// Or clear all LoRA adapters
await llamafu.clearAllLoraAdapters();

// Clean up resources
llamafu.close();
```

## Integration with Other Features

The LoRA implementation is fully compatible with other Llamafu features:

1. **Multi-modal Support**: LoRA adapters can be used with multi-modal models
2. **Streaming**: LoRA adapters work with both streaming and non-streaming inference
3. **Resource Management**: Automatic cleanup of LoRA adapters when the main instance is closed

## Technical Details

1. **Memory Management**: LoRA adapters are automatically freed when the main Llamafu instance is closed
2. **Error Handling**: Comprehensive error handling for LoRA operations with specific error codes
3. **Thread Safety**: LoRA operations are designed to be thread-safe within the constraints of the underlying llama.cpp library
4. **Scale Factors**: Support for configurable scale factors when applying LoRA adapters (0.0 to 1.0 range)

## Limitations

1. **Model Compatibility**: LoRA adapters must be compatible with the base model
2. **File Format**: Only GGUF format LoRA adapters are supported
3. **Performance**: Applying multiple LoRA adapters may impact inference performance

## Future Improvements

1. **Async Loading**: Implement asynchronous loading of large LoRA adapters
2. **Adapter Merging**: Support for merging multiple LoRA adapters
3. **Dynamic Scaling**: Support for dynamically adjusting scale factors during inference
4. **Adapter Inspection**: Add functionality to inspect LoRA adapter properties