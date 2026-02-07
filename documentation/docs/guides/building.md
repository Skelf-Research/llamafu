# Building from Source

Build Llamafu from source for custom configurations or development.

## Prerequisites

### All Platforms

- Git
- CMake 3.19+
- C++17 compatible compiler
- Flutter SDK 3.16+

### Platform-Specific

=== "Linux"
    ```bash
    sudo apt-get install build-essential cmake git
    ```

=== "macOS"
    ```bash
    xcode-select --install
    brew install cmake
    ```

=== "Windows"
    - Visual Studio 2019+ with C++ workload
    - CMake (included with VS or standalone)

=== "Android"
    - Android NDK r21+
    - Android SDK with API 21+

## Clone the Repository

```bash
git clone https://github.com/skelf-research/llamafu.git
cd llamafu

# Initialize llama.cpp submodule
git submodule update --init --recursive
```

## Building Native Libraries

### Linux/macOS Desktop

```bash
# Configure
cmake -B build -DCMAKE_BUILD_TYPE=Release

# Build
cmake --build build --parallel

# Verify
ls build/libllamafu.so  # Linux
ls build/libllamafu.dylib  # macOS
```

### With GPU Support

=== "Metal (macOS)"
    ```bash
    cmake -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLAMAFU_ENABLE_METAL=ON
    cmake --build build --parallel
    ```

=== "CUDA (Linux/Windows)"
    ```bash
    cmake -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLAMAFU_ENABLE_CUDA=ON
    cmake --build build --parallel
    ```

### Android

```bash
# Set NDK path
export ANDROID_NDK=/path/to/ndk

# Build for arm64-v8a
./tools/build-android.sh --arch arm64-v8a --release

# Or build for all architectures
./tools/build-android.sh --all-archs --release
```

### iOS

```bash
# Requires Xcode
./tools/build-ios.sh --release

# Output: ios/Frameworks/llamafu.xcframework
```

## CMake Options

| Option | Default | Description |
|--------|---------|-------------|
| `CMAKE_BUILD_TYPE` | Release | Debug, Release, RelWithDebInfo |
| `LLAMAFU_ENABLE_GPU` | ON | Enable GPU support |
| `LLAMAFU_ENABLE_METAL` | ON | Metal support (Apple) |
| `LLAMAFU_ENABLE_CUDA` | OFF | CUDA support (NVIDIA) |
| `LLAMAFU_ENABLE_OPENCL` | OFF | OpenCL support |
| `BUILD_SHARED_LIBS` | ON | Build shared library |

Example with multiple options:

```bash
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMAFU_ENABLE_CUDA=ON \
  -DLLAMAFU_ENABLE_OPENCL=OFF \
  -DBUILD_SHARED_LIBS=ON
```

## Running Tests

### Dart Tests (Mock)

```bash
flutter test
```

### Integration Tests (Real Model)

```bash
# Download a small test model
./tools/download-test-models.sh

# Run with real model
LLAMAFU_TEST_MODEL=test/fixtures/models/test-model.gguf \
  flutter test test/integration/
```

### Multimodal Tests

```bash
LLAMAFU_TEST_MODEL=test/fixtures/models/nanollava.gguf \
LLAMAFU_TEST_MMPROJ=test/fixtures/models/mmproj.gguf \
  flutter test test/integration/ --name="Multimodal"
```

## Project Structure

```
llamafu/
├── android/                 # Android plugin
│   └── src/main/cpp/       # Native C++ code
│       ├── llamafu.cpp     # Main implementation
│       └── llamafu.h       # C API header
├── ios/                     # iOS plugin
│   └── Classes/            # Native code (symlinked)
├── lib/                     # Dart library
│   └── src/
│       ├── llamafu_base.dart    # High-level API
│       └── llamafu_bindings.dart # FFI bindings
├── llama.cpp/              # llama.cpp submodule
├── build/                  # Build output
├── test/                   # Test files
└── CMakeLists.txt         # Build configuration
```

## Development Workflow

### 1. Make Native Changes

Edit `android/src/main/cpp/llamafu.cpp`:

```cpp
// Add new function
LlamafuError llamafu_my_function(...) {
    // Implementation
}
```

### 2. Rebuild Native Library

```bash
cmake --build build --parallel
```

### 3. Update FFI Bindings

Edit `lib/src/llamafu_bindings.dart`:

```dart
// Add binding
int myFunction(...) {
  return _myFunction(...);
}
```

### 4. Add High-Level API

Edit `lib/src/llamafu_base.dart`:

```dart
// Add method
void myFunction() {
  _bindings.myFunction(...);
}
```

### 5. Sync iOS

```bash
cp android/src/main/cpp/llamafu.* ios/Classes/
```

### 6. Run Tests

```bash
flutter test
```

## Updating llama.cpp

### Check Current Version

```bash
cd llama.cpp
git describe --tags
```

### Update to Latest

```bash
git submodule update --remote llama.cpp
```

### Handle API Changes

After updating, check for breaking changes:

```bash
# Rebuild - errors indicate API changes
cmake --build build --parallel 2>&1 | grep error
```

Common API changes to watch for:
- Function signature changes in `llama.h`
- Struct field changes
- Removed/renamed functions

## Cross-Compilation

### Android from Linux

```bash
export ANDROID_NDK=/path/to/ndk

cmake -B build-android \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-21

cmake --build build-android --parallel
```

### iOS from macOS

```bash
cmake -B build-ios \
  -GXcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_ARCHITECTURES=arm64

cmake --build build-ios --config Release
```

## Troubleshooting

### "Cannot find llama.h"

```bash
git submodule update --init --recursive
```

### "Undefined symbol" at runtime

Rebuild with correct settings:

```bash
rm -rf build
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --parallel
```

### CMake version too old

```bash
# Ubuntu
pip install cmake --upgrade

# macOS
brew upgrade cmake
```

### NDK not found

```bash
export ANDROID_NDK_HOME=/path/to/ndk
export ANDROID_NDK=$ANDROID_NDK_HOME
```

## Next Steps

- [Platform Notes](platforms.md) - Platform-specific details
- [Contributing](../contributing.md) - Contribution guidelines
