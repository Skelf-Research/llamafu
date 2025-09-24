#!/bin/bash

# Llamafu Local Build Script
# Builds native libraries for the current platform

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BUILD_TYPE="Release"
ENABLE_GPU="ON"
ENABLE_METAL="ON"
ENABLE_CUDA="OFF"
ENABLE_OPENCL="OFF"
CLEAN_BUILD="false"
PARALLEL_JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "4")

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_help() {
    echo "Llamafu Native Library Build Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE       Build type (Debug, Release) [default: Release]"
    echo "  -j, --jobs N          Number of parallel jobs [default: auto-detect]"
    echo "  -c, --clean           Clean build directory before building"
    echo "  --enable-gpu          Enable GPU support [default: ON]"
    echo "  --disable-gpu         Disable GPU support"
    echo "  --enable-metal        Enable Metal support (macOS/iOS) [default: ON]"
    echo "  --disable-metal       Disable Metal support"
    echo "  --enable-cuda         Enable CUDA support [default: OFF]"
    echo "  --disable-cuda        Disable CUDA support"
    echo "  --enable-opencl       Enable OpenCL support [default: OFF]"
    echo "  --disable-opencl      Disable OpenCL support"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Build with default settings"
    echo "  $0 -t Debug -c        # Clean debug build"
    echo "  $0 --enable-cuda      # Build with CUDA support"
    echo "  $0 -j 8               # Build with 8 parallel jobs"
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

detect_platform() {
    local platform=""
    local arch=""

    case "$(uname -s)" in
        Linux*)
            platform="linux"
            case "$(uname -m)" in
                x86_64|amd64)
                    arch="x64"
                    ;;
                aarch64|arm64)
                    arch="arm64"
                    ;;
                armv7l)
                    arch="arm"
                    ;;
                *)
                    arch="unknown"
                    ;;
            esac
            ;;
        Darwin*)
            platform="macos"
            case "$(uname -m)" in
                x86_64)
                    arch="x86_64"
                    ;;
                arm64)
                    arch="arm64"
                    ;;
                *)
                    arch="unknown"
                    ;;
            esac
            ;;
        CYGWIN*|MINGW*|MSYS*)
            platform="windows"
            case "$(uname -m)" in
                x86_64)
                    arch="x64"
                    ;;
                i686)
                    arch="x86"
                    ;;
                *)
                    arch="unknown"
                    ;;
            esac
            ;;
        *)
            platform="unknown"
            arch="unknown"
            ;;
    esac

    echo "${platform}-${arch}"
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

    # Platform-specific checks
    local platform_arch=$(detect_platform)
    case "$platform_arch" in
        linux-*)
            if ! command -v gcc &> /dev/null && ! command -v clang &> /dev/null; then
                log_error "No C++ compiler found. Please install GCC or Clang."
                exit 1
            fi
            ;;
        macos-*)
            if ! command -v clang &> /dev/null; then
                log_error "Xcode command line tools not found. Please install with: xcode-select --install"
                exit 1
            fi
            ;;
        windows-*)
            log_warning "Windows detected. Make sure Visual Studio or Build Tools are installed."
            ;;
    esac

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

