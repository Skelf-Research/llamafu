# Tool Calling and JSON Output

Llamafu supports tool calling (function calling) and structured JSON output generation, enabling LLMs to interact with external systems and produce consistently formatted responses.

## Overview

- **Tool Calling**: Define tools/functions the model can call, receive structured invocations
- **JSON Output**: Generate JSON that conforms to a specified schema
- **Grammar Constraints**: Uses GBNF grammars internally to ensure valid output

## Tool Calling

### Defining Tools

```dart
import 'package:llamafu/llamafu.dart';

// Define tools with name, description, and parameters
final tools = [
  Tool(
    name: 'get_weather',
    description: 'Get the current weather for a location',
    parameters: {
      'type': 'object',
      'properties': {
        'location': {
          'type': 'string',
          'description': 'City name, e.g., "Paris"',
        },
        'unit': {
          'type': 'string',
          'enum': ['celsius', 'fahrenheit'],
          'description': 'Temperature unit',
        },
      },
      'required': ['location'],
    },
  ),
  Tool(
    name: 'search_web',
    description: 'Search the web for information',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Search query',
        },
        'num_results': {
          'type': 'integer',
          'description': 'Number of results to return',
        },
      },
      'required': ['query'],
    },
  ),
];
```

### Using ToolBuilder

```dart
// Fluent API for building tools
final weatherTool = ToolBuilder('get_weather', 'Get weather for a location')
    .addString('location', 'City name', required: true)
    .addEnum('unit', 'Temperature unit', ['celsius', 'fahrenheit'])
    .build();

final searchTool = ToolBuilder('search_web', 'Search the web')
    .addString('query', 'Search query', required: true)
    .addInteger('num_results', 'Number of results')
    .build();
```

### Generating Tool Calls

```dart
// Initialize model
final llamafu = await Llamafu.init(
  modelPath: '/path/to/model.gguf',
  threads: 4,
  contextSize: 2048,
);

// Generate tool call
final toolCall = await llamafu.generateToolCall(
  prompt: "What's the weather in Tokyo?",
  tools: [weatherTool, searchTool],
  maxTokens: 150,
  temperature: 0.1,
);

// Use the result
print('Tool: ${toolCall.name}');           // "get_weather"
print('Args: ${toolCall.arguments}');      // {"location": "Tokyo"}

// Execute the tool
if (toolCall.name == 'get_weather') {
  final weather = await getWeatherApi(toolCall.arguments['location']);
  print('Weather: $weather');
}
```

### Tool Choice Options

```dart
// Let model decide (default)
final call = await llamafu.generateToolCall(
  prompt: userInput,
  tools: tools,
  toolChoice: ToolChoice.auto(),
);

// Force a specific tool
final call = await llamafu.generateToolCall(
  prompt: userInput,
  tools: tools,
  toolChoice: ToolChoice.specific('get_weather'),
);

// Must call some tool
final call = await llamafu.generateToolCall(
  prompt: userInput,
  tools: tools,
  toolChoice: ToolChoice.required(),
);

// Never call tools (just respond)
final call = await llamafu.generateToolCall(
  prompt: userInput,
  tools: tools,
  toolChoice: ToolChoice.none(),
);
```

### Multiple Tool Calls

```dart
// Allow multiple tools in one response
final calls = await llamafu.generateToolCalls(
  prompt: "Get weather in Paris and search for restaurants",
  tools: tools,
  allowMultipleCalls: true,
  maxCalls: 3,
);

for (final call in calls) {
  print('${call.name}: ${call.arguments}');
}
```

### Conversation with Tools

```dart
// Build conversation with tool results
final messages = <Message>[
  Message.system('You are a helpful assistant with access to tools.'),
  Message.user("What's the weather in London?"),
];

// Get tool call
final toolCall = await llamafu.chatWithTools(
  messages: messages,
  tools: tools,
);

if (toolCall != null) {
  // Execute tool and get result
  final result = await executeWeatherApi(toolCall.arguments);

  // Add tool result to conversation
  messages.add(Message.toolResult(
    toolCallId: toolCall.id,
    name: toolCall.name,
    result: result,
  ));

  // Get final response
  final response = await llamafu.chat(messages: messages);
  print(response);
}
```

## JSON Output

### Basic JSON Generation

```dart
// Generate JSON matching a schema
final result = await llamafu.generateJson(
  prompt: 'Extract: John Smith is 32 years old and lives in Boston',
  schema: {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'age': {'type': 'integer'},
      'city': {'type': 'string'},
    },
    'required': ['name', 'age', 'city'],
  },
  maxTokens: 100,
);

// Result is valid JSON
print(result);  // {"name": "John Smith", "age": 32, "city": "Boston"}
```

### Using JsonSchemaBuilder

```dart
// Fluent API for building schemas
final schema = JsonSchemaBuilder()
    .addString('name', required: true)
    .addInteger('age', required: true)
    .addString('email')
    .addBoolean('active')
    .build();

final result = await llamafu.generateJson(
  prompt: 'Create a user profile for Alice, age 28, email alice@example.com',
  schema: schema,
);
```

### Complex Schemas

```dart
// Nested objects
final schema = {
  'type': 'object',
  'properties': {
    'user': {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'email': {'type': 'string'},
      },
    },
    'preferences': {
      'type': 'object',
      'properties': {
        'theme': {'type': 'string', 'enum': ['light', 'dark']},
        'notifications': {'type': 'boolean'},
      },
    },
  },
};

final result = await llamafu.generateJson(
  prompt: 'Create profile for Bob who prefers dark theme with notifications',
  schema: schema,
);
```

### Arrays

```dart
// Generate arrays
final schema = {
  'type': 'array',
  'items': {
    'type': 'object',
    'properties': {
      'task': {'type': 'string'},
      'priority': {'type': 'integer'},
    },
  },
  'minItems': 3,
};

final result = await llamafu.generateJson(
  prompt: 'Generate a todo list with 3 tasks for a software developer',
  schema: schema,
);

// Result: [{"task": "Review PR", "priority": 1}, ...]
```

### Streaming JSON

```dart
// Stream JSON as it's generated
final stream = llamafu.generateJsonStream(
  prompt: 'Generate a detailed product description',
  schema: productSchema,
);

await for (final chunk in stream) {
  stdout.write(chunk);
}
```

### JSON Validation

```dart
// Validate JSON against schema
final isValid = await llamafu.validateJson(
  jsonString: '{"name": "Test", "value": 42}',
  schema: {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'value': {'type': 'integer'},
    },
    'required': ['name', 'value'],
  },
);

print('Valid: $isValid');
```

## Model Compatibility

Tool calling works best with models trained for it:

- **Llama 3 Instruct** - Good tool calling support
- **Mistral Instruct** - Reliable function calling
- **Hermes 2 Pro** - Specifically trained for tools
- **Functionary** - Optimized for function calling

The API formats prompts according to each model's expected format for tool definitions.

## Grammar Constraints

Internally, tool calling and JSON output use GBNF grammars to constrain model output:

```dart
// Convert JSON Schema to grammar manually
final grammar = await llamafu.schemaToGrammar(schema);

// Use with completeWithGrammar for custom control
final result = await llamafu.completeWithGrammar(
  prompt: prompt,
  grammarStr: grammar,
  maxTokens: 200,
);
```

## Best Practices

### Tool Design

1. **Clear descriptions** - Help the model understand when to use each tool
2. **Specific parameters** - Define parameter types and constraints clearly
3. **Required fields** - Mark essential parameters as required
4. **Enums for choices** - Use enums for fixed option sets

### JSON Generation

1. **Define required fields** - Ensure essential data is always present
2. **Use appropriate types** - Match data types to expected values
3. **Limit schema complexity** - Simpler schemas produce more reliable output
4. **Test with examples** - Verify schemas work with your prompts

### Performance

1. **Low temperature** - Use 0.0-0.2 for deterministic tool calls
2. **Reasonable token limits** - Match to expected output size
3. **Appropriate models** - Use instruction-tuned models for best results

## Error Handling

```dart
try {
  final toolCall = await llamafu.generateToolCall(
    prompt: userInput,
    tools: tools,
  );

  if (toolCall.name == 'unknown') {
    // Model didn't understand the request
    print('Could not determine which tool to call');
  } else {
    await executeToolCall(toolCall);
  }
} on LlamafuException catch (e) {
  switch (e.code) {
    case LlamafuErrorCode.grammarInitFailed:
      print('Invalid tool/schema definition');
      break;
    case LlamafuErrorCode.outOfMemory:
      print('Model too large for available memory');
      break;
    default:
      print('Error: ${e.message}');
  }
}
```

## Examples

### Weather Assistant

```dart
final weatherTool = Tool(
  name: 'get_weather',
  description: 'Get current weather',
  parameters: {
    'type': 'object',
    'properties': {
      'city': {'type': 'string'},
    },
    'required': ['city'],
  },
);

Future<String> weatherAssistant(String query) async {
  final call = await llamafu.generateToolCall(
    prompt: query,
    tools: [weatherTool],
  );

  if (call.name == 'get_weather') {
    final weather = await fetchWeather(call.arguments['city']);
    return 'The weather in ${call.arguments['city']} is $weather';
  }

  return 'I can only help with weather queries';
}
```

### Data Extraction

```dart
Future<Map<String, dynamic>> extractContactInfo(String text) async {
  return await llamafu.generateJson(
    prompt: 'Extract contact information from: $text',
    schema: {
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'email': {'type': 'string'},
        'phone': {'type': 'string'},
        'company': {'type': 'string'},
      },
    },
  );
}

// Usage
final contact = await extractContactInfo(
  'Call John at john@example.com or 555-1234. He works at Acme Corp.'
);
print(contact);
// {"name": "John", "email": "john@example.com", "phone": "555-1234", "company": "Acme Corp"}
```

## Related Documentation

- [API Reference](api-reference.md) - Complete API documentation
- [Getting Started](getting-started.md) - Basic usage guide
- [Performance Guide](performance-guide.md) - Optimization tips
