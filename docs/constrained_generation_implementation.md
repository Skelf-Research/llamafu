# Constrained Generation Implementation in Llamafu

## Overview

Llamafu now supports constrained generation through integration with llama.cpp's grammar sampler functionality. This allows users to constrain model outputs to specific formats such as JSON, XML, or custom grammars defined in GBNF (Grammar-Based Noise-Free) format.

## Implementation Details

### Native Layer (C++)

1. **Header File (`llamafu.h`)**:
   - Added new data structures for grammar parameters:
     - `LlamafuGrammarParams` struct for grammar string and root symbol
   - Added new function signatures:
     - `llamafu_complete_with_grammar`
     - `llamafu_complete_with_grammar_stream`
     - `llamafu_grammar_sampler_init`
     - `llamafu_grammar_sampler_free`

2. **Implementation (`llamafu.cpp`)**:
   - Extended `Llamafu_s` struct to track grammar samplers
   - Implemented `llamafu_complete_with_grammar` for constrained text completion
   - Implemented `llamafu_complete_with_grammar_stream` for streaming constrained completion
   - Implemented `llamafu_grammar_sampler_init` for creating grammar samplers
   - Implemented `llamafu_grammar_sampler_free` for freeing grammar sampler resources
   - Integrated with llama.cpp's `llama_sampler_init_grammar` function

### Dart Layer

1. **FFI Bindings (`llamafu_bindings.dart`)**:
   - Added new Dart structs for grammar parameters
   - Added bindings for new native grammar functions
   - Added `GrammarSampler` class for managing grammar sampler resources

2. **High-level API (`llamafu_base.dart`)**:
   - Added `completeWithGrammar` method to the main `Llamafu` class
   - Added `GrammarSampler` class for grammar sampler management
   - Added `createGrammarSampler` method for creating reusable grammar samplers

## Supported Constraint Types

1. **GBNF Grammars**: Full support for GBNF (Grammar-Based Noise-Free) grammars
2. **JSON Generation**: Predefined grammars for JSON object generation
3. **XML Generation**: Predefined grammars for XML document generation
4. **Custom Formats**: Support for user-defined grammars for specific formats

## Usage Example

```dart
// Initialize the model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/your/model.gguf',
);

// Define a JSON grammar
final jsonGrammar = '''
root   ::= object
value  ::= object | array | string | number | ("true" | "false" | "null") ws

object ::=
  "{" ws (
            string ":" ws value
    ("," ws string ":" ws value)*
  )? "}" ws

array  ::=
  "[" ws (
            value
    ("," ws value)*
  )? "]" ws

string ::=
  "\\"" (
    [^\\"\\\\\x7F\x00-\x1F] |
    "\\\\" (["\\\\bfnrt] | "u" [0-9a-fA-F]{4}) # escapes
  )* "\\"" ws

number ::= ("-"? ([0-9] | [1-9] [0-9]{0,15})) ("." [0-9]+)? ([eE] [-+]? [0-9] [1-9]{0,15})? ws

# Optional space: by convention, applied in this grammar after literal chars when allowed
ws ::= | " " | "\n" [ \\t]{0,20}
''';

// Generate text constrained to JSON format
final result = await llamafu.completeWithGrammar(
  prompt: 'Generate a JSON object describing a person:',
  grammarStr: jsonGrammar,
  grammarRoot: 'root',
  maxTokens: 256,
  temperature: 0.8,
);

print(result);

// Clean up resources
llamafu.close();
```

## Integration with Other Features

The constrained generation implementation is fully compatible with other Llamafu features:

1. **LoRA Support**: Grammar constraints work with LoRA-adapted models
2. **Multi-modal Support**: Grammar constraints can be applied to text generated from multi-modal inputs
3. **Resource Management**: Automatic cleanup of grammar sampler resources when the main instance is closed

## Technical Details

1. **Memory Management**: Grammar samplers are automatically freed when the main Llamafu instance is closed
2. **Error Handling**: Comprehensive error handling for grammar operations with specific error codes
3. **Performance**: Grammar constraints are applied efficiently during token sampling without significant overhead
4. **Flexibility**: Support for both inline grammar definitions and reusable grammar sampler objects

## Limitations

1. **Grammar Complexity**: Very complex grammars may impact generation speed
2. **Format Support**: Currently limited to GBNF grammar format
3. **Streaming**: Streaming with grammar constraints requires careful implementation to maintain consistency

## Future Improvements

1. **Regex Support**: Add support for regex-based constraints
2. **JSON Schema**: Add support for JSON Schema-based constraints
3. **Custom Constraints**: Add support for custom constraint functions
4. **Performance Optimization**: Optimize grammar constraint application for complex grammars