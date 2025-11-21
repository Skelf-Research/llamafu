# Architecture

This document describes the technical architecture of Llamafu, including its layered design, FFI integration, and key implementation details.

## Overview

Llamafu is structured as a Flutter FFI plugin that wraps llama.cpp for on-device LLM inference. The architecture consists of four main layers:

```
┌─────────────────────────────────┐
│     Dart API Layer              │
│   (llamafu_base.dart)           │
├─────────────────────────────────┤
│     FFI Binding Layer           │
│   (llamafu_bindings.dart)       │
├─────────────────────────────────┤
│     Native C++ Layer            │
│   (llamafu.cpp / llamafu.h)     │
├─────────────────────────────────┤
│     llama.cpp Core              │
│   (llama.cpp submodule)         │
└─────────────────────────────────┘
```

## Layer Details

### Dart API Layer

Location: `lib/src/llamafu_base.dart`

The high-level Flutter API provides:

- Type-safe Dart interfaces
- Parameter validation
- Memory safety through automatic resource management
- Async/await support for non-blocking operations
- Error handling with typed exceptions

Key responsibilities:
- Input validation and sanitization
- Security checks (path traversal, injection prevention)
- Resource lifecycle management
- Type conversion between Dart and native types

### FFI Binding Layer

Location: `lib/src/llamafu_bindings.dart`

The FFI layer handles Dart-to-C communication:

- Function pointer definitions matching C API
- Structure definitions for parameter passing
- Memory allocation/deallocation helpers
- Callback mechanism support

Patterns used:
- Opaque pointers for native object handles
- Struct marshaling for complex parameters
- Finalizers for automatic resource cleanup

### Native C++ Layer

Location: `android/src/main/cpp/llamafu.cpp`, `android/src/main/cpp/llamafu.h`

The C API wrapper provides:

- C-compatible interface for FFI consumption
- Parameter validation and bounds checking
- Error code propagation
- Thread safety where required

The header file (`llamafu.h`) defines:
- Type definitions and enums
- Function declarations
- Structure definitions
- Error codes

### llama.cpp Core

Location: `llama.cpp/` (git submodule)

The inference engine provides:

- Model loading and management
- Token processing (encode/decode)
- Inference execution
- Sampling algorithms
- Memory management (KV cache, context)

## Key Design Patterns

### Resource Management

Native resources use RAII patterns in C++:

```cpp
struct Llamafu_s {
    llama_model* model;
    llama_context* ctx;
    std::map<LlamafuLoraAdapter, llama_adapter_lora*> lora_adapters;
    // ...
};
```

Dart layer tracks native pointers and ensures cleanup:

```dart
class Llamafu {
  Pointer<Void>? _handle;

  void close() {
    if (_handle != null) {
      _bindings.llamafu_free(_handle!);
      _handle = null;
    }
  }
}
```

### Error Handling

Errors propagate through error codes:

```cpp
typedef enum {
    LLAMAFU_SUCCESS = 0,
    LLAMAFU_ERROR_INVALID_PARAM = -2,
    LLAMAFU_ERROR_MODEL_LOAD_FAILED = -3,
    LLAMAFU_ERROR_OUT_OF_MEMORY = -4,
    // ...
} LlamafuError;
```

Dart converts to typed exceptions:

```dart
if (result != LLAMAFU_SUCCESS) {
  throw LlamafuException(
    code: LlamafuErrorCode.fromInt(result),
    message: 'Operation failed',
  );
}
```

### Memory Safety

Multiple layers of protection:

1. Dart layer validates string parameters
2. C layer performs bounds checking
3. Pointer validity checks before operations
4. Automatic cleanup through finalizers

### Opaque Handles

Native objects are represented as opaque pointers:

```cpp
typedef struct Llamafu_s* Llamafu;
typedef struct LlamafuLoraAdapter_s* LlamafuLoraAdapter;
typedef struct LlamafuSampler_s* LlamafuSampler;
```

This hides implementation details and allows internal changes without API breaks.

## Data Flow

### Model Loading

```
Dart: loadModel(path)
  │
  ▼
FFI: llamafu_init(params, &handle)
  │
  ▼
C++: Load model file
     Initialize llama context
     Setup samplers
     Return handle
  │
  ▼
Dart: Store handle for future operations
```

### Text Generation

