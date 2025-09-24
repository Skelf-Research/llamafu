# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
```bash
# Set up development environment (includes git submodules, dependencies)
./tools/setup-dev-env.sh

# Install Flutter dependencies
flutter pub get

# Run comprehensive test suite
dart ./tools/test_runner.dart --comprehensive --coverage

# Run specific test types
dart ./tools/test_runner.dart --performance    # Performance tests only
dart ./tools/test_runner.dart --native         # C++ native tests only
flutter test test/llamafu_comprehensive_test.dart  # Main Dart test suite

# Run a single test by name pattern
flutter test --name="tokenization"
flutter test test/integration/llamafu_integration_test.dart --name="Image"

# Build native library for development
cmake -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build --parallel

# Build for specific platforms
./tools/build-android.sh --debug
./tools/build-local.sh --type Release --enable-gpu
```

### Code Quality
```bash
# Format code
dart format .

# Analyze code
dart analyze --fatal-warnings

# Generate documentation
dart doc

# Security audit
dart pub audit
```

### Clean and Reset
```bash
# Clean all build artifacts
./tools/clean.sh

# Reset git submodules
git submodule update --init --recursive --force
```

## High-Level Architecture

### Core Components
Llamafu is a Flutter FFI plugin that provides on-device AI inference capabilities. The architecture follows these layers:

1. **Dart API Layer** (`lib/src/llamafu_base.dart`) - High-level Flutter API with safety validation
2. **FFI Binding Layer** (`lib/src/llamafu_bindings.dart`) - Dart-to-C bindings via dart:ffi
3. **Native C++ Layer** (`android/src/main/cpp/llamafu.cpp`) - C API wrapper around llama.cpp
4. **Core Engine** (`llama.cpp/` submodule) - llama.cpp inference engine

### Key Design Patterns

#### Resource Management
- All native resources (models, adapters, samplers) use RAII patterns in C++
- Dart layer tracks native pointers and ensures cleanup via finalizers
- Automatic validation prevents resource leaks and use-after-free bugs

#### Multi-Modal Processing
- Vision models require separate CLIP projection files (`mmproj_path`)
- Base64 encoding/decoding handles binary media data transfer
- Streaming interfaces support real-time audio/video processing

#### LoRA Adapter System
- Dynamic loading/unloading of fine-tuning adapters at runtime
- Adapter chaining and scaling for complex model behaviors
- Batch operations for efficient multi-adapter management

#### Security Model
- Input validation prevents path traversal and injection attacks
- File path sanitization blocks access to system directories
- Parameter bounds checking prevents buffer overflows
- Memory safety through careful pointer management

### FFI Architecture Details

The FFI layer uses these patterns:
- **Opaque Pointers**: Native objects represented as `Pointer<Void>` in Dart
- **Structure Marshaling**: Complex parameters passed via packed structs
- **Callback Handling**: Function pointers for progress/streaming callbacks
- **Memory Management**: Manual allocation/deallocation with safety checks

### Build System Integration

#### CMake Configuration (`CMakeLists.txt`)
- Cross-platform build targeting Android NDK, iOS, macOS, Windows, Linux
- Automatic llama.cpp submodule integration and dependency management
- Platform-specific optimization flags (Metal on Apple, CUDA on supported systems)
- Static linking for self-contained mobile deployments

#### Flutter Plugin Structure
- FFI plugin architecture (`pubspec.yaml: ffiPlugin: true`)
- Platform-specific native library loading
- Automatic symbol resolution across platforms

### Critical Implementation Details

#### Context Management
- Context size determines memory usage and maximum conversation length
- Context overflow requires truncation or sliding window approaches
- Multi-sequence support for batch processing

#### Model Loading Pipeline
1. Validate model file format (GGUF headers)
2. Initialize llama.cpp backend with platform-specific settings
3. Load model weights with optional GPU layer offloading
4. Create context with specified parameters
5. Initialize sampling chains and optional features

#### Error Handling Strategy
- Comprehensive error codes for different failure modes (`LlamafuError` enum)
- Validation at multiple layers (Dart parameter validation, C++ bounds checking)
- Graceful degradation for optional features (GPU acceleration, multimodal)

### Testing Architecture

#### Test Structure
- **Comprehensive Tests** (`test/llamafu_comprehensive_test.dart`) - Full API coverage with mock data
- **Integration Tests** (`test/integration/`) - End-to-end workflows with realistic scenarios
- **Performance Tests** (`test/performance/`) - Benchmarking and stress testing
- **Native Tests** (`test/native/`) - C++ unit tests using GoogleTest framework

#### Mock Data System (`test/fixtures/test_data.dart`)
- Generates realistic GGUF model files with proper headers
- Creates valid image/audio data with correct format signatures
- Provides JSON schemas for structured output validation
- Includes malicious input patterns for security testing

## Platform-Specific Considerations

### Android
- Minimum API level 21 (Android 5.0)
- NDK r21+ required for C++17 support
- Static linking to avoid shared library conflicts
- CPU-only inference by default (GPU requires NNAPI/Vulkan)

### iOS
- iOS 12.0+ deployment target
- Metal GPU acceleration available on A7+ devices
- Xcode 14+ required for build
- App Store guidelines compliance for AI model usage

### Memory Constraints
- Mobile devices have limited RAM (typically 4-8GB)
- Model quantization (INT4/INT8) reduces memory footprint
- Context size should be tuned based on available memory
- Streaming generation prevents excessive memory accumulation

## Development Workflow

### Adding New Features
1. Update C API in `android/src/main/cpp/llamafu.h`
2. Implement C++ functionality in `android/src/main/cpp/llamafu.cpp`
3. Add FFI bindings in `lib/src/llamafu_bindings.dart`
4. Create high-level Dart API in `lib/src/llamafu_base.dart`
5. Write comprehensive tests covering all code paths
6. Update documentation and examples

### Debugging Native Code
- Use `CMAKE_BUILD_TYPE=Debug` for debug symbols
- Valgrind on Linux for memory leak detection
- Xcode/Android Studio debuggers for platform-specific issues
- Comprehensive logging through `tools/test_runner.dart --verbose`

### Model Compatibility
- GGUF format is primary supported format (llama.cpp standard)
- Vision models require compatible CLIP projections
- LoRA adapters must match base model architecture
- Quantized models (Q4_0, Q8_0, etc.) supported for reduced memory usage