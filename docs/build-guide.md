# Build Guide

This guide covers building Llamafu from source, customizing build configurations, and setting up development environments.

## Prerequisites

### System Requirements

**Development Environment**
- **Operating System**: macOS 10.14+, Ubuntu 18.04+, or Windows 10+
- **Flutter**: 3.0 or higher
- **Dart**: 3.0 or higher
- **Git**: For submodule management

**Android Development**
- **Android Studio**: 2021.1.1 or higher
- **Android SDK**: API Level 21+ (Android 5.0)
- **Android NDK**: 21.4.7075529 or higher
- **CMake**: 3.18.1 or higher

**iOS Development**
- **Xcode**: 14.0 or higher
- **iOS Deployment Target**: 12.0 or higher
- **Command Line Tools**: Latest version

### Development Tools

**Recommended IDEs**
- **VS Code** with Flutter and Dart extensions
- **Android Studio** with Flutter plugin
- **IntelliJ IDEA** with Flutter plugin

**Build Tools**
```bash
# Install Flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor

# Install dependencies
flutter precache
```

## Quick Start Build

### Clone Repository

```bash
# Clone with submodules (recommended)
git clone --recursive https://github.com/your-org/llamafu.git
cd llamafu

# Or clone and initialize submodules separately
git clone https://github.com/your-org/llamafu.git
cd llamafu
git submodule update --init --recursive
```

### Build for Development

```bash
# Get Flutter dependencies
flutter pub get

# Run code generation (if needed)
flutter packages pub run build_runner build

# Build for Android (debug)
flutter build apk --debug

# Build for iOS (debug)
flutter build ios --debug
```

### Build for Release

```bash
# Android release with optimization
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/debug-info/

# iOS release
flutter build ios --release

# Create iOS archive
flutter build ipa --release
```

## Advanced Build Configuration

### Custom llama.cpp Build

**Environment Variables**
```bash
# Use custom llama.cpp directory
export LLAMA_CPP_DIR="/path/to/custom/llama.cpp"

# Set specific commit/branch
export LLAMA_CPP_COMMIT="abcd1234"

# Enable specific features
export LLAMA_CPP_FLAGS="-DLLAMA_CUBLAS=ON -DLLAMA_METAL=ON"
```

**Using Different llama.cpp Versions**
```bash
# Update submodule to specific version
cd llama.cpp
git checkout v0.0.1  # or specific commit
cd ..

# Clean and rebuild
flutter clean
flutter build apk
```

### Platform-Specific Configuration

#### Android Build Configuration

**gradle.properties**
```properties
# Performance optimization
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g
org.gradle.parallel=true
org.gradle.configureondemand=true
org.gradle.daemon=true

# Llamafu-specific
llamafu.llama_cpp.dir=llama.cpp
llamafu.enable_gpu=false
llamafu.optimization_level=3
```

**android/build.gradle**
```gradle
android {
    ndkVersion "21.4.7075529"

    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34

        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }

        externalNativeBuild {
            cmake {
                cppFlags "-std=c++17 -frtti -fexceptions"
                arguments "-DANDROID_STL=c++_shared",
                         "-DCMAKE_BUILD_TYPE=Release"
            }
        }
    }

    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                         'proguard-rules.pro'
        }
    }

    externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
            version "3.18.1"
        }
    }
}
```

#### iOS Build Configuration

**ios/Runner.xcodeproj/project.pbxproj Settings**
```xml
<!-- Build Settings -->
<key>IPHONEOS_DEPLOYMENT_TARGET</key>
<string>12.0</string>

<key>ENABLE_BITCODE</key>
<string>NO</string>

<key>OTHER_CPLUSPLUSFLAGS</key>
<array>
    <string>-std=c++17</string>
    <string>-stdlib=libc++</string>
</array>
```

**ios/Classes/CMakeLists.txt**
```cmake
cmake_minimum_required(VERSION 3.18)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Platform-specific optimizations
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "12.0")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fembed-bitcode")
endif()

# Add llama.cpp
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)

# Link libraries
target_link_libraries(llamafu_plugin
    PRIVATE llama ggml
)
```

## Build Scripts

### Automated Build Scripts