```
Dart: complete(prompt, params)
  │
  ▼
FFI: llamafu_complete(handle, params, &result)
  │
  ▼
C++: Tokenize prompt
     Clear KV cache
     Evaluate tokens
     Sample next token (loop)
     Detokenize result
     Return string
  │
  ▼
Dart: Convert to String, return to caller
```

### Multimodal Processing

```
Dart: multimodalComplete(prompt, images)
  │
  ▼
FFI: llamafu_multimodal_complete(handle, params, &result)
  │
  ▼
C++: Process text prompt
     Load and encode images via CLIP
     Combine embeddings
     Generate response
     Return string
```

## Memory Architecture

### Context Management

The context holds the KV cache and generation state:

- `n_ctx`: Maximum context size (tokens)
- `n_batch`: Batch size for prompt processing
- KV cache memory scales with context size

Memory usage: `O(n_ctx * n_layers * n_embd * 2)`

### Model Memory

Model weights are memory-mapped when `use_mmap` is enabled:

- Reduces initial load time
- Allows OS to manage memory
- May increase memory pressure under load

Quantization reduces memory requirements:

- FP16: 2 bytes per parameter
- Q8_0: 1 byte per parameter
- Q4_K_M: 0.5 bytes per parameter

### Adapter Memory

LoRA adapters add relatively small overhead:

- Low-rank matrices: `A (d x r)` and `B (r x d)`
- Typical rank: 8-64
- Memory: `O(r * d * n_adapted_layers)`

## Thread Model

### CPU Threading

Inference uses multiple threads for matrix operations:

```cpp
llama_context_params ctx_params;
ctx_params.n_threads = n_threads;        // Prompt processing
ctx_params.n_threads_batch = n_threads;  // Batch operations
```

Recommendation: `n_threads = num_cores - 1`

### GPU Offloading

When available, layers can be offloaded to GPU:

```cpp
llama_model_params model_params;
model_params.n_gpu_layers = n_gpu_layers;  // -1 for all
```

GPU backends:
- Metal (iOS/macOS)
- CUDA (Android with supported hardware)
- OpenCL (experimental)

## Build System

### CMake Integration

The build uses CMake for cross-platform compilation:

```
CMakeLists.txt
├── Platform detection
├── llama.cpp submodule inclusion
├── Compiler flags
└── Output library configuration
```

### Static Linking

Libraries are statically linked for:

- Self-contained deployment
- Avoiding shared library conflicts
- Simplified distribution

### Platform Specifics

Android (NDK):
- ABI targets: arm64-v8a, armeabi-v7a, x86_64
- C++17 support required
- Static linking to avoid conflicts

iOS:
- Universal binary (arm64)
- Bitcode disabled
- Framework packaging

## Security Considerations

### Input Validation

All inputs are validated:

- String length limits
- Path traversal prevention
- Numeric bounds checking
- Null pointer checks

### File Access

Model file paths are sanitized:

- No relative path traversal (`..`)
- No system directory access
- Length limits enforced

### Memory Protection

- Buffer overflow prevention
- Use-after-free prevention through handle validation
- Integer overflow checks on sizes

## Extension Points

### Adding New Functions

1. Add declaration to `llamafu.h`
2. Implement in `llamafu.cpp`
3. Add FFI binding in `llamafu_bindings.dart`
4. Create Dart API in `llamafu_base.dart`
5. Write tests

### Custom Samplers

The sampler chain pattern allows custom sampling:

```cpp
LlamafuSampler chain = llamafu_sampler_chain_init();
llamafu_sampler_chain_add(chain, llamafu_sampler_init_top_k(40));
llamafu_sampler_chain_add(chain, llamafu_sampler_init_top_p(0.9, 1));
llamafu_sampler_chain_add(chain, llamafu_sampler_init_temp(0.7));
```

## Performance Characteristics

### Latency Components

1. Model loading: O(model_size) - one time
2. Tokenization: O(prompt_length)
3. Prompt evaluation: O(prompt_tokens * model_complexity)
4. Token generation: O(max_tokens * model_complexity)

### Memory Access Patterns

- Sequential for KV cache updates
- Random for attention computation
- Streaming for token generation

### Optimization Opportunities

- Quantization for memory/compute tradeoff
- Batch processing for throughput
- KV cache reuse for conversations
- Speculative decoding (future)

## Related Documentation

- [Building](building.md) - Build system details
- [API Reference](api-reference.md) - Complete API documentation
- [Performance Guide](performance-guide.md) - Optimization techniques
