#!/bin/bash

# Download Test Models for Llamafu
# This script downloads small GGUF models for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODELS_DIR="${PROJECT_ROOT}/test/fixtures/models"

# Model URLs (using Hugging Face)
# TinyLlama is a small 1.1B model, quantized versions are ~500-700MB
TINYLLAMA_Q4_URL="https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
TINYLLAMA_Q4_FILE="tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"

# Smaller alternative: Qwen2 0.5B (~400MB Q4)
QWEN2_05B_Q4_URL="https://huggingface.co/Qwen/Qwen2-0.5B-Instruct-GGUF/resolve/main/qwen2-0_5b-instruct-q4_k_m.gguf"
QWEN2_05B_Q4_FILE="qwen2-0_5b-instruct-q4_k_m.gguf"

# Even smaller: SmolLM 135M (~100MB)
SMOLLM_135M_URL="https://huggingface.co/second-state/SmolLM-135M-Instruct-GGUF/resolve/main/SmolLM-135M-Instruct-Q8_0.gguf"
SMOLLM_135M_FILE="smollm-135m-instruct-q8_0.gguf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check for required tools
check_requirements() {
    local missing=false

    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        print_error "Neither curl nor wget found. Please install one of them."
        missing=true
    fi

    if [ "$missing" = true ]; then
        exit 1
    fi
}

# Download a file with progress
download_file() {
    local url="$1"
    local output="$2"
    local description="$3"

    print_info "Downloading: $description"
    print_info "URL: $url"
    print_info "Target: $output"

    if [ -f "$output" ]; then
        print_warning "File already exists: $output"
        read -p "Re-download? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping download"
            return 0
        fi
    fi

    # Create directory if needed
    mkdir -p "$(dirname "$output")"

    # Download with progress
    if command -v curl &> /dev/null; then
        curl -L --progress-bar -o "$output" "$url"
    else
        wget --show-progress -O "$output" "$url"
    fi

    if [ -f "$output" ]; then
        local size=$(du -h "$output" | cut -f1)
        print_success "Downloaded: $output ($size)"
    else
        print_error "Download failed: $output"
        return 1
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [options] [model]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -l, --list     List available models"
    echo "  -a, --all      Download all models"
    echo "  --tiny         Download TinyLlama 1.1B Q4 (~700MB)"
    echo "  --qwen         Download Qwen2 0.5B Q4 (~400MB)"
    echo "  --smol         Download SmolLM 135M Q8 (~100MB) [Recommended for CI]"
    echo ""
    echo "Models are downloaded to: $MODELS_DIR"
    echo ""
    echo "After downloading, run tests with:"
    echo "  LLAMAFU_TEST_MODEL=$MODELS_DIR/<model>.gguf flutter test test/integration/llamafu_real_model_test.dart"
}

# List available models
list_models() {
    echo "Available models for download:"
    echo ""
    echo "  1. SmolLM 135M Q8 (~100MB)"
    echo "     - Smallest option, good for quick CI tests"
    echo "     - URL: $SMOLLM_135M_URL"
    echo ""
    echo "  2. Qwen2 0.5B Q4 (~400MB)"
    echo "     - Small but capable instruction model"
    echo "     - URL: $QWEN2_05B_Q4_URL"
    echo ""
    echo "  3. TinyLlama 1.1B Q4 (~700MB)"
    echo "     - Good balance of size and capability"
    echo "     - URL: $TINYLLAMA_Q4_URL"
    echo ""
    echo "Already downloaded:"
    if [ -d "$MODELS_DIR" ]; then
        ls -lh "$MODELS_DIR"/*.gguf 2>/dev/null || echo "  (none)"
    else
        echo "  (none)"
    fi
}

# Download SmolLM (smallest)
download_smollm() {
    download_file "$SMOLLM_135M_URL" "$MODELS_DIR/$SMOLLM_135M_FILE" "SmolLM 135M Q8"
}

# Download Qwen2
download_qwen() {
    download_file "$QWEN2_05B_Q4_URL" "$MODELS_DIR/$QWEN2_05B_Q4_FILE" "Qwen2 0.5B Q4"
}

# Download TinyLlama
download_tinyllama() {
    download_file "$TINYLLAMA_Q4_URL" "$MODELS_DIR/$TINYLLAMA_Q4_FILE" "TinyLlama 1.1B Q4"
}

# Create symlink for default test model
create_default_symlink() {
    local model_file="$1"
    local default_link="$MODELS_DIR/test-model.gguf"

    if [ -f "$MODELS_DIR/$model_file" ]; then
        ln -sf "$model_file" "$default_link"
        print_success "Created default symlink: $default_link -> $model_file"
    fi
}

# Main
main() {
    print_header "Llamafu Test Model Downloader"

    check_requirements

    # Parse arguments
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                list_models
                exit 0
                ;;
            -a|--all)
                download_smollm
                download_qwen
                download_tinyllama
                create_default_symlink "$SMOLLM_135M_FILE"
                shift
                ;;
            --tiny|--tinyllama)
                download_tinyllama
                create_default_symlink "$TINYLLAMA_Q4_FILE"
                shift
                ;;
            --qwen)
                download_qwen
                create_default_symlink "$QWEN2_05B_Q4_FILE"
                shift
                ;;
            --smol|--smollm)
                download_smollm
                create_default_symlink "$SMOLLM_135M_FILE"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    echo ""
    print_header "Download Complete"

    echo ""
    echo "Downloaded models:"
    ls -lh "$MODELS_DIR"/*.gguf 2>/dev/null || echo "  (none)"

    echo ""
    echo "To run tests with a model:"
    echo "  export LLAMAFU_TEST_MODEL=$MODELS_DIR/<model>.gguf"
    echo "  flutter test test/integration/llamafu_real_model_test.dart"
    echo ""
    echo "Or use the default symlink:"
    echo "  export LLAMAFU_TEST_MODEL=$MODELS_DIR/test-model.gguf"
    echo "  flutter test test/integration/llamafu_real_model_test.dart"
}

main "$@"
