# Llamafu Project Structure

This document describes the organization of the Llamafu Flutter plugin project.

## Root Directory Structure

```
llamafu/
├── android/                 # Android platform implementation
├── ios/                     # iOS platform implementation
├── lib/                     # Dart/Flutter library code
├── test/                    # Test suites (unit, integration, performance)
├── example/                 # Example Flutter application
├── docs/                    # Documentation
├── tools/                   # Build scripts and utilities
├── coverage/                # Test coverage reports
├── llama.cpp/              # llama.cpp submodule
├── .github/                # CI/CD workflows
├── CMakeLists.txt          # Main CMake configuration
├── pubspec.yaml            # Flutter package configuration
├── README.md               # Main project documentation
└── LICENSE                 # MIT license file
```

## Detailed Directory Breakdown

### `/android/` - Android Implementation
```
android/
├── src/main/cpp/
│   ├── llamafu.h           # C API header
│   ├── llamafu.cpp         # C++ implementation
│   └── CMakeLists.txt      # Android CMake configuration
└── build.gradle           # Android build configuration
```

### `/ios/` - iOS Implementation
```
ios/
├── Classes/
│   ├── llamafu.cpp         # C++ implementation (symlink)
│   ├── llamafu.h           # C API header (symlink)
│   └── LlamafuPlugin.swift # Swift plugin wrapper
└── llamafu.podspec         # CocoaPods specification
```

### `/lib/` - Dart Library
```
lib/
├── src/
│   ├── llamafu_base.dart   # Main Llamafu class
│   ├── llamafu_bindings.dart # FFI bindings
│   └── llamafu_types.dart  # Type definitions
└── llamafu.dart            # Public API exports
```

### `/test/` - Test Suites
```
test/
├── fixtures/
│   └── test_data.dart      # Mock data generators
├── utils/
│   └── test_helpers.dart   # Test utilities
├── native/
│   ├── test_llamafu_native.cpp        # C++ unit tests
│   ├── test_performance_native.cpp    # C++ performance tests
│   └── CMakeLists.txt                 # C++ test build config
├── integration/
│   └── llamafu_integration_test.dart  # Integration tests
├── performance/
│   └── llamafu_performance_test.dart  # Performance tests
└── llamafu_comprehensive_test.dart    # Main test suite
```

### `/docs/` - Documentation
```
docs/
├── archive/                         # Historical documentation
│   ├── ADVANCED_FEATURES_SUMMARY.md
│   ├── CONSTRAINED_GENERATION_SUMMARY.md
│   ├── FINAL_SUMMARY.md
│   ├── IMPROVEMENTS_SUMMARY.md
│   ├── LLAMA_CPP_API_COVERAGE_REPORT.md
│   ├── LORA_SUMMARY.md
│   ├── MULTIMODAL_SUMMARY.md
│   ├── PUBLISH_READY.md
│   ├── STATUS_REPORT.md
│   └── SUBMODULE_INTEGRATION_SUMMARY.md
├── android_build.md                 # Android build guide
├── ios_build.md                     # iOS build guide
├── BUILD_SETUP.md                   # General build setup
├── constrained_generation_implementation.md
├── lora_implementation.md
├── multimodal_implementation.md
├── NATIVE_LIBRARIES.md              # Native library documentation
├── PROJECT_STRUCTURE.md             # This file
└── TODO.md                          # Remaining tasks
```

### `/tools/` - Build Scripts and Utilities
```
tools/
├── build_android.sh        # Android build script
├── build_ios.sh            # iOS build script
├── clean.sh                # Cleanup script
├── build-android.sh        # Advanced Android build
├── build-local.sh          # Local build script
├── setup-dev-env.sh        # Development environment setup
└── test_runner.dart        # Comprehensive test runner
```

### `/example/` - Example Application
```
example/
├── lib/
│   └── main.dart           # Example app implementation
├── pubspec.yaml            # Example app dependencies
└── README.md               # Example usage guide
```

### `/.github/` - CI/CD Configuration
```
.github/
└── workflows/
    └── test.yml            # GitHub Actions test workflow
```

## Key Files

### Core Configuration
- **`pubspec.yaml`** - Flutter package metadata and dependencies
- **`CMakeLists.txt`** - Cross-platform native build configuration
- **`analysis_options.yaml`** - Dart static analysis rules

### Platform Bindings
- **`android/src/main/cpp/llamafu.cpp`** - Main C++ implementation
- **`android/src/main/cpp/llamafu.h`** - C API header with 100+ functions
- **`lib/src/llamafu_bindings.dart`** - Dart FFI bindings
- **`lib/src/llamafu_base.dart`** - High-level Dart API

### Documentation
- **`README.md`** - Main project documentation with usage examples
- **`CHANGELOG.md`** - Version history and changes
- **`LICENSE`** - MIT license

## Build Artifacts (Generated)

These directories are created during build but not tracked in git:

```
build/                      # CMake build directory
.dart_tool/                 # Dart tool cache
coverage/                   # Test coverage reports (tracked)
```

## Submodules

- **`llama.cpp/`** - Official llama.cpp repository as a Git submodule
  - Provides the core AI inference engine
  - Automatically managed by CMake build system
  - Updated periodically to latest stable version

## Navigation Guidelines

### For Developers
- Start with `/lib/llamafu.dart` for the public API
- Core implementation in `/android/src/main/cpp/`
- Test your changes with `/test/llamafu_comprehensive_test.dart`
- Build with scripts in `/tools/`

### For Users
- See `/README.md` for quick start guide
- Check `/example/` for usage examples
- Read `/docs/BUILD_SETUP.md` for custom builds

### For Contributors
- Run `/tools/test_runner.dart` for comprehensive testing
- Follow patterns in existing test files
- Update documentation in `/docs/` for new features
- Use the CI workflow in `/.github/workflows/test.yml`

## Clean Architecture

The project follows clean architecture principles:

1. **Presentation Layer**: Flutter UI (in example app)
2. **Application Layer**: Dart API (`/lib/src/llamafu_base.dart`)
3. **Infrastructure Layer**: FFI bindings (`/lib/src/llamafu_bindings.dart`)
4. **Native Layer**: C++ implementation (`/android/src/main/cpp/`)
5. **Core Engine**: llama.cpp submodule

This separation ensures:
- Platform independence
- Easy testing and mocking
- Clear responsibility boundaries
- Maintainable codebase

## Maintenance

Regular maintenance tasks:
- Update llama.cpp submodule for latest features
- Run full test suite before releases
- Update documentation for API changes
- Clean build artifacts with `/tools/clean.sh`
- Review and archive old documentation in `/docs/archive/`