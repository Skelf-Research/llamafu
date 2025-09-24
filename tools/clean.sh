#!/bin/bash

# Clean script for Llamafu build artifacts

echo "Cleaning build artifacts..."

# Clean Android build directory
if [ -d "android/src/main/cpp/build" ]; then
    rm -rf android/src/main/cpp/build
    echo "Cleaned Android build directory"
fi

# Clean iOS build directory
if [ -d "ios/Classes/build" ]; then
    rm -rf ios/Classes/build
    echo "Cleaned iOS build directory"
fi

# Clean Dart build artifacts
if [ -d ".dart_tool" ]; then
    rm -rf .dart_tool
    echo "Cleaned Dart build artifacts"
fi

# Clean example app build artifacts
if [ -d "example/.dart_tool" ]; then
    rm -rf example/.dart_tool
    echo "Cleaned example app build artifacts"
fi

echo "Cleaning completed!"