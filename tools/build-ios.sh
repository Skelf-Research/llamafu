#!/bin/bash

# iOS Build Script for Llamafu
# This script builds the native library for iOS (device and simulator)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build/ios"
OUTPUT_DIR="${PROJECT_ROOT}/ios/Frameworks"

# Default configuration
BUILD_TYPE="Release"
BUILD_SIMULATOR=true
BUILD_DEVICE=true
ENABLE_METAL=true
CREATE_XCFRAMEWORK=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="Debug"
            shift
            ;;
        --release)
            BUILD_TYPE="Release"
            shift
            ;;
        --device-only)
            BUILD_SIMULATOR=false
            shift
            ;;
        --simulator-only)
            BUILD_DEVICE=false
            shift
            ;;
        --no-metal)
            ENABLE_METAL=false
            shift
            ;;
        --no-xcframework)
            CREATE_XCFRAMEWORK=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --debug          Build debug configuration"
            echo "  --release        Build release configuration (default)"
            echo "  --device-only    Only build for iOS devices"
            echo "  --simulator-only Only build for iOS simulator"
            echo "  --no-metal       Disable Metal GPU support"
            echo "  --no-xcframework Don't create XCFramework"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "Llamafu iOS Build"
echo "=========================================="
echo "Build Type: ${BUILD_TYPE}"
echo "Build Simulator: ${BUILD_SIMULATOR}"
echo "Build Device: ${BUILD_DEVICE}"
echo "Metal Support: ${ENABLE_METAL}"
echo "Create XCFramework: ${CREATE_XCFRAMEWORK}"
echo "=========================================="

# Check for required tools
check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is required but not installed."
        exit 1
    fi
}

check_tool cmake
check_tool xcodebuild

# Ensure llama.cpp submodule is initialized
if [ ! -f "${PROJECT_ROOT}/llama.cpp/CMakeLists.txt" ]; then
    echo "Initializing llama.cpp submodule..."
    cd "${PROJECT_ROOT}"
    git submodule update --init --recursive
fi

# Create output directories
mkdir -p "${BUILD_DIR}"
mkdir -p "${OUTPUT_DIR}"

# iOS SDK paths
IOS_SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
SIM_SDK_PATH=$(xcrun --sdk iphonesimulator --show-sdk-path)

# CMake common options
CMAKE_COMMON_OPTS=(
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}"
    -DLLAMA_BUILD_TESTS=OFF
    -DLLAMA_BUILD_EXAMPLES=OFF
    -DLLAMA_BUILD_SERVER=OFF
    -DLLAMA_STATIC=ON
    -DGGML_STATIC=ON
    -DLLAMA_NATIVE=OFF
)

if [ "${ENABLE_METAL}" = true ]; then
    CMAKE_COMMON_OPTS+=(-DLLAMA_METAL=ON -DLLAMAFU_ENABLE_METAL=ON)
else
    CMAKE_COMMON_OPTS+=(-DLLAMA_METAL=OFF -DLLAMAFU_ENABLE_METAL=OFF)
fi

# Build for iOS device (arm64)
build_device() {
    echo ""
    echo "Building for iOS device (arm64)..."

    local BUILD_PATH="${BUILD_DIR}/device"
    mkdir -p "${BUILD_PATH}"

    cd "${BUILD_PATH}"
    cmake "${PROJECT_ROOT}/ios/Classes" \
        "${CMAKE_COMMON_OPTS[@]}" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_SYSROOT="${IOS_SDK_PATH}" \
        -DCMAKE_IOS_INSTALL_COMBINED=YES \
        -DIOS=ON

    cmake --build . --config "${BUILD_TYPE}" --parallel

    echo "iOS device build complete!"
}

