#!/bin/bash

# Build script for Llamafu Android library

# Initialize submodules if they don't exist
if [ ! -f "llama.cpp/CMakeLists.txt" ]; then
    echo "Initializing llama.cpp submodule..."
    git submodule update --init --recursive
fi

# Set the path to the llama.cpp directory
LLAMA_CPP_DIR="${LLAMA_CPP_DIR:-${PWD}/llama.cpp}"

# Create build directory
mkdir -p android/src/main/cpp/build
cd android/src/main/cpp/build

# Configure with CMake
cmake .. -DLLAMA_CPP_DIR=$LLAMA_CPP_DIR

# Build
make -j$(nproc)

echo "Build completed successfully!"