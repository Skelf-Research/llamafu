# Contributing

Guidelines for contributing to Llamafu.

## Getting Started

### Prerequisites

- Flutter SDK 3.10.0+
- Dart SDK 3.1.0+
- CMake 3.18+
- C++17 compatible compiler
- Git with submodule support

### Development Setup

```bash
# Clone with submodules
git clone --recursive https://github.com/dipankar/llamafu.git
cd llamafu

# Setup development environment
make setup

# Install dependencies
flutter pub get

# Build native libraries
make build

# Run tests
make test
```

## Development Workflow

### Branch Strategy

- `main` - Stable release branch
- `develop` - Integration branch for features
- `feature/*` - Feature branches
- `fix/*` - Bug fix branches

### Making Changes

1. Create a branch from `develop`:
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature
   ```

2. Make your changes

3. Run tests and linting:
   ```bash
   make test
   dart analyze
   dart format --set-exit-if-changed .
   ```

4. Commit with clear messages:
   ```bash
   git commit -m "Add feature: description of change"
   ```

5. Push and create pull request:
   ```bash
   git push origin feature/your-feature
   ```

## Code Standards

### Dart Code

Follow the official Dart style guide:

```dart
// Good
class ModelLoader {
  final String modelPath;

  ModelLoader({required this.modelPath});

  Future<void> load() async {
    // Implementation
  }
}

// Avoid
class modelloader {
  String? model_path;
  load() async { /* ... */ }
}
```

Format with:
```bash
dart format .
```

Analyze with:
```bash
dart analyze --fatal-warnings
```

### C++ Code

Follow consistent style:

```cpp
// Function naming: snake_case
LlamafuError llamafu_init(LlamafuModelParams* params, Llamafu* out_llamafu) {
    // Parameter validation first
    if (!params || !out_llamafu) {
        return LLAMAFU_ERROR_INVALID_PARAM;
    }

    // Try-catch for exception safety
    try {
        // Implementation
        return LLAMAFU_SUCCESS;
    } catch (const std::exception& e) {
        return LLAMAFU_ERROR_UNKNOWN;
    }
}
```

### Commit Messages

Format:
```
<type>: <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `test`: Tests
- `build`: Build system
- `ci`: CI/CD

Examples:
```
feat: Add streaming generation support

Implements token-by-token streaming with callback support.
Includes timeout and cancellation handling.

fix: Resolve memory leak in LoRA adapter unloading

The adapter pointer was not being freed when removed from
the adapter map. Added proper cleanup in unload function.
```

## Project Structure

```
llamafu/
├── lib/
│   ├── llamafu.dart            # Public API exports
│   └── src/
│       ├── llamafu_base.dart   # Main Dart API
│       └── llamafu_bindings.dart # FFI bindings
├── android/
│   └── src/main/cpp/
│       ├── llamafu.h           # C API header
│       └── llamafu.cpp         # Implementation
├── ios/
│   └── Classes/                # iOS native code
├── test/
│   ├── llamafu_comprehensive_test.dart
│   └── fixtures/
│       └── test_data.dart      # Test utilities
├── example/                    # Example application
└── docs/                       # Documentation
```

## Adding Features

### Adding a New API Function

1. **Header Declaration** (`android/src/main/cpp/llamafu.h`):
   ```cpp
   LlamafuError llamafu_new_function(
       Llamafu llamafu,
       const char* input,
       char** output
   );
   ```

2. **Implementation** (`android/src/main/cpp/llamafu.cpp`):
   ```cpp
   LlamafuError llamafu_new_function(Llamafu llamafu, const char* input, char** output) {
       if (!llamafu || !input || !output) {
           return LLAMAFU_ERROR_INVALID_PARAM;
       }

       try {
           // Implementation
           return LLAMAFU_SUCCESS;
       } catch (const std::exception& e) {
           return LLAMAFU_ERROR_UNKNOWN;
       }
   }
   ```