**build_android.sh**
```bash
#!/bin/bash
set -e

echo "Building Llamafu for Android..."

# Check prerequisites
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Please install Flutter first."
    exit 1
fi

# Initialize submodules if needed
if [ ! -f "llama.cpp/CMakeLists.txt" ]; then
    echo "Initializing llama.cpp submodule..."
    git submodule update --init --recursive
fi

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean
rm -rf build/
rm -rf android/build/

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build configurations
BUILD_TYPE=${1:-debug}
ABI_FILTERS=${2:-"arm64-v8a,armeabi-v7a"}
OPTIMIZATION=${3:-3}

echo "Building with:"
echo "  Build type: $BUILD_TYPE"
echo "  ABI filters: $ABI_FILTERS"
echo "  Optimization: $OPTIMIZATION"

# Set environment variables
export LLAMAFU_OPTIMIZATION_LEVEL=$OPTIMIZATION
export LLAMAFU_ABI_FILTERS=$ABI_FILTERS

# Build
if [ "$BUILD_TYPE" = "release" ]; then
    echo "Building release APK..."
    flutter build apk --release \
        --target-platform android-arm64,android-arm \
        --split-per-abi \
        --obfuscate \
        --split-debug-info=build/debug-info-android/
else
    echo "Building debug APK..."
    flutter build apk --debug
fi

echo "Build completed successfully!"
echo "Output files:"
find build/app/outputs/flutter-apk/ -name "*.apk" -exec echo "  {}" \;
```

**build_ios.sh**
```bash
#!/bin/bash
set -e

echo "Building Llamafu for iOS..."

# Check prerequisites
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Please install Flutter first."
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "Xcode not found. Please install Xcode first."
    exit 1
fi

# Initialize submodules if needed
if [ ! -f "llama.cpp/CMakeLists.txt" ]; then
    echo "Initializing llama.cpp submodule..."
    git submodule update --init --recursive
fi

# Clean previous builds
echo "Cleaning previous builds..."
flutter clean
rm -rf build/
rm -rf ios/build/

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build configurations
BUILD_TYPE=${1:-debug}
DEVICE_TYPE=${2:-device}

echo "Building with:"
echo "  Build type: $BUILD_TYPE"
echo "  Device type: $DEVICE_TYPE"

# Build
if [ "$BUILD_TYPE" = "release" ]; then
    if [ "$DEVICE_TYPE" = "simulator" ]; then
        echo "Building for iOS Simulator..."
        flutter build ios --release --simulator
    else
        echo "Building iOS IPA..."
        flutter build ipa --release
    fi
else
    echo "Building debug version..."
    flutter build ios --debug
fi

echo "Build completed successfully!"
```

### Custom Build Targets

**Makefile**
```makefile
# Llamafu Build Makefile

# Configuration
FLUTTER := flutter
BUILD_DIR := build
LLAMA_CPP_DIR := llama.cpp

# Default target
.PHONY: all
all: android ios

# Development builds
.PHONY: dev
dev: android-debug ios-debug

# Production builds
.PHONY: prod
prod: android-release ios-release

# Android targets
.PHONY: android android-debug android-release
android: android-debug

android-debug:
	@echo "Building Android debug..."
	$(FLUTTER) build apk --debug

android-release:
	@echo "Building Android release..."
	$(FLUTTER) build apk --release --obfuscate --split-debug-info=$(BUILD_DIR)/debug-info-android/

# iOS targets
.PHONY: ios ios-debug ios-release
ios: ios-debug

ios-debug:
	@echo "Building iOS debug..."
	$(FLUTTER) build ios --debug

ios-release:
	@echo "Building iOS release..."
	$(FLUTTER) build ipa --release

# Utilities
.PHONY: clean deps submodules
clean:
	$(FLUTTER) clean
	rm -rf $(BUILD_DIR)/
	rm -rf android/build/
	rm -rf ios/build/

deps:
	$(FLUTTER) pub get

submodules:
	git submodule update --init --recursive

# Update llama.cpp
.PHONY: update-llama
update-llama:
	cd $(LLAMA_CPP_DIR) && git pull origin main
	git add $(LLAMA_CPP_DIR)
	git commit -m "Update llama.cpp submodule"

# Test targets
.PHONY: test test-unit test-integration
test: test-unit

test-unit:
	$(FLUTTER) test

test-integration:
	$(FLUTTER) test integration_test/

# Lint and format
.PHONY: lint format
lint:
	$(FLUTTER) analyze

format:
	$(FLUTTER) format lib/ test/ integration_test/

# Documentation
.PHONY: docs
docs:
	dart doc .
```

