# Building from Source

This guide covers building Llamafu from source for development and custom deployments.

## Prerequisites

### Required Tools

- Git (with submodule support)
- CMake 3.18+
- C++17 compatible compiler
- Flutter SDK 3.10.0+
- Dart SDK 3.1.0+

### Platform-Specific

Android:
- Android Studio
- Android NDK 21+
- Android SDK API 21+

iOS:
- macOS
- Xcode 14+
- Command Line Tools

Linux:
- GCC 9+ or Clang 10+
- build-essential

## Quick Start

```bash
# Clone repository with submodules
git clone --recursive https://github.com/neul-labs/llamafu.git
cd llamafu

# Setup development environment
make setup

# Build native libraries
make build

# Run tests
make test
```

## Make Targets

```bash
# View all available targets
make

# Setup
make setup              # Full environment setup
make deps               # Flutter dependencies only

# Build
make build              # Debug build
make build-release      # Release build
make build-android      # Android build
make build-ios          # iOS build
make build-local        # Local with GPU support

# Test
make test               # Comprehensive tests
make test-unit          # Unit tests only
make test-integration   # Integration tests
make test-performance   # Performance tests

# Code Quality
make format             # Format code
make analyze            # Static analysis
make docs               # Generate documentation

# Clean
make clean              # Clean build artifacts
make clean-all          # Full clean including submodules
```

## Development Build

### Linux/macOS

```bash
# Configure
cmake -B build -DCMAKE_BUILD_TYPE=Debug

# Build
cmake --build build --parallel

# Output
# build/lib/linux/x64/libllamafu_native.a (Linux)
# build/lib/macos/libllamafu_native.a (macOS)
```

### With GPU Support

```bash
# CUDA (Linux)
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_CUDA=ON

# Metal (macOS)
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_METAL=ON

cmake --build build --parallel
```

## Android Build

### Setup

1. Install Android Studio
2. Install NDK through SDK Manager (21.0.6113669 or later)
3. Set environment variables:
   ```bash
   export ANDROID_HOME=$HOME/Android/Sdk
   export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/21.0.6113669
   ```

### Build

```bash
# Using make
make build-android

# Or manually
./tools/build-android.sh --debug

# For release
./tools/build-android.sh --release
```

### Output

Native libraries are placed in:
```
android/src/main/jniLibs/
├── arm64-v8a/
│   └── libllamafu_native.so
├── armeabi-v7a/
│   └── libllamafu_native.so
└── x86_64/
    └── libllamafu_native.so
```

### ABI Selection

In `android/build.gradle`:
```gradle
android {
    defaultConfig {
        ndk {
            // Include all supported ABIs
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64'

            // Or specific ABIs for smaller APK
            // abiFilters 'arm64-v8a'
        }
    }
}
```

## iOS Build

### Setup

1. Install Xcode from App Store
2. Install Command Line Tools:
   ```bash
   xcode-select --install
   ```
3. Accept Xcode license:
   ```bash
   sudo xcodebuild -license accept
   ```

### Build

```bash
# Using make
make build-ios

# Or manually
./tools/build-ios.sh

# Without code signing (for CI)
./tools/build-ios.sh --no-codesign
```

### Output

Framework is placed in:
```
ios/Frameworks/
└── llamafu_native.xcframework/
    ├── ios-arm64/
    └── ios-arm64_x86_64-simulator/
```

### Podspec Configuration

The `llamafu.podspec` configures the framework:
```ruby
Pod::Spec.new do |s|
  s.name             = 'llamafu'
  s.platform         = :ios, '12.0'
  s.vendored_frameworks = 'Frameworks/llamafu_native.xcframework'
end
```

## CMake Configuration

### Options

