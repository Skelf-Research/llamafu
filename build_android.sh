#!/bin/bash

# Build script for Llamafu Android library

# Set the path to the llama.cpp directory
LLAMA_CPP_DIR="/home/dipankar/Github/llama.cpp"

# Create build directory
mkdir -p android/src/main/cpp/build
cd android/src/main/cpp/build

# Configure with CMake
cmake .. -DLLAMA_CPP_DIR=$LLAMA_CPP_DIR

# Build
make

echo "Build completed successfully!"