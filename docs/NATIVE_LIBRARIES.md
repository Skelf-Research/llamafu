# Llamafu Native Libraries

This directory contains pre-compiled native libraries for different platforms and architectures.

## Directory Structure

```
native-libs/
├── android/
│   ├── arm64-v8a/
│   │   ├── libllamafu_native.a
│   │   └── llamafu.h
│   ├── armeabi-v7a/
│   ├── x86_64/
│   └── x86/
├── ios/
│   ├── device/
│   │   └── arm64/
│   └── simulator/
│       ├── arm64/
│       └── x86_64/
├── macos/
│   ├── arm64/
│   └── x86_64/
├── linux/
│   ├── x64/
│   └── arm64/
├── windows/
│   ├── x64/
│   └── x86/
└── README.md
```

## Usage

### Flutter Plugin Development

The native libraries are automatically integrated into the Flutter plugin build process. The CMake configuration will use these pre-compiled libraries when available, falling back to building from source if needed.

### Manual Integration

For manual integration, copy the appropriate library and header file for your target platform:

1. **Android**: Use the library matching your target ABI
   ```bash
   cp native-libs/android/arm64-v8a/libllamafu_native.a your-project/
   cp native-libs/android/arm64-v8a/llamafu.h your-project/
   ```

2. **iOS**: Use device libraries for real devices, simulator libraries for iOS Simulator
   ```bash
   cp native-libs/ios/device/arm64/libllamafu_native.a your-project/
   cp native-libs/ios/device/arm64/llamafu.h your-project/
   ```

3. **macOS**: Choose the appropriate architecture
   ```bash
   cp native-libs/macos/arm64/libllamafu_native.a your-project/  # Apple Silicon
   cp native-libs/macos/x86_64/libllamafu_native.a your-project/  # Intel
   ```

### CMake Integration

To use these libraries in your CMake project:

```cmake
# Find the appropriate library for your platform
set(LLAMAFU_NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/native-libs")

if(ANDROID)
    set(LLAMAFU_LIB_PATH "${LLAMAFU_NATIVE_DIR}/android/${ANDROID_ABI}/libllamafu_native.a")
elseif(IOS)
    if(CMAKE_OSX_SYSROOT MATCHES "iphoneos")
        set(LLAMAFU_LIB_PATH "${LLAMAFU_NATIVE_DIR}/ios/device/${CMAKE_OSX_ARCHITECTURES}/libllamafu_native.a")
    else()
        set(LLAMAFU_LIB_PATH "${LLAMAFU_NATIVE_DIR}/ios/simulator/${CMAKE_OSX_ARCHITECTURES}/libllamafu_native.a")
    endif()
elseif(APPLE)
    set(LLAMAFU_LIB_PATH "${LLAMAFU_NATIVE_DIR}/macos/${CMAKE_OSX_ARCHITECTURES}/libllamafu_native.a")
elseif(WIN32)
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(LLAMAFU_LIB_PATH "${LLAMAFU_NATIVE_DIR}/windows/x64/llamafu_native.lib")
    else()
        set(LLAMAFU_LIB_PATH "${LLAMAFU_NATIVE_DIR}/windows/x86/llamafu_native.lib")
    endif()
else()
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        set(LLAMAFU_LIB_PATH "${LLAMAFU_NATIVE_DIR}/linux/arm64/libllamafu_native.a")
    else()
        set(LLAMAFU_LIB_PATH "${LLAMAFU_NATIVE_DIR}/linux/x64/libllamafu_native.a")
    endif()
endif()

# Create imported library target
add_library(llamafu_native STATIC IMPORTED)
set_target_properties(llamafu_native PROPERTIES
    IMPORTED_LOCATION "${LLAMAFU_LIB_PATH}"
    INTERFACE_INCLUDE_DIRECTORIES "${LLAMAFU_NATIVE_DIR}"
)

# Link your target with the library
target_link_libraries(your_target PRIVATE llamafu_native)
```

## Building from Source

If pre-compiled libraries are not available for your platform, you can build them from source:

### Local Build
```bash
# Build for current platform
./scripts/build-local.sh

# Build for Android (requires Android NDK)
./scripts/build-android.sh

# Build with specific options
./scripts/build-local.sh --type Debug --enable-cuda
```

### Automated Builds

The project includes GitHub Actions workflows that automatically build libraries for all supported platforms. These are triggered on:

- Push to main branch
- Pull requests
- Manual workflow dispatch

## Library Features

The native libraries include the following features:

### Core Features
- ✅ Text generation and completion
- ✅ Multi-modal support (vision and audio)
- ✅ LoRA adapter loading and management
- ✅ Grammar-constrained generation (GBNF)
- ✅ Token-level operations (tokenize, detokenize)
- ✅ Model introspection and embeddings

### Platform-Specific Optimizations
- **Android**: Optimized for mobile ARM processors
- **iOS**: Metal GPU acceleration support
- **macOS**: Metal GPU acceleration support
- **Linux**: OpenCL support (when available)
- **Windows**: CUDA support (when enabled)

### Performance Features
- Static linking for reduced dependencies
- Optimized for mobile and embedded deployment
- Memory-efficient quantized model support
- Multi-threading support

## Version Information

Each library directory contains a `build-info.txt` file with:
- Platform and architecture
- Build type (Debug/Release)
- Build date and commit
- Enabled features

## Troubleshooting

### Library Not Found
If you get linking errors, ensure:
1. The library path is correct for your platform/architecture
2. All required system libraries are available
3. The library was built with compatible compiler settings

### Architecture Mismatch
Make sure you're using the library that matches your target architecture:
- Android: arm64-v8a for 64-bit ARM, armeabi-v7a for 32-bit ARM
- iOS: arm64 for devices, x86_64/arm64 for simulator
- macOS: arm64 for Apple Silicon, x86_64 for Intel

### Missing Dependencies
On Linux, you may need to install additional packages:
```bash
sudo apt-get install build-essential cmake
```

On macOS, ensure Xcode command line tools are installed:
```bash
xcode-select --install
```

## Support

For issues with the native libraries:

1. Check the build logs in the Actions tab of the GitHub repository
2. Verify your platform/architecture combination is supported
3. Try building from source using the provided scripts
4. Open an issue with your platform details and error messages

## License

The native libraries are built from:
- **llamafu**: MIT License
- **llama.cpp**: MIT License

See the respective projects for full license terms.