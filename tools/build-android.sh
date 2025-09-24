#!/bin/bash

# Llamafu Android Build Script
# Builds native libraries for Android using NDK

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BUILD_TYPE="Release"
ANDROID_API="21"
ANDROID_NDK_VERSION="r25c"
BUILD_ABIS="arm64-v8a,armeabi-v7a,x86_64,x86"
CLEAN_BUILD="false"
PARALLEL_JOBS=$(nproc 2>/dev/null || echo "4")

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_help() {
    echo "Llamafu Android Native Library Build Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE       Build type (Debug, Release) [default: Release]"
    echo "  -a, --api LEVEL       Android API level [default: 21]"
    echo "  --abis LIST           Comma-separated list of ABIs to build [default: arm64-v8a,armeabi-v7a,x86_64,x86]"
    echo "  -j, --jobs N          Number of parallel jobs [default: auto-detect]"
    echo "  -c, --clean           Clean build directories before building"
    echo "  --ndk-path PATH       Path to Android NDK (if not in ANDROID_NDK_ROOT)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  ANDROID_NDK_ROOT      Path to Android NDK root directory"
    echo ""
    echo "Examples:"
    echo "  $0                            # Build all ABIs with default settings"
    echo "  $0 --abis arm64-v8a           # Build only arm64-v8a"
    echo "  $0 -t Debug -c                # Clean debug build"
    echo "  $0 --api 28 --abis arm64-v8a  # Build for API 28, arm64 only"
    echo ""
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_android_ndk() {
    log_info "Checking Android NDK..."

    if [ -z "$ANDROID_NDK_ROOT" ]; then
        # Try common locations
        local ndk_paths=(
            "$HOME/Android/Sdk/ndk/$ANDROID_NDK_VERSION"
            "$HOME/Library/Android/sdk/ndk/$ANDROID_NDK_VERSION"
            "/opt/android-ndk-$ANDROID_NDK_VERSION"
            "/usr/local/android-ndk-$ANDROID_NDK_VERSION"
        )

        for path in "${ndk_paths[@]}"; do
            if [ -d "$path" ]; then
                export ANDROID_NDK_ROOT="$path"
                break
            fi
        done

        if [ -z "$ANDROID_NDK_ROOT" ]; then
            log_error "Android NDK not found!"
            echo "Please set ANDROID_NDK_ROOT environment variable or install NDK to a standard location."
            echo "Download from: https://developer.android.com/ndk/downloads"
            exit 1
        fi
    fi

    if [ ! -f "$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" ]; then
        log_error "Invalid Android NDK at: $ANDROID_NDK_ROOT"
        echo "NDK toolchain not found. Please check your NDK installation."
        exit 1
    fi

    log_success "Android NDK found: $ANDROID_NDK_ROOT"
}

check_dependencies() {
    log_info "Checking build dependencies..."

    # Check for CMake
    if ! command -v cmake &> /dev/null; then
        log_error "CMake is required but not installed."
        echo "Please install CMake 3.19 or later."
        exit 1
    fi

    # Check CMake version
    local cmake_version=$(cmake --version | head -n1 | cut -d' ' -f3)
    local required_version="3.19.0"
    if ! printf '%s\n%s\n' "$required_version" "$cmake_version" | sort -V -C; then
        log_error "CMake version $cmake_version is too old. Required: $required_version or later."
        exit 1
    fi

    # Check for Git (for submodules)
    if ! command -v git &> /dev/null; then
        log_error "Git is required but not installed."
        exit 1
    fi

    check_android_ndk

    log_success "All dependencies satisfied."
}

initialize_submodules() {
    log_info "Initializing git submodules..."

    cd "$PROJECT_ROOT"

    if [ ! -f "llama.cpp/CMakeLists.txt" ]; then
        log_info "Initializing llama.cpp submodule..."
        git submodule update --init --recursive
    else
        log_info "Submodules already initialized."
    fi
}

build_abi() {
    local abi="$1"
    local build_dir="$PROJECT_ROOT/build-android-$abi"

    log_info "Building for ABI: $abi"

    if [ "$CLEAN_BUILD" = "true" ] && [ -d "$build_dir" ]; then
        log_info "Cleaning build directory for $abi..."
        rm -rf "$build_dir"
    fi

    mkdir -p "$build_dir"
    cd "$build_dir"

    # Configure CMake for Android
    local cmake_args=(
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake"
        -DANDROID_ABI="$abi"
        -DANDROID_PLATFORM="android-$ANDROID_API"
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
        -DLLAMAFU_ENABLE_GPU=ON
        -DLLAMAFU_ENABLE_CUDA=OFF
        -DLLAMAFU_ENABLE_OPENCL=OFF
        -DLLAMAFU_ENABLE_METAL=OFF
    )

    log_info "Configuring CMake for $abi..."
    cmake "${cmake_args[@]}" "$PROJECT_ROOT"

    log_info "Building for $abi with $PARALLEL_JOBS parallel jobs..."
    cmake --build . --config "$BUILD_TYPE" -j "$PARALLEL_JOBS"

    log_success "Build complete for $abi"
}

package_artifacts() {
    local artifacts_dir="$PROJECT_ROOT/artifacts/android"

    log_info "Packaging Android artifacts..."

    mkdir -p "$artifacts_dir"

    # Convert comma-separated ABIs to array
    IFS=',' read -ra ABIS <<< "$BUILD_ABIS"

    for abi in "${ABIS[@]}"; do
        local build_dir="$PROJECT_ROOT/build-android-$abi"
        local abi_artifacts_dir="$artifacts_dir/$abi"

        mkdir -p "$abi_artifacts_dir"

        # Find and copy the built library
        local lib_file=$(find "$build_dir" -name "libllamafu_native.a" | head -n1)

        if [ -n "$lib_file" ] && [ -f "$lib_file" ]; then
            cp "$lib_file" "$abi_artifacts_dir/"
            log_success "Library copied for $abi: $(basename "$lib_file")"
        else
            log_error "Built library not found for $abi!"
            continue
        fi

        # Copy header file
        if [ -f "$PROJECT_ROOT/android/src/main/cpp/llamafu.h" ]; then
            cp "$PROJECT_ROOT/android/src/main/cpp/llamafu.h" "$abi_artifacts_dir/"
        fi

        # Create build info
        cat > "$abi_artifacts_dir/build-info.txt" << EOF
Platform: android-$abi
Build Type: $BUILD_TYPE
Android API: $ANDROID_API
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
NDK Version: $(basename "$ANDROID_NDK_ROOT")
EOF
    done

    # Create combined archive
    cd "$artifacts_dir"
    tar -czf "../llamafu-android-${BUILD_TYPE,,}.tar.gz" .
    zip -r "../llamafu-android-${BUILD_TYPE,,}.zip" .

    log_success "Android artifacts packaged in: $artifacts_dir"
    log_success "Archives created: llamafu-android-${BUILD_TYPE,,}.tar.gz, llamafu-android-${BUILD_TYPE,,}.zip"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -a|--api)
            ANDROID_API="$2"
            shift 2
            ;;
        --abis)
            BUILD_ABIS="$2"
            shift 2
            ;;
        -j|--jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_BUILD="true"
            shift
            ;;
        --ndk-path)
            ANDROID_NDK_ROOT="$2"
            shift 2
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# Validate build type
case "$BUILD_TYPE" in
    Debug|Release|RelWithDebInfo|MinSizeRel)
        ;;
    *)
        log_error "Invalid build type: $BUILD_TYPE"
        echo "Valid types: Debug, Release, RelWithDebInfo, MinSizeRel"
        exit 1
        ;;
esac

# Validate Android API level
if ! [[ "$ANDROID_API" =~ ^[0-9]+$ ]] || [ "$ANDROID_API" -lt 16 ]; then
    log_error "Invalid Android API level: $ANDROID_API"
    echo "API level must be 16 or higher"
    exit 1
fi

# Main execution
main() {
    log_info "Starting Llamafu Android native library build..."
    log_info "Build Type: $BUILD_TYPE"
    log_info "Android API: $ANDROID_API"
    log_info "ABIs: $BUILD_ABIS"

    check_dependencies
    initialize_submodules

    # Convert comma-separated ABIs to array and build each
    IFS=',' read -ra ABIS <<< "$BUILD_ABIS"
    for abi in "${ABIS[@]}"; do
        build_abi "$abi"
    done

    package_artifacts

    log_success "Android build completed successfully!"
    log_info "Artifacts location: $PROJECT_ROOT/artifacts/android"
}

# Run main function
main "$@"