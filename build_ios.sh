#!/bin/bash

# Build script for Llamafu iOS library

# Set the path to the llama.cpp directory
LLAMA_CPP_DIR="/home/dipankar/Github/llama.cpp"

# Create build directory
mkdir -p ios/Classes/build
cd ios/Classes/build

# Configure with CMake for iOS
# Note: This is a simplified example. Actual iOS build would require more specific flags.
cmake .. -DLLAMA_CPP_DIR=$LLAMA_CPP_DIR -DCMAKE_SYSTEM_NAME=iOS

# Build
make

echo "iOS build completed successfully!"