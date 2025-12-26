# Chat Sessions

Build conversational applications with proper context management and chat templates.

## Chat Templates

Modern LLMs use specific prompt formats. Llamafu automatically applies the correct template.

### Automatic Template Detection

```dart
// Uses model's built-in template
final formatted = llamafu.applyChatTemplate(
  '',  // Empty string = use model's default
  [
    'user: Hello!',
    'assistant: Hi there! How can I help?',
    'user: What is the weather like?',
  ],
  addAssistant: true,
);
```

### Common Template Formats

=== "Llama 3"
    ```
    <|begin_of_text|><|start_header_id|>user<|end_header_id|>

    Hello!<|eot_id|><|start_header_id|>assistant<|end_header_id|>
    ```

=== "ChatML"
    ```
    <|im_start|>user
    Hello!<|im_end|>
    <|im_start|>assistant
    ```

=== "Mistral"
    ```
    [INST] Hello! [/INST]
    ```

### Custom Templates

```dart
final customTemplate = '''
{{#each messages}}
{{#ifEquals role "user"}}User: {{content}}
{{else}}Assistant: {{content}}
{{/ifEquals}}
{{/each}}
''';

final formatted = llamafu.applyChatTemplate(
  customTemplate,
  messages,
);
```

## Creating Chat Sessions

### Basic Session

```dart
final session = llamafu.createChatSession(
  systemPrompt: 'You are a helpful assistant.',
);

// Add user message and get response
session.addMessage('user', 'What is Python?');
final response = await session.generate(maxTokens: 200);

// Continue the conversation
session.addMessage('user', 'Show me an example');
final followUp = await session.generate(maxTokens: 300);
```

### Session with History

```dart
final session = llamafu.createChatSession(
  systemPrompt: 'You are a coding assistant.',
  history: [
    ChatMessage(role: 'user', content: 'What is a function?'),
    ChatMessage(role: 'assistant', content: 'A function is...'),
  ],
);
```

## Managing Context

### Context Window

The context window limits conversation length:

```dart
final session = llamafu.createChatSession();

// Check remaining context
print('Used tokens: ${session.usedTokens}');
print('Remaining: ${session.remainingTokens}');

// Conversation will auto-truncate old messages when full
```

### Manual Truncation

```dart
// Keep only the last N messages
session.truncateHistory(keepLast: 10);

// Or keep messages within token budget
session.truncateToFit(maxTokens: 1500);
```

### Sliding Window

```dart
final session = llamafu.createChatSession(
  contextStrategy: ContextStrategy.slidingWindow,
  windowSize: 2048,
);
```

## Streaming Responses

```dart
session.addMessage('user', 'Tell me a story');

await for (final token in session.generateStream(maxTokens: 500)) {
  stdout.write(token);
}

// Message is automatically added to history after completion
```

## System Prompts

### Setting the System Prompt

```dart
final session = llamafu.createChatSession(
  systemPrompt: '''You are a helpful coding assistant.
You write clean, well-documented code.
You explain your reasoning step by step.''',
);
```

### Updating System Prompt

```dart
session.setSystemPrompt('You are now a creative writer.');
```

## Multi-turn Example

```dart
class ChatBot {
  late final Llamafu _llamafu;
  late final ChatSession _session;

  Future<void> init() async {
    _llamafu = await Llamafu.init(
      modelPath: 'models/llama-3.2-1b.gguf',
      contextSize: 4096,
    );

    _session = _llamafu.createChatSession(
      systemPrompt: 'You are a friendly assistant.',
    );
  }

  Future<String> chat(String userMessage) async {
    _session.addMessage('user', userMessage);

    final response = await _session.generate(
      maxTokens: 500,
      temperature: 0.7,
    );

    return response;
  }

  List<ChatMessage> get history => _session.messages;

  void clearHistory() {
    _session.clear();
  }

  void dispose() {
    _llamafu.dispose();
  }
}
```

## Role-Playing

```dart
final session = llamafu.createChatSession(
  systemPrompt: '''You are Sherlock Holmes, the famous detective.
You speak in Victorian English and love solving mysteries.
You often reference your past cases and your friend Watson.''',
);

session.addMessage('user', 'Mr. Holmes, I need your help!');
final response = await session.generate();
// "Ah, do come in and have a seat by the fire..."
```

## Function Calling Pattern

Implement tool use with structured output:

```dart
final session = llamafu.createChatSession(
  systemPrompt: '''You are an assistant with access to tools.
When you need to use a tool, respond with JSON:
{"tool": "tool_name", "args": {...}}

Available tools:
- weather: Get weather for a location. Args: {"location": "city"}
- calculate: Do math. Args: {"expression": "2+2"}
''',
);

session.addMessage('user', 'What is the weather in Paris?');
final response = await session.generate();
// {"tool": "weather", "args": {"location": "Paris"}}

// Parse and execute tool, then continue
final toolResult = await executeWeatherTool('Paris');
session.addMessage('assistant', response);
session.addMessage('user', 'Tool result: $toolResult');
final finalResponse = await session.generate();
```

## Saving and Restoring Sessions

### Export History

```dart
final historyJson = session.toJson();
await File('chat_history.json').writeAsString(historyJson);
```

### Restore Session

```dart
final historyJson = await File('chat_history.json').readAsString();
final session = llamafu.createChatSession();
session.fromJson(historyJson);
```

## Best Practices

### 1. Keep System Prompts Concise

```dart
// Good: Focused instructions
systemPrompt: 'You are a helpful coding assistant. Be concise.';

// Avoid: Lengthy instructions that consume context
```

### 2. Handle Long Conversations

```dart
if (session.usedTokens > session.maxTokens * 0.8) {
  // Approaching limit, summarize or truncate
  session.truncateHistory(keepLast: 5);
}
```

### 3. Use Temperature Appropriately

```dart
// Lower for consistent responses
await session.generate(temperature: 0.3);

// Higher for creative responses
await session.generate(temperature: 0.9);
```

## Next Steps

- [Text Generation](text-generation.md) - Advanced generation options
- [Examples: Chatbot](../examples/chatbot.md) - Complete chatbot example
- [API: Chat Sessions](../api/inference.md)