## CI/CD Configuration

### GitHub Actions

**.github/workflows/build.yml**
```yaml
name: Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive

    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        channel: 'stable'

    - name: Get dependencies
      run: flutter pub get

    - name: Run tests
      run: flutter test

    - name: Analyze
      run: flutter analyze

  build-android:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive

    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        channel: 'stable'

    - name: Setup Android SDK
      uses: android-actions/setup-android@v2

    - name: Install NDK
      run: |
        sdkmanager "ndk;21.4.7075529"
        sdkmanager "cmake;3.18.1"

    - name: Get dependencies
      run: flutter pub get

    - name: Build APK
      run: flutter build apk --release

    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: android-apk
        path: build/app/outputs/flutter-apk/

  build-ios:
    needs: test
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v3
      with:
        submodules: recursive

    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.16.0'
        channel: 'stable'

    - name: Get dependencies
      run: flutter pub get

    - name: Build iOS
      run: flutter build ios --release --no-codesign

    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: ios-build
        path: build/ios/
```

### GitLab CI

**.gitlab-ci.yml**
```yaml
image: cirrusci/flutter:3.16.0

variables:
  GIT_SUBMODULE_STRATEGY: recursive
  FLUTTER_VERSION: "3.16.0"

stages:
  - test
  - build
  - deploy

cache:
  paths:
    - .pub-cache/

before_script:
  - export PATH="$PATH:$HOME/.pub-cache/bin"
  - flutter config --no-analytics
  - flutter precache

test:
  stage: test
  script:
    - flutter pub get
    - flutter analyze
    - flutter test
  coverage: '/lines......: \d+\.\d+\%/'

build-android:
  stage: build
  image: cirrusci/flutter:3.16.0-android
  script:
    - flutter pub get
    - flutter build apk --release
  artifacts:
    paths:
      - build/app/outputs/flutter-apk/
    expire_in: 1 week

build-ios:
  stage: build
  image: cirrusci/flutter:3.16.0
  tags:
    - macos
  script:
    - flutter pub get
    - flutter build ios --release --no-codesign
  artifacts:
    paths:
      - build/ios/
    expire_in: 1 week
```

## Development Environment Setup

### VS Code Configuration

**.vscode/settings.json**
```json
{
  "dart.debugExternalPackageLibraries": true,
  "dart.debugSdkLibraries": false,
  "dart.analysisServerFolding": true,
  "dart.closingLabels": true,
  "dart.completeFunctionCalls": true,
  "dart.enableCompletionCommitCharacters": true,
  "dart.previewFlutterUiGuides": true,
  "dart.previewFlutterUiGuidesCustomTracking": true,
  "editor.formatOnSave": true,
  "editor.rulers": [80],
  "editor.selectionHighlight": false,
  "editor.suggest.snippetsPreventQuickSuggestions": false,
  "editor.suggestSelection": "first",
  "editor.tabCompletion": "onlySnippets",
  "editor.wordBasedSuggestions": false,
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.formatOnType": true,
    "editor.selectionHighlight": false,
    "editor.suggest.snippetsPreventQuickSuggestions": false,
    "editor.suggestSelection": "first",
    "editor.tabCompletion": "onlySnippets",
    "editor.wordBasedSuggestions": false
  },
  "cmake.configureOnOpen": true,
  "C_Cpp.default.compilerPath": "/usr/bin/clang++",
  "C_Cpp.default.cppStandard": "c++17",
  "files.associations": {
    "*.h": "c",
    "*.cpp": "cpp"
  }
}
```

