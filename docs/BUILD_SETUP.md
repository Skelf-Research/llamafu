# Llamafu Build Environment Setup

This document explains how to set up the build environment for Llamafu with automatic llama.cpp integration.

## Quick Start

Llamafu now includes llama.cpp as a git submodule, making setup much simpler:

```bash
# Clone the repository with submodules
git clone --recursive git@github.com:your-username/llamafu.git

# Or if you already cloned, initialize submodules
cd llamafu
git submodule update --init --recursive
```

## Environment Variables (Optional)

For advanced users who want to use a custom llama.cpp build:

### LLAMA_CPP_DIR

Set the path to your custom llama.cpp installation:

```bash
export LLAMA_CPP_DIR="/path/to/your/llama.cpp"
```

### Build Configuration Priority

The build system uses the following priority order for finding llama.cpp:

1. **Environment variable**: `LLAMA_CPP_DIR`
2. **Gradle property**: `llama.cpp.dir` (Android only)
3. **Git submodule**: `./llama.cpp` (recommended default)

## Platform-Specific Setup

### Android

#### Method 1: Environment Variable (Recommended)
```bash
export LLAMA_CPP_DIR="/path/to/llama.cpp"
flutter build apk
```

#### Method 2: Gradle Property
Add to `android/gradle.properties`:
```properties
llama.cpp.dir=/path/to/llama.cpp
```

#### Method 3: Command Line
```bash
flutter build apk --dart-define=llama.cpp.dir=/path/to/llama.cpp
```

### iOS

#### Method 1: Environment Variable (Recommended)
```bash
export LLAMA_CPP_DIR="/path/to/llama.cpp"
flutter build ios
```

#### Method 2: Manual Build Script
```bash
LLAMA_CPP_DIR="/path/to/llama.cpp" ./build_ios.sh
```

## Prerequisites

### Required Dependencies

1. **Flutter SDK** (3.0+)
2. **Android NDK** (for Android builds)
3. **Xcode** (for iOS builds)
4. **CMake** (3.4.1+)
5. **Pre-built llama.cpp libraries**

### Automatic llama.cpp Building

Llamafu now automatically builds llama.cpp as part of the build process. No manual setup required!

The build process automatically:
- Initializes the llama.cpp submodule if needed
- Configures llama.cpp with optimal settings for mobile
- Builds the required libraries:
  - `libllama` - Core language model engine
  - `libggml` - Low-level tensor operations
  - Multi-modal support (for vision/audio models)

### Manual llama.cpp Building (Advanced)

If you need a custom llama.cpp build:

```bash
cd llama.cpp
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DGGML_STATIC=ON -DLLAMA_STATIC=ON
make -j$(nproc)
```

## Directory Structure

```
llamafu/                       # This project
├── llama.cpp/                 # Git submodule (automatically managed)
│   ├── CMakeLists.txt
│   ├── src/
│   ├── ggml/
│   └── tools/
├── android/
│   └── src/main/cpp/
├── ios/
│   └── Classes/
├── lib/
│   └── src/
└── example/
```

## Build Commands

### Native Library Build

#### Android
```bash
# Simple build (uses submodule automatically)
./build_android.sh

# Or with custom llama.cpp path
LLAMA_CPP_DIR="/path/to/custom/llama.cpp" ./build_android.sh
```

#### iOS
```bash
# Simple build (uses submodule automatically)
./build_ios.sh

# Or with custom llama.cpp path
LLAMA_CPP_DIR="/path/to/custom/llama.cpp" ./build_ios.sh
```

### Flutter App Build

```bash
# Build for Android (submodule handled automatically)
flutter build apk

# Build for iOS (submodule handled automatically)
flutter build ios

# For development
flutter run
```

## Troubleshooting

### Common Issues

1. **Submodule not initialized**
   ```bash
   # Fix: Initialize submodules
   git submodule update --init --recursive
   ```

2. **CMake configuration errors**
   - Verify CMake version (3.4.1+)
   - Check that NDK is properly installed (Android)
   - Ensure Xcode command line tools are installed (iOS)

3. **Build performance issues**
   ```bash
   # For faster builds, use more CPU cores
   export CMAKE_BUILD_PARALLEL_LEVEL=$(nproc)  # Linux
   export CMAKE_BUILD_PARALLEL_LEVEL=$(sysctl -n hw.ncpu)  # macOS
   ```

4. **Clean build issues**
   ```bash
   # Clean everything and rebuild
   ./clean.sh
   git submodule update --init --recursive
   ./build_android.sh  # or build_ios.sh
   ```

### Debug Information

To debug build issues, check:

```bash
# Verify environment variable
echo $LLAMA_CPP_DIR

# Check library existence
ls -la $LLAMA_CPP_DIR/build/bin/

# Verify library architecture (Linux/macOS)
file $LLAMA_CPP_DIR/build/bin/libllama.so
```

## Security Considerations

- The build system validates paths to prevent directory traversal
- Environment variables take precedence over hardcoded paths
- Build scripts reject paths containing suspicious patterns
- All paths are validated before use in CMake configuration

## CI/CD Integration

For automated builds, set environment variables in your CI/CD pipeline:

```yaml
# GitHub Actions example
env:
  LLAMA_CPP_DIR: ${{ github.workspace }}/llama.cpp

# GitLab CI example
variables:
  LLAMA_CPP_DIR: "${CI_PROJECT_DIR}/llama.cpp"
```