configure_build() {
    local platform_arch=$(detect_platform)
    local build_dir="$PROJECT_ROOT/build-native-$platform_arch"

    log_info "Configuring build for $platform_arch..."
    log_info "Build directory: $build_dir"
    log_info "Build type: $BUILD_TYPE"

    if [ "$CLEAN_BUILD" = "true" ] && [ -d "$build_dir" ]; then
        log_info "Cleaning build directory..."
        rm -rf "$build_dir"
    fi

    mkdir -p "$build_dir"
    cd "$build_dir"

    # Configure CMake
    local cmake_args=(
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE"
        -DLLAMAFU_ENABLE_GPU="$ENABLE_GPU"
        -DLLAMAFU_ENABLE_METAL="$ENABLE_METAL"
        -DLLAMAFU_ENABLE_CUDA="$ENABLE_CUDA"
        -DLLAMAFU_ENABLE_OPENCL="$ENABLE_OPENCL"
    )

    # Platform-specific configuration
    case "$platform_arch" in
        macos-arm64)
            cmake_args+=(-DCMAKE_OSX_ARCHITECTURES=arm64)
            cmake_args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=10.15)
            ;;
        macos-x86_64)
            cmake_args+=(-DCMAKE_OSX_ARCHITECTURES=x86_64)
            cmake_args+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=10.15)
            ;;
        windows-*)
            if command -v cl &> /dev/null; then
                cmake_args+=(-G "Visual Studio 17 2022")
                if [[ "$platform_arch" == *"x64" ]]; then
                    cmake_args+=(-A x64)
                else
                    cmake_args+=(-A Win32)
                fi
            fi
            ;;
    esac

    log_info "CMake configuration: ${cmake_args[*]}"
    cmake "${cmake_args[@]}" "$PROJECT_ROOT"

    log_success "Configuration complete."
}

build_project() {
    local platform_arch=$(detect_platform)
    local build_dir="$PROJECT_ROOT/build-native-$platform_arch"

    log_info "Building project with $PARALLEL_JOBS parallel jobs..."

    cd "$build_dir"
    cmake --build . --config "$BUILD_TYPE" -j "$PARALLEL_JOBS"

    log_success "Build complete."
}

package_artifacts() {
    local platform_arch=$(detect_platform)
    local build_dir="$PROJECT_ROOT/build-native-$platform_arch"
    local artifacts_dir="$PROJECT_ROOT/artifacts/native/$platform_arch"

    log_info "Packaging artifacts..."

    mkdir -p "$artifacts_dir"

    # Find and copy the built library
    local lib_file=""
    case "$platform_arch" in
        windows-*)
            lib_file=$(find "$build_dir" -name "llamafu_native.lib" | head -n1)
            ;;
        *)
            lib_file=$(find "$build_dir" -name "libllamafu_native.a" | head -n1)
            ;;
    esac

    if [ -n "$lib_file" ] && [ -f "$lib_file" ]; then
        cp "$lib_file" "$artifacts_dir/"
        log_success "Library copied: $(basename "$lib_file")"
    else
        log_error "Built library not found!"
        exit 1
    fi

    # Copy header file
    if [ -f "$PROJECT_ROOT/android/src/main/cpp/llamafu.h" ]; then
        cp "$PROJECT_ROOT/android/src/main/cpp/llamafu.h" "$artifacts_dir/"
        log_success "Header copied: llamafu.h"
    fi

    # Create build info
    cat > "$artifacts_dir/build-info.txt" << EOF
Platform: $platform_arch
Build Type: $BUILD_TYPE
Build Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
GPU Support: $ENABLE_GPU
Metal Support: $ENABLE_METAL
CUDA Support: $ENABLE_CUDA
OpenCL Support: $ENABLE_OPENCL
EOF

    log_success "Artifacts packaged in: $artifacts_dir"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            BUILD_TYPE="$2"
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
        --enable-gpu)
            ENABLE_GPU="ON"
            shift
            ;;
        --disable-gpu)
            ENABLE_GPU="OFF"
            shift
            ;;
        --enable-metal)
            ENABLE_METAL="ON"
            shift
            ;;
        --disable-metal)
            ENABLE_METAL="OFF"
            shift
            ;;
        --enable-cuda)
            ENABLE_CUDA="ON"
            shift
            ;;
        --disable-cuda)
            ENABLE_CUDA="OFF"
            shift
            ;;
        --enable-opencl)
            ENABLE_OPENCL="ON"
            shift
            ;;
        --disable-opencl)
            ENABLE_OPENCL="OFF"
            shift
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

# Main execution
main() {
    log_info "Starting Llamafu native library build..."
    log_info "Platform: $(detect_platform)"

    check_dependencies
    initialize_submodules
    configure_build
    build_project
    package_artifacts

    log_success "Build completed successfully!"
    log_info "Artifacts location: $PROJECT_ROOT/artifacts/native/$(detect_platform)"
}

# Run main function
main "$@"