# Build for iOS simulator (arm64 + x86_64)
build_simulator() {
    echo ""
    echo "Building for iOS simulator..."

    # Build arm64 simulator
    local BUILD_PATH_ARM="${BUILD_DIR}/simulator-arm64"
    mkdir -p "${BUILD_PATH_ARM}"

    echo "Building simulator (arm64)..."
    cd "${BUILD_PATH_ARM}"
    cmake "${PROJECT_ROOT}/ios/Classes" \
        "${CMAKE_COMMON_OPTS[@]}" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
        -DCMAKE_OSX_ARCHITECTURES=arm64 \
        -DCMAKE_OSX_SYSROOT="${SIM_SDK_PATH}" \
        -DIOS=ON

    cmake --build . --config "${BUILD_TYPE}" --parallel

    # Build x86_64 simulator
    local BUILD_PATH_X86="${BUILD_DIR}/simulator-x86_64"
    mkdir -p "${BUILD_PATH_X86}"

    echo "Building simulator (x86_64)..."
    cd "${BUILD_PATH_X86}"
    cmake "${PROJECT_ROOT}/ios/Classes" \
        "${CMAKE_COMMON_OPTS[@]}" \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
        -DCMAKE_OSX_ARCHITECTURES=x86_64 \
        -DCMAKE_OSX_SYSROOT="${SIM_SDK_PATH}" \
        -DIOS=ON

    cmake --build . --config "${BUILD_TYPE}" --parallel

    # Create fat library for simulator
    echo "Creating fat library for simulator..."
    local SIM_OUTPUT="${BUILD_DIR}/simulator"
    mkdir -p "${SIM_OUTPUT}"

    # Find the library files
    local LIB_ARM="${BUILD_PATH_ARM}/libllamafu_static.a"
    local LIB_X86="${BUILD_PATH_X86}/libllamafu_static.a"

    if [ -f "${LIB_ARM}" ] && [ -f "${LIB_X86}" ]; then
        lipo -create "${LIB_ARM}" "${LIB_X86}" -output "${SIM_OUTPUT}/libllamafu.a"
        echo "Simulator fat library created!"
    else
        # Try shared library
        LIB_ARM="${BUILD_PATH_ARM}/libllamafu.dylib"
        LIB_X86="${BUILD_PATH_X86}/libllamafu.dylib"
        if [ -f "${LIB_ARM}" ] && [ -f "${LIB_X86}" ]; then
            lipo -create "${LIB_ARM}" "${LIB_X86}" -output "${SIM_OUTPUT}/libllamafu.dylib"
            echo "Simulator fat library created!"
        else
            echo "Warning: Could not find libraries to create fat binary"
        fi
    fi

    echo "iOS simulator build complete!"
}

# Create XCFramework
create_xcframework() {
    echo ""
    echo "Creating XCFramework..."

    local XCFRAMEWORK_PATH="${OUTPUT_DIR}/llamafu.xcframework"

    # Remove existing XCFramework
    rm -rf "${XCFRAMEWORK_PATH}"

    local DEVICE_LIB="${BUILD_DIR}/device/libllamafu_static.a"
    local SIM_LIB="${BUILD_DIR}/simulator/libllamafu.a"

    # Try to find the libraries
    if [ ! -f "${DEVICE_LIB}" ]; then
        DEVICE_LIB="${BUILD_DIR}/device/libllamafu.a"
    fi

    if [ -f "${DEVICE_LIB}" ] && [ -f "${SIM_LIB}" ]; then
        xcodebuild -create-xcframework \
            -library "${DEVICE_LIB}" -headers "${PROJECT_ROOT}/ios/Classes/llamafu.h" \
            -library "${SIM_LIB}" -headers "${PROJECT_ROOT}/ios/Classes/llamafu.h" \
            -output "${XCFRAMEWORK_PATH}"

        echo "XCFramework created at: ${XCFRAMEWORK_PATH}"
    else
        echo "Warning: Could not create XCFramework - libraries not found"
        echo "Device library: ${DEVICE_LIB} (exists: $([ -f "${DEVICE_LIB}" ] && echo yes || echo no))"
        echo "Simulator library: ${SIM_LIB} (exists: $([ -f "${SIM_LIB}" ] && echo yes || echo no))"
    fi
}

# Main build process
cd "${PROJECT_ROOT}"

if [ "${BUILD_DEVICE}" = true ]; then
    build_device
fi

if [ "${BUILD_SIMULATOR}" = true ]; then
    build_simulator
fi

if [ "${CREATE_XCFRAMEWORK}" = true ] && [ "${BUILD_DEVICE}" = true ] && [ "${BUILD_SIMULATOR}" = true ]; then
    create_xcframework
fi

echo ""
echo "=========================================="
echo "iOS Build Complete!"
echo "=========================================="
echo "Build output: ${BUILD_DIR}"
echo "Frameworks: ${OUTPUT_DIR}"
echo ""
echo "To use in Flutter:"
echo "  1. Run 'flutter pub get' in your Flutter project"
echo "  2. Run 'cd ios && pod install'"
echo "  3. Build your Flutter app for iOS"
echo "=========================================="