3. **FFI Binding** (`lib/src/llamafu_bindings.dart`):
   ```dart
   typedef _NewFunctionNative = Int32 Function(
     Pointer<Void> llamafu,
     Pointer<Utf8> input,
     Pointer<Pointer<Utf8>> output,
   );
   typedef _NewFunctionDart = int Function(
     Pointer<Void> llamafu,
     Pointer<Utf8> input,
     Pointer<Pointer<Utf8>> output,
   );
   ```

4. **Dart API** (`lib/src/llamafu_base.dart`):
   ```dart
   Future<String> newFunction(String input) async {
     _ensureInitialized();

     final inputPtr = input.toNativeUtf8();
     final outputPtr = calloc<Pointer<Utf8>>();

     try {
       final result = _bindings.llamafu_new_function(
         _handle!,
         inputPtr,
         outputPtr,
       );

       if (result != LLAMAFU_SUCCESS) {
         throw LlamafuException.fromCode(result);
       }

       return outputPtr.value.toDartString();
     } finally {
       calloc.free(inputPtr);
       if (outputPtr.value != nullptr) {
         calloc.free(outputPtr.value);
       }
       calloc.free(outputPtr);
     }
   }
   ```

5. **Tests** (`test/llamafu_comprehensive_test.dart`):
   ```dart
   test('newFunction returns expected output', () async {
     final result = await llamafu.newFunction('test input');
     expect(result, isNotEmpty);
   });
   ```

## Testing

### Running Tests

```bash
# All tests
make test

# Unit tests only
flutter test

# Specific test file
flutter test test/llamafu_comprehensive_test.dart

# With coverage
make test-all
```

### Writing Tests

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  group('Feature tests', () {
    late Llamafu llamafu;

    setUpAll(() async {
      llamafu = await Llamafu.init(
        modelPath: testModelPath,
        contextSize: 512,
      );
    });

    tearDownAll(() {
      llamafu.close();
    });

    test('feature works correctly', () async {
      final result = await llamafu.feature();
      expect(result, expectedValue);
    });

    test('handles errors appropriately', () async {
      expect(
        () => llamafu.feature(invalidInput),
        throwsA(isA<LlamafuException>()),
      );
    });
  });
}
```

### Test Data

Use the test fixtures for generating test data:

```dart
import 'fixtures/test_data.dart';

final mockModel = TestData.generateMockGgufModel();
final mockImage = TestData.generateMockImage();
```

## Documentation

### Code Documentation

Document public APIs:

```dart
/// Generates text completion for the given prompt.
///
/// Parameters:
/// - [prompt]: The input text to complete
/// - [maxTokens]: Maximum tokens to generate (default: 256)
/// - [temperature]: Sampling temperature 0.0-2.0 (default: 0.7)
///
/// Returns the generated text.
///
/// Throws [LlamafuException] if generation fails.
///
/// Example:
/// ```dart
/// final result = await llamafu.complete(
///   prompt: 'Hello',
///   maxTokens: 100,
/// );
/// ```
Future<String> complete({
  required String prompt,
  int maxTokens = 256,
  double temperature = 0.7,
}) async {
  // Implementation
}
```

### Updating Documentation

When adding features:

1. Update relevant docs in `docs/`
2. Update README if public API changes
3. Add examples for new features
4. Update CHANGELOG.md

## Pull Request Process

### Before Submitting

- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No merge conflicts with develop

### PR Description

Include:
- Summary of changes
- Related issue numbers
- Testing performed
- Breaking changes (if any)

### Review Process

1. Automated checks must pass
2. At least one maintainer approval
3. All review comments addressed
4. Branch is up to date with develop

## Reporting Issues

### Bug Reports

Include:
- Llamafu version
- Flutter/Dart version
- Platform (Android/iOS)
- Model used
- Steps to reproduce
- Expected vs actual behavior
- Error messages/logs

### Feature Requests

Include:
- Use case description
- Proposed API (if applicable)
- Alternative approaches considered

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Keep discussions on topic

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Questions

- Open a GitHub Discussion for general questions
- Tag maintainers in issues for urgent matters