**.vscode/launch.json**
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (Debug)",
      "request": "launch",
      "type": "dart",
      "args": ["--debug"]
    },
    {
      "name": "Flutter (Release)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "release"
    },
    {
      "name": "Flutter (Profile)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile"
    }
  ]
}
```

### Docker Development Environment

**Dockerfile.dev**
```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-8-jdk \
    cmake \
    ninja-build \
    clang \
    && rm -rf /var/lib/apt/lists/*

# Set up Android SDK
ENV ANDROID_HOME="/opt/android-sdk"
ENV PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

# Install Android SDK
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    cd ${ANDROID_HOME}/cmdline-tools && \
    curl -o cmdtools.zip https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip && \
    unzip cmdtools.zip && \
    mv cmdline-tools latest && \
    rm cmdtools.zip

# Accept Android licenses
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools" "platforms;android-33" "build-tools;33.0.0" "ndk;21.4.7075529" "cmake;3.18.1"

# Install Flutter
ENV FLUTTER_HOME="/opt/flutter"
ENV PATH="${PATH}:${FLUTTER_HOME}/bin"

RUN git clone https://github.com/flutter/flutter.git ${FLUTTER_HOME} && \
    cd ${FLUTTER_HOME} && \
    git checkout stable && \
    flutter config --no-analytics && \
    flutter precache

# Set up workspace
WORKDIR /workspace

CMD ["/bin/bash"]
```

**docker-compose.dev.yml**
```yaml
version: '3.8'

services:
  llamafu-dev:
    build:
      context: .
      dockerfile: Dockerfile.dev
    volumes:
      - .:/workspace
      - flutter-cache:/opt/flutter/.pub-cache
    environment:
      - ANDROID_HOME=/opt/android-sdk
      - FLUTTER_HOME=/opt/flutter
    working_dir: /workspace
    tty: true
    stdin_open: true

volumes:
  flutter-cache:
```

## Troubleshooting

### Common Build Issues

**Issue: Submodule not initialized**
```bash
# Error: llama.cpp/CMakeLists.txt not found
# Solution:
git submodule update --init --recursive
```

**Issue: NDK version mismatch**
```bash
# Error: NDK version X not compatible
# Solution: Update android/build.gradle
android {
    ndkVersion "21.4.7075529"  // Use compatible version
}
```

**Issue: CMake not found**
```bash
# Error: CMake 3.18.1 was not found
# Solution: Install via Android Studio SDK Manager or
sdkmanager "cmake;3.18.1"
```

**Issue: iOS build fails on M1 Macs**
```bash
# Error: Architecture mismatch
# Solution: Add to ios/Podfile
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

### Build Environment Validation

**validate_build_env.sh**
```bash
#!/bin/bash

echo "Validating Llamafu build environment..."

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter not found"
    exit 1
else
    echo "✅ Flutter found: $(flutter --version | head -n1)"
fi

# Check Android tools (if building for Android)
if [[ "$1" == "android" || -z "$1" ]]; then
    if [ -z "$ANDROID_HOME" ]; then
        echo "❌ ANDROID_HOME not set"
    else
        echo "✅ ANDROID_HOME: $ANDROID_HOME"
    fi

    if ! command -v adb &> /dev/null; then
        echo "❌ Android SDK not found"
    else
        echo "✅ Android SDK found"
    fi
fi

# Check iOS tools (if on macOS and building for iOS)
if [[ "$OSTYPE" == "darwin"* ]] && [[ "$1" == "ios" || -z "$1" ]]; then
    if ! command -v xcodebuild &> /dev/null; then
        echo "❌ Xcode not found"
    else
        echo "✅ Xcode found: $(xcodebuild -version | head -n1)"
    fi
fi

# Check submodules
if [ ! -f "llama.cpp/CMakeLists.txt" ]; then
    echo "❌ llama.cpp submodule not initialized"
    echo "   Run: git submodule update --init --recursive"
else
    echo "✅ llama.cpp submodule initialized"
fi

# Check dependencies
echo "Checking Flutter dependencies..."
flutter pub get > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Flutter dependencies resolved"
else
    echo "❌ Flutter dependencies failed"
fi

echo "Environment validation complete!"
```

### Performance Optimization

**Build Performance Tips**
```bash
# Use parallel builds
export MAKEFLAGS="-j$(nproc)"

# Enable Gradle daemon
echo "org.gradle.daemon=true" >> ~/.gradle/gradle.properties
echo "org.gradle.parallel=true" >> ~/.gradle/gradle.properties

# Increase Gradle heap size
echo "org.gradle.jvmargs=-Xmx4g" >> ~/.gradle/gradle.properties

# Use Flutter build cache
flutter config --build-dir=build
```

**Incremental Build Setup**
```bash
# Configure Git hooks for efficient builds
cat > .git/hooks/post-merge << 'EOF'
#!/bin/bash
# Check if submodules changed
if git diff-tree -r --name-only --no-commit-id HEAD@{1} HEAD | grep -q "^llama.cpp"; then
    echo "Submodule changed, updating..."
    git submodule update --init --recursive
    flutter clean  # Force rebuild
fi
EOF

chmod +x .git/hooks/post-merge
```