```cmake
# Build type
-DCMAKE_BUILD_TYPE=Debug|Release|RelWithDebInfo

# GPU support
-DLLAMA_CUDA=ON          # NVIDIA CUDA
-DLLAMA_METAL=ON         # Apple Metal
-DLLAMA_OPENCL=ON        # OpenCL

# Optimization
-DLLAMA_NATIVE=ON        # Native CPU optimizations
-DLLAMA_AVX=ON           # AVX instructions
-DLLAMA_AVX2=ON          # AVX2 instructions

# Build options
-DBUILD_SHARED_LIBS=OFF  # Static linking
-DLLAMA_STATIC=ON        # Static runtime
```

### Cross-Compilation

For Android:
```cmake
cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21 \
  -DCMAKE_BUILD_TYPE=Release
```

For iOS:
```cmake
cmake -B build \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
  -DCMAKE_BUILD_TYPE=Release
```

## Submodule Management

### Initial Setup

```bash
# Clone with submodules
git clone --recursive https://github.com/neul-labs/llamafu.git

# Or initialize after clone
git submodule update --init --recursive
```

### Updating llama.cpp

```bash
# Update to latest
cd llama.cpp
git fetch origin
git checkout <version_tag>
cd ..
git add llama.cpp
git commit -m "Update llama.cpp to <version>"
```

### Using Custom llama.cpp

```bash
# Point to custom directory
export LLAMA_CPP_DIR=/path/to/custom/llama.cpp
cmake -B build -DLLAMA_CPP_DIR=$LLAMA_CPP_DIR
```

## Build Troubleshooting

### CMake Not Found

```bash
# Ubuntu/Debian
sudo apt install cmake

# macOS
brew install cmake

# Windows
# Download from cmake.org
```

### NDK Not Found

```bash
# Set path explicitly
export ANDROID_NDK_HOME=/path/to/ndk

# Or install via sdkmanager
sdkmanager "ndk;21.0.6113669"
```

### iOS Simulator Build Fails

```bash
# Build for specific simulator architecture
cmake -B build \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"
```

### Compiler Errors

Ensure C++17 support:
```bash
# Check compiler version
gcc --version    # Need 9+
clang --version  # Need 10+

# Update on Ubuntu
sudo apt install gcc-11 g++-11
```

### Memory Issues During Build

```bash
# Limit parallel jobs
cmake --build build --parallel 2

# Or set memory limit
cmake --build build -j $(nproc --ignore=2)
```

## Release Build

### Optimized Build

```bash
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_NATIVE=ON \
  -DLLAMA_LTO=ON

cmake --build build --parallel
```

### Strip Symbols

```bash
# Linux
strip build/lib/linux/x64/libllamafu_native.a

# macOS
strip -x build/lib/macos/libllamafu_native.a
```

### Size Optimization

For smaller binaries:
```cmake
-DCMAKE_BUILD_TYPE=MinSizeRel
-DLLAMA_STATIC=ON
-DLLAMA_SANITIZE_UNDEFINED=OFF
```

## CI/CD Build

### GitHub Actions Example

```yaml
jobs:
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'

      - name: Build
        run: |
          make setup
          make build-android

  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.10.0'

      - name: Build
        run: |
          make setup
          make build-ios
```

## Custom Builds

### Adding Compiler Flags

```cmake
# In CMakeLists.txt
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -march=native")
```

### Custom Output Directory

```cmake
cmake -B build \
  -DCMAKE_LIBRARY_OUTPUT_DIRECTORY=/custom/path
```

### Debug Symbols

```cmake
cmake -B build \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_CXX_FLAGS="-g"
```

## Verification

### Test Build

```bash
# Run tests
make test

# Check library
file build/lib/linux/x64/libllamafu_native.a

# Check symbols
nm -g build/lib/linux/x64/libllamafu_native.a | grep llamafu
```

### Flutter Integration Test

```bash
cd example
flutter run
```

## Related Documentation

- [Architecture](architecture.md) - Build system internals
- [Contributing](contributing.md) - Development workflow
- [Performance Guide](performance-guide.md) - Build optimization
