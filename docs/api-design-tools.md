# Tool Calling & JSON Output API Design

## Overview

This document describes the API design for tool calling and structured JSON output in Llamafu.

## JSON Output API

### Simple Usage

```dart
// Generate JSON matching a schema
final result = await llamafu.generateJson(
  prompt: 'Extract user info from: John is 25 years old',
  schema: {
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'age': {'type': 'integer'},
    },
    'required': ['name', 'age'],
  },
  maxTokens: 100,
);

// Returns Map<String, dynamic>
print(result); // {name: "John", age: 25}
```

### With Custom Types

```dart
// Define output structure
final result = await llamafu.generateJson(
  prompt: 'List 3 colors',
  schema: {
    'type': 'array',
    'items': {'type': 'string'},
    'minItems': 3,
    'maxItems': 3,
  },
);

print(result); // ["red", "blue", "green"]
```

### Raw JSON String

```dart
// Get raw JSON string instead of parsed
final jsonString = await llamafu.generateJsonString(
  prompt: 'Generate config',
  schema: schema,
);
```

## Tool Calling API

### Define Tools

```dart
// Define available tools
final tools = [
  Tool(
    name: 'get_weather',
    description: 'Get current weather for a location',
    parameters: {
      'type': 'object',
      'properties': {
        'location': {
          'type': 'string',
          'description': 'City name',
        },
        'unit': {
          'type': 'string',
          'enum': ['celsius', 'fahrenheit'],
        },
      },
      'required': ['location'],
    },
  ),
  Tool(
    name: 'search',
    description: 'Search the web',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
      },
      'required': ['query'],
    },
  ),
];
```

### Generate Tool Calls

```dart
// Generate tool call from user input
final toolCall = await llamafu.generateToolCall(
  prompt: "What's the weather in Paris?",
  tools: tools,
  maxTokens: 150,
);

// Returns ToolCall object
print(toolCall.name);       // "get_weather"
print(toolCall.arguments);  // {"location": "Paris"}
```

### Multiple Tool Calls

```dart
// Allow model to call multiple tools
final toolCalls = await llamafu.generateToolCalls(
  prompt: "Get weather in Paris and search for restaurants",
  tools: tools,
  maxCalls: 3,
);

for (final call in toolCalls) {
  print('${call.name}: ${call.arguments}');
}
```

### Tool Choice

```dart
// Force specific tool
final result = await llamafu.generateToolCall(
  prompt: userInput,
  tools: tools,
  toolChoice: ToolChoice.specific('get_weather'),
);

// Let model decide (default)
final result = await llamafu.generateToolCall(
  prompt: userInput,
  tools: tools,
  toolChoice: ToolChoice.auto,
);

// No tool call (just respond)
final result = await llamafu.generateToolCall(
  prompt: userInput,
  tools: tools,
  toolChoice: ToolChoice.none,
);
```

### Conversation with Tools

```dart
// Multi-turn conversation with tool execution
final messages = <Message>[
  Message.system('You are a helpful assistant with access to tools.'),
  Message.user("What's the weather in Tokyo?"),
];

// Get tool call
final toolCall = await llamafu.chatWithTools(
  messages: messages,
  tools: tools,
);

if (toolCall != null) {
  // Execute tool
  final weatherData = await getWeather(toolCall.arguments['location']);

  // Add tool result to conversation
  messages.add(Message.toolResult(
    toolCallId: toolCall.id,
    name: toolCall.name,
    result: weatherData,
  ));

  // Get final response
  final response = await llamafu.chat(messages: messages);
  print(response);
}
```

## Data Types

### Tool

```dart
class Tool {
  final String name;
  final String description;
  final Map<String, dynamic> parameters; // JSON Schema

  const Tool({
    required this.name,
    required this.description,
    required this.parameters,
  });
}
```

### ToolCall

```dart
class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });
}
```

### ToolChoice

```dart
enum ToolChoiceType { auto, none, specific }

class ToolChoice {
  final ToolChoiceType type;
  final String? toolName;

  const ToolChoice.auto() : type = ToolChoiceType.auto, toolName = null;
  const ToolChoice.none() : type = ToolChoiceType.none, toolName = null;
  const ToolChoice.specific(String name) : type = ToolChoiceType.specific, toolName = name;
}
```

### Message Types

```dart
abstract class Message {
  factory Message.system(String content);
  factory Message.user(String content);
  factory Message.assistant(String content);
  factory Message.toolCall(ToolCall call);
  factory Message.toolResult({
    required String toolCallId,
    required String name,
    required String result,
  });
}
```

## Implementation Notes

### JSON Schema to GBNF

Internally converts JSON Schema to GBNF grammar:
- `string` → `"\"" [^"]* "\""`
- `integer` → `"-"? [0-9]+`
- `number` → `"-"? [0-9]+ ("." [0-9]+)?`
- `boolean` → `"true" | "false"`
- `array` → `"[" (item ("," item)*)? "]"`
- `object` → `"{" (pair ("," pair)*)? "}"`

### Tool Call Format

Standard format for tool calls:

```json
{
  "id": "call_abc123",
  "name": "get_weather",
  "arguments": {
    "location": "Paris"
  }
}
```

Multiple calls:

```json
{
  "tool_calls": [
    {"id": "call_1", "name": "get_weather", "arguments": {"location": "Paris"}},
    {"id": "call_2", "name": "search", "arguments": {"query": "restaurants"}}
  ]
}
```

### Model Compatibility

Tool calling works best with models trained for it:
- Llama 3 Instruct
- Mistral Instruct
- Hermes 2 Pro
- Functionary

The API formats prompts according to each model's expected format.
