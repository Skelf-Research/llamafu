#!/bin/bash

# Build script for Llamafu iOS library

# Initialize submodules if they don't exist
if [ ! -f "llama.cpp/CMakeLists.txt" ]; then
    echo "Initializing llama.cpp submodule..."
    git submodule update --init --recursive
fi

# Set the path to the llama.cpp directory
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-${PWD}/llama.cpp}"

# Create build directory
mkdir -p ios/Classes/build
cd ios/Classes/build

# Configure with CMake for iOS
# Note: This is a simplified example. Actual iOS build would require more specific flags.
cmake .. -DLLAMA_CPP_DIR=$LLAMA_CPP_DIR -DCMAKE_SYSTEM_NAME=iOS

# Build
make -j$(sysctl -n hw.ncpu)

echo "iOS build completed successfully!"