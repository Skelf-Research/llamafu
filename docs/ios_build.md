# iOS Build Process

## Prerequisites

1. Xcode installed
2. CMake installed
3. llama.cpp library built and available

## Building the Native Library

1. Navigate to the project root directory
2. Run the build script:
   ```bash
   ./build_ios.sh
   ```

   Or build manually:
   ```bash
   cd ios/Classes
   mkdir build
   cd build
   cmake .. -DLLAMA_CPP_DIR=/path/to/llama.cpp -DCMAKE_SYSTEM_NAME=iOS
   make
   ```

## Integrating with Flutter

1. Ensure the compiled library is properly linked with the iOS project
2. The Flutter plugin will automatically load the library at runtime

## Troubleshooting

- If you encounter linking errors, make sure all required llama.cpp libraries are available in the specified path
- Ensure Xcode is properly installed and configured
- iOS builds may require additional flags for architecture and SDK specification