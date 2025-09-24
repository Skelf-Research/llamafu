# Multi-modal Implementation in Llamafu

## Overview

Llamafu now supports multi-modal inference through integration with the MTMD (Multi-Modal) library in llama.cpp. This allows processing of images and audio alongside text inputs.

## Implementation Details

### Native Layer (C++)

1. **Header File (`llamafu.h`)**:
   - Added new data structures for multi-modal inputs:
     - `LlamafuMediaType` enum for text, image, and audio
     - `LlamafuMediaInput` struct for media data
     - `LlamafuMultimodalInferParams` struct for multi-modal inference parameters
   - Added new function signatures:
     - `llamafu_multimodal_complete`
     - `llamafu_multimodal_complete_stream`

2. **Implementation (`llamafu.cpp`)**:
   - Extended `Llamafu_s` struct to include `mtmd_context` for multi-modal processing
   - Modified `llamafu_init` to optionally initialize multi-modal context
   - Implemented `llamafu_multimodal_complete` for multi-modal inference
   - Added helper functions for loading media files
   - Integrated with MTMD library for tokenization and encoding of media inputs

### Dart Layer

1. **FFI Bindings (`llamafu_bindings.dart`)**:
   - Added new Dart structs for multi-modal parameters
   - Added bindings for new multi-modal native functions

2. **High-level API (`llamafu_base.dart`)**:
   - Added `MediaType` enum
   - Added `MediaInput` class
   - Added `multimodalComplete` method to the main `Llamafu` class
   - Extended `init` method to accept multi-modal projector path

### Supported Media Types

1. **Images**: Processed through CLIP-based encoders
2. **Audio**: Processed through audio-specific encoders
3. **Text**: Standard text tokenization (existing functionality)

### Supported Models

The implementation supports various multi-modal models through llama.cpp's MTMD library:

- Vision models (Gemma 3, SmolVLM, Qwen series, etc.)
- Audio models (Ultravox, Qwen2-Audio, etc.)
- Mixed modality models (Qwen2.5 Omni)

## Usage Example

```dart
// Initialize with multi-modal support
final llamafu = await Llamafu.init(
  modelPath: '/path/to/model.gguf',
  mmprojPath: '/path/to/mmproj.gguf',
  useGpu: false,
);

// Perform multi-modal inference
final mediaInputs = [
  MediaInput(
    type: MediaType.image,
    data: '/path/to/image.jpg',
  ),
];

final result = await llamafu.multimodalComplete(
  prompt: 'Describe this image: <image>',
  mediaInputs: mediaInputs,
);
```

## Limitations

1. **Simplified Implementation**: The current implementation is a simplified version that demonstrates the concept. A production implementation would require more sophisticated integration between media embeddings and the text model.

2. **Media Processing**: The example assumes pre-processed media data. A complete implementation would need to include proper media decoding (image format support, audio format support, etc.).

3. **Streaming Support**: Multi-modal streaming is not yet fully implemented.

## Future Improvements

1. **Video Support**: Extend to support video inputs
2. **Enhanced Media Processing**: Add proper image/audio decoding and preprocessing
3. **Performance Optimizations**: Optimize media processing pipelines
4. **Streaming Support**: Implement full streaming for multi-modal inputs