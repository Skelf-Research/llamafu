#!/bin/bash

# Llamafu Development Environment Setup Script
# Sets up the development environment for cross-platform native library development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

print_help() {
    echo "Llamafu Development Environment Setup"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --android             Setup Android development environment"
    echo "  --ios                 Setup iOS development environment (macOS only)"
    echo "  --desktop             Setup desktop development environment"
    echo "  --all                 Setup all available environments"
    echo "  --check               Check current environment status"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all             # Setup all environments"
    echo "  $0 --android         # Setup Android only"
    echo "  $0 --check           # Check environment status"
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
    case "$(uname -s)" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

check_command() {
    local cmd="$1"
    local name="$2"

    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>/dev/null | head -n1 || echo "unknown")
        log_success "$name is installed: $version"
        return 0
    else
        log_warning "$name is not installed"
        return 1
    fi
}

check_directory() {
    local dir="$1"
    local name="$2"

    if [ -d "$dir" ]; then
        log_success "$name found: $dir"
        return 0
    else
        log_warning "$name not found: $dir"
        return 1
    fi
}

check_base_requirements() {
    log_info "Checking base development requirements..."

    local all_good=true

    # Git
    if ! check_command "git" "Git"; then
        all_good=false
    fi

    # CMake
    if ! check_command "cmake" "CMake"; then
        all_good=false
        echo "  Install: https://cmake.org/download/"
    else
        local cmake_version=$(cmake --version | head -n1 | cut -d' ' -f3)
        local required_version="3.19.0"
        if ! printf '%s\n%s\n' "$required_version" "$cmake_version" | sort -V -C; then
            log_warning "CMake version $cmake_version is too old. Required: $required_version+"
            all_good=false
        fi
    fi

    # Platform-specific compilers
    local platform=$(detect_platform)
    case "$platform" in
        linux)
            if ! check_command "gcc" "GCC" && ! check_command "clang" "Clang"; then
                log_warning "No C++ compiler found"
                echo "  Install: sudo apt-get install build-essential"
                all_good=false
            fi
            ;;
        macos)
            if ! check_command "clang" "Clang"; then
                log_warning "Xcode command line tools not found"
                echo "  Install: xcode-select --install"
                all_good=false
            fi
            ;;
        windows)
            log_info "Windows detected - Visual Studio or Build Tools required"
            ;;
    esac

    return $all_good
}

check_flutter_environment() {
    log_info "Checking Flutter environment..."

    local all_good=true

    # Flutter
    if ! check_command "flutter" "Flutter"; then
        all_good=false
        echo "  Install: https://flutter.dev/docs/get-started/install"
    else
        # Run flutter doctor
        log_info "Running flutter doctor..."
        flutter doctor
    fi

    # Dart
    if ! check_command "dart" "Dart"; then
        all_good=false
    fi

    return $all_good
}

check_android_environment() {
    log_info "Checking Android development environment..."

    local all_good=true

    # Android SDK
    if [ -n "$ANDROID_HOME" ] && [ -d "$ANDROID_HOME" ]; then
        log_success "Android SDK found: $ANDROID_HOME"
    elif [ -n "$ANDROID_SDK_ROOT" ] && [ -d "$ANDROID_SDK_ROOT" ]; then
        log_success "Android SDK found: $ANDROID_SDK_ROOT"
    else
        log_warning "Android SDK not found"
        echo "  Set ANDROID_HOME or ANDROID_SDK_ROOT environment variable"
        all_good=false
    fi

    # Android NDK
    if [ -n "$ANDROID_NDK_ROOT" ] && [ -d "$ANDROID_NDK_ROOT" ]; then
        log_success "Android NDK found: $ANDROID_NDK_ROOT"
    else
        log_warning "Android NDK not found"
        echo "  Download from: https://developer.android.com/ndk/downloads"
        echo "  Set ANDROID_NDK_ROOT environment variable"
        all_good=false
    fi

    return $all_good
}

check_ios_environment() {
    local platform=$(detect_platform)

    if [ "$platform" != "macos" ]; then
        log_warning "iOS development only available on macOS"
        return false
    fi

    log_info "Checking iOS development environment..."

    local all_good=true

    # Xcode
    if command -v xcodebuild &> /dev/null; then
        local xcode_version=$(xcodebuild -version | head -n1)
        log_success "Xcode installed: $xcode_version"
    else
        log_warning "Xcode not found"
        echo "  Install from Mac App Store"
        all_good=false
    fi

    # iOS Simulator
    if command -v xcrun &> /dev/null && xcrun simctl list &> /dev/null; then
        log_success "iOS Simulator available"
    else
        log_warning "iOS Simulator not available"
        all_good=false
    fi

    return $all_good
}

check_submodules() {
    log_info "Checking git submodules..."

    cd "$PROJECT_ROOT"

    if [ ! -f "llama.cpp/CMakeLists.txt" ]; then
        log_warning "llama.cpp submodule not initialized"
        return false
    else
        log_success "llama.cpp submodule initialized"
        return true
    fi
}

setup_submodules() {
    log_info "Setting up git submodules..."

    cd "$PROJECT_ROOT"

    if [ ! -f "llama.cpp/CMakeLists.txt" ]; then
        log_info "Initializing llama.cpp submodule..."
        git submodule update --init --recursive
        log_success "Submodules initialized"
    else
        log_info "Updating submodules..."
        git submodule update --recursive
        log_success "Submodules updated"
    fi
}

setup_pre_commit_hooks() {
    log_info "Setting up pre-commit hooks..."

    cd "$PROJECT_ROOT"

    # Create pre-commit hook script
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Llamafu pre-commit hook
# Runs basic checks before allowing commits

set -e

echo "Running pre-commit checks..."

# Check for large files
large_files=$(find . -type f -size +10M -not -path "./.git/*" -not -path "./llama.cpp/*" -not -path "./build*/*" 2>/dev/null || true)
if [ -n "$large_files" ]; then
    echo "Error: Large files detected (>10MB):"
    echo "$large_files"
    echo "Please use Git LFS for large files or add to .gitignore"
    exit 1
fi

# Check Dart formatting (if dart available)
if command -v dart &> /dev/null; then
    echo "Checking Dart formatting..."
    if ! dart format --set-exit-if-changed lib/ test/ example/lib/ > /dev/null 2>&1; then
        echo "Error: Dart code is not properly formatted"
        echo "Run: dart format lib/ test/ example/lib/"
        exit 1
    fi
fi

# Check for debug prints and TODOs in critical files
critical_patterns=(
    "TODO.*FIXME"
    "console\.log"
    "print\s*\("
    "debugPrint"
)

for pattern in "${critical_patterns[@]}"; do
    if git diff --cached --name-only | xargs grep -l "$pattern" 2>/dev/null | grep -E "\.(dart|cpp|h)$" > /dev/null; then
        echo "Warning: Found '$pattern' in staged files"
        echo "Consider removing debug code before committing"
    fi
done

echo "Pre-commit checks passed!"
EOF

    chmod +x .git/hooks/pre-commit
    log_success "Pre-commit hooks installed"
}

create_dev_scripts() {
    log_info "Creating development convenience scripts..."

    # Create quick build script
    cat > "$PROJECT_ROOT/quick-build.sh" << 'EOF'
#!/bin/bash
# Quick build script for development

set -e

echo "Quick build for current platform..."

# Build native library
./scripts/build-local.sh --type Debug

# Run Dart tests
if command -v flutter &> /dev/null; then
    echo "Running Dart tests..."
    flutter test
fi

echo "Quick build complete!"
EOF

    chmod +x "$PROJECT_ROOT/quick-build.sh"

    # Create clean script
    cat > "$PROJECT_ROOT/clean-all.sh" << 'EOF'
#!/bin/bash
# Clean all build artifacts

set -e

echo "Cleaning all build artifacts..."

# Remove build directories
rm -rf build*
rm -rf artifacts

# Flutter clean
if command -v flutter &> /dev/null; then
    flutter clean
    cd example && flutter clean && cd ..
fi

echo "Clean complete!"
EOF

    chmod +x "$PROJECT_ROOT/clean-all.sh"

    log_success "Development scripts created"
}

setup_vscode_config() {
    log_info "Setting up VS Code configuration..."

    local vscode_dir="$PROJECT_ROOT/.vscode"
    mkdir -p "$vscode_dir"

    # VS Code settings
    cat > "$vscode_dir/settings.json" << 'EOF'
{
    "dart.flutterSdkPath": null,
    "dart.enableSdkFormatter": true,
    "dart.lineLength": 80,
    "editor.rulers": [80],
    "editor.formatOnSave": true,
    "files.associations": {
        "*.h": "c",
        "*.cpp": "cpp"
    },
    "C_Cpp.default.configurationProvider": "ms-vscode.cmake-tools",
    "cmake.buildDirectory": "${workspaceFolder}/build-native-${buildKit}",
    "cmake.generator": "Unix Makefiles"
}
EOF

    # VS Code launch configuration
    cat > "$vscode_dir/launch.json" << 'EOF'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug Example App",
            "type": "dart",
            "request": "launch",
            "program": "example/lib/main.dart"
        },
        {
            "name": "Run Tests",
            "type": "dart",
            "request": "launch",
            "program": "test/"
        }
    ]
}
EOF

    # VS Code tasks
    cat > "$vscode_dir/tasks.json" << 'EOF'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Build Native (Debug)",
            "type": "shell",
            "command": "./scripts/build-local.sh",
            "args": ["--type", "Debug"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        },
        {
            "label": "Build Native (Release)",
            "type": "shell",
            "command": "./scripts/build-local.sh",
            "args": ["--type", "Release"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        },
        {
            "label": "Clean All",
            "type": "shell",
            "command": "./clean-all.sh",
            "group": "build"
        },
        {
            "label": "Flutter Test",
            "type": "shell",
            "command": "flutter",
            "args": ["test"],
            "group": "test"
        }
    ]
}
EOF

    log_success "VS Code configuration created"
}

print_environment_status() {
    echo ""
    echo "=== Development Environment Status ==="

    check_base_requirements && log_success "Base requirements: OK" || log_warning "Base requirements: ISSUES"
    check_flutter_environment && log_success "Flutter environment: OK" || log_warning "Flutter environment: ISSUES"
    check_android_environment && log_success "Android environment: OK" || log_warning "Android environment: ISSUES"
    check_ios_environment && log_success "iOS environment: OK" || log_warning "iOS environment: ISSUES/UNAVAILABLE"
    check_submodules && log_success "Git submodules: OK" || log_warning "Git submodules: NOT INITIALIZED"

    echo "======================================"
    echo ""
}

# Parse command line arguments
SETUP_ANDROID=false
SETUP_IOS=false
SETUP_DESKTOP=false
CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --android)
            SETUP_ANDROID=true
            shift
            ;;
        --ios)
            SETUP_IOS=true
            shift
            ;;
        --desktop)
            SETUP_DESKTOP=true
            shift
            ;;
        --all)
            SETUP_ANDROID=true
            SETUP_IOS=true
            SETUP_DESKTOP=true
            shift
            ;;
        --check)
            CHECK_ONLY=true
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

# Main execution
main() {
    log_info "Llamafu Development Environment Setup"

    if [ "$CHECK_ONLY" = "true" ]; then
        print_environment_status
        exit 0
    fi

    # Always setup base requirements
    log_info "Setting up base development environment..."

    setup_submodules
    setup_pre_commit_hooks
    create_dev_scripts
    setup_vscode_config

    # Platform-specific setup
    if [ "$SETUP_ANDROID" = "true" ]; then
        log_info "Android development setup..."
        if ! check_android_environment; then
            log_warning "Android environment not ready. Please install Android SDK/NDK."
        fi
    fi

    if [ "$SETUP_IOS" = "true" ]; then
        log_info "iOS development setup..."
        if ! check_ios_environment; then
            log_warning "iOS environment not ready. Please install Xcode."
        fi
    fi

    if [ "$SETUP_DESKTOP" = "true" ]; then
        log_info "Desktop development setup..."
        if ! check_base_requirements; then
            log_warning "Desktop environment not ready. Please install required tools."
        fi
    fi

    log_success "Development environment setup complete!"
    echo ""
    echo "Next steps:"
    echo "1. Test the environment: ./scripts/setup-dev-env.sh --check"
    echo "2. Try a quick build: ./quick-build.sh"
    echo "3. Run tests: flutter test"
    echo "4. Open in VS Code: code ."
    echo ""
}

# Run main function
main "$@"