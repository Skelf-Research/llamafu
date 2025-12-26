# Llamafu Makefile
# Run 'make help' to see available targets

.PHONY: help setup deps build build-debug build-release build-android build-ios test test-all test-unit test-integration test-performance test-native test-real test-models format analyze docs audit clean clean-all

# Default target
help:
	@echo "Llamafu Development Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make setup          - Full dev environment setup (submodules + deps)"
	@echo "  make deps           - Install Flutter dependencies only"
	@echo ""
	@echo "Build:"
	@echo "  make build          - Build native library (debug)"
	@echo "  make build-debug    - Build native library (debug)"
	@echo "  make build-release  - Build native library (release)"
	@echo "  make build-android  - Build for Android"
	@echo "  make build-ios      - Build for iOS (no codesign)"
	@echo "  make build-local    - Build local with GPU support"
	@echo ""
	@echo "Test:"
	@echo "  make test           - Run comprehensive test suite"
	@echo "  make test-all       - Run all tests with coverage"
	@echo "  make test-unit      - Run unit tests only"
	@echo "  make test-integration - Run integration tests"
	@echo "  make test-performance - Run performance tests"
	@echo "  make test-native    - Run C++ native tests"
	@echo "  make test-real      - Run real model tests (set LLAMAFU_TEST_MODEL)"
	@echo "  make test-models    - Download test models (SmolLM 135M recommended)"
	@echo ""
	@echo "Code Quality:"
	@echo "  make format         - Format Dart code"
	@echo "  make analyze        - Analyze code for issues"
	@echo "  make docs           - Generate documentation"
	@echo "  make audit          - Security audit dependencies"
	@echo ""
	@echo "Clean:"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make clean-all      - Full clean including submodules"

# Setup
setup:
	./tools/setup-dev-env.sh

deps:
	flutter pub get

# Build targets
build: build-debug

build-debug:
	cmake -B build -DCMAKE_BUILD_TYPE=Debug
	cmake --build build --parallel

build-release:
	cmake -B build -DCMAKE_BUILD_TYPE=Release
	cmake --build build --parallel

build-android:
	./tools/build-android.sh --debug

build-ios:
	cd example && flutter build ios --no-codesign

build-local:
	./tools/build-local.sh --type Release --enable-gpu

# Test targets
test:
	flutter test test/llamafu_comprehensive_test.dart

test-all:
	dart ./tools/test_runner.dart --comprehensive --coverage

test-unit:
	flutter test test/llamafu_comprehensive_test.dart

test-integration:
	flutter test test/integration/

test-performance:
	dart ./tools/test_runner.dart --performance

test-native:
	dart ./tools/test_runner.dart --native

test-real:
	@if [ -z "$(LLAMAFU_TEST_MODEL)" ]; then \
		echo "Error: LLAMAFU_TEST_MODEL not set"; \
		echo "Usage: make test-real LLAMAFU_TEST_MODEL=/path/to/model.gguf"; \
		echo "Or run: make test-models && make test-real LLAMAFU_TEST_MODEL=test/fixtures/models/test-model.gguf"; \
		exit 1; \
	fi
	LLAMAFU_TEST_MODEL=$(LLAMAFU_TEST_MODEL) \
	LLAMAFU_TEST_LORA=$(LLAMAFU_TEST_LORA) \
	LLAMAFU_TEST_MMPROJ=$(LLAMAFU_TEST_MMPROJ) \
	flutter test test/integration/llamafu_real_model_test.dart

test-models:
	./tools/download-test-models.sh --smol

# Code quality
format:
	dart format .

analyze:
	dart analyze --fatal-warnings

docs:
	dart doc

audit:
	dart pub audit

# Clean
clean:
	./tools/clean.sh || true
	rm -rf build/
	flutter clean

clean-all: clean
	git submodule update --init --recursive --force
