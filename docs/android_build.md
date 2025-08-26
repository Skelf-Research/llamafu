# Android Build Process

## Prerequisites

1. Android NDK installed
2. CMake installed
3. llama.cpp library built and available

## Building the Native Library

1. Navigate to the project root directory
2. Run the build script:
   ```bash
   ./build_android.sh
   ```

   Or build manually:
   ```bash
   cd android/src/main/cpp
   mkdir build
   cd build
   cmake .. -DLLAMA_CPP_DIR=/path/to/llama.cpp
   make
   ```

## Integrating with Flutter

1. Ensure the `libllamafu.so` file is placed in the correct directory for Flutter to find it
2. The Flutter plugin will automatically load the library at runtime

## Troubleshooting

- If you encounter linking errors, make sure all required llama.cpp libraries are available in the specified path
- Ensure the Android NDK is properly installed and configured