import 'dart:typed_data';
import 'dart:math';

class TestFixtures {
  static const String testModelPath = 'test/fixtures/models/test_model.gguf';
  static const String testMmprojPath = 'test/fixtures/models/test_mmproj.gguf';
  static const String testLoraPath = 'test/fixtures/lora/test_lora.bin';

  // Sample prompts for testing
  static const List<String> testPrompts = [
    'Hello, world!',
    'Complete this sentence: The weather today is',
    'Write a short story about a robot.',
    'Explain quantum computing in simple terms.',
    'What is the capital of France?',
    'Generate a list of programming languages.',
    'Describe the process of photosynthesis.',
    'Tell me a joke about computers.',
    'How do you make a sandwich?',
    'What are the benefits of exercise?',
  ];

  // Complex prompts for advanced testing
  static const List<String> complexPrompts = [
    '''
    You are a helpful AI assistant. Please analyze the following data and provide insights:

    Sales Data for Q1 2024:
    - January: \$125,000
    - February: \$134,000
    - March: \$156,000

    What trends do you see and what recommendations would you make?
    ''',
    '''
    Create a comprehensive business plan for a sustainable coffee shop that includes:
    1. Market analysis
    2. Financial projections
    3. Marketing strategy
    4. Operational plan
    5. Environmental initiatives
    ''',
    '''
    Debug this Python code and explain the issues:

    def fibonacci(n):
        if n <= 1:
            return n
        else:
            return fibonacci(n-1) + fibonacci(n-2)

    result = fibonacci(50)
    print(result)
    ''',
  ];

  // Multimodal prompts
  static const List<String> multimodalPrompts = [
    'Describe what you see in this image.',
    'What objects are present in this picture?',
    'Analyze the composition and colors in this image.',
    'What is the mood or atmosphere of this image?',
    'Count the number of people in this image.',
    'Describe the setting and environment shown.',
    'What activities are taking place in this image?',
    'Identify any text or signs visible in the image.',
  ];

  // JSON schemas for structured output testing
  static const Map<String, String> jsonSchemas = {
    'person': '''
    {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "number"},
        "email": {"type": "string", "format": "email"},
        "skills": {
          "type": "array",
          "items": {"type": "string"}
        },
        "address": {
          "type": "object",
          "properties": {
            "street": {"type": "string"},
            "city": {"type": "string"},
            "zipCode": {"type": "string"}
          },
          "required": ["city"]
        }
      },
      "required": ["name", "age"]
    }
    ''',
    'product': '''
    {
      "type": "object",
      "properties": {
        "id": {"type": "string"},
        "name": {"type": "string"},
        "price": {"type": "number", "minimum": 0},
        "category": {"type": "string"},
        "inStock": {"type": "boolean"},
        "tags": {
          "type": "array",
          "items": {"type": "string"}
        },
        "description": {"type": "string"}
      },
      "required": ["id", "name", "price", "category", "inStock"]
    }
    ''',
    'weather': '''
    {
      "type": "object",
      "properties": {
        "location": {"type": "string"},
        "temperature": {"type": "number"},
        "humidity": {"type": "number", "minimum": 0, "maximum": 100},
        "conditions": {
          "type": "string",
          "enum": ["sunny", "cloudy", "rainy", "snowy", "stormy"]
        },
        "windSpeed": {"type": "number", "minimum": 0},
        "forecast": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "day": {"type": "string"},
              "temperature": {"type": "number"},
              "conditions": {"type": "string"}
            },
            "required": ["day", "temperature", "conditions"]
          }
        }
      },
      "required": ["location", "temperature", "conditions"]
    }
    ''',
  };

  // Sample valid JSON objects for schema validation
  static const Map<String, List<String>> validJsonSamples = {
    'person': [
      '''
      {
        "name": "John Doe",
        "age": 30,
        "email": "john@example.com",
        "skills": ["JavaScript", "Python", "Dart"],
        "address": {
          "street": "123 Main St",
          "city": "New York",
          "zipCode": "10001"
        }
      }
      ''',
      '''
      {
        "name": "Jane Smith",
        "age": 25,
        "skills": ["Design", "Photography"],
        "address": {
          "city": "San Francisco"
        }
      }
      ''',
    ],
    'product': [
      '''
      {
        "id": "PROD-001",
        "name": "Wireless Headphones",
        "price": 99.99,
        "category": "Electronics",
        "inStock": true,
        "tags": ["wireless", "bluetooth", "music"],
        "description": "High-quality wireless headphones with noise cancellation."
      }
      ''',
      '''
      {
        "id": "PROD-002",
        "name": "Coffee Mug",
        "price": 12.50,
        "category": "Kitchen",
        "inStock": false,
        "tags": ["ceramic", "dishwasher-safe"]
      }
      ''',
    ],
    'weather': [
      '''
      {
        "location": "New York, NY",
        "temperature": 72,
        "humidity": 65,
        "conditions": "partly cloudy",
        "windSpeed": 8.5,
        "forecast": [
          {
            "day": "Monday",
            "temperature": 75,
            "conditions": "sunny"
          },
          {
            "day": "Tuesday",
            "temperature": 68,
            "conditions": "rainy"
          }
        ]
      }
      ''',
    ],
  };

  // Sample invalid JSON objects for testing validation
  static const Map<String, List<String>> invalidJsonSamples = {
    'person': [
      '{"age": 30}', // Missing required "name"
      '{"name": "John", "age": "thirty"}', // Wrong type for age
      '{"name": "John", "age": 30, "email": "invalid-email"}', // Invalid email format
    ],
    'product': [
      '{"name": "Product", "price": 10}', // Missing required fields
      '{"id": "1", "name": "Product", "price": -5, "category": "Test", "inStock": true}', // Negative price
    ],
  };

  // Template strings for testing
  static const Map<String, String> templates = {
    'email': '''
    Subject: {{subject}}

    Dear {{name}},

    {{body}}

    Best regards,
    {{sender}}
    ''',
    'report': '''
    # {{title}}

    Date: {{date}}
    Author: {{author}}

    ## Summary
    {{summary}}

    ## Details
    {{details}}

    ## Conclusions
    {{conclusions}}
    ''',
    'product_description': '''
    **{{product_name}}**

    Price: \${{price}}
    Category: {{category}}

    {{description}}

    Features:
    {{#features}}
    - {{.}}
    {{/features}}

    Available: {{#in_stock}}Yes{{/in_stock}}{{^in_stock}}No{{/in_stock}}
    ''',
  };

  // Template variables for testing
  static const Map<String, Map<String, dynamic>> templateVariables = {
    'email': {
      'subject': 'Important Update',
      'name': 'John Doe',
      'body': 'We wanted to inform you about the latest changes to our service.',
      'sender': 'The Support Team',
    },
    'report': {
      'title': 'Quarterly Sales Report',
      'date': '2024-03-31',
      'author': 'Jane Smith',
      'summary': 'Sales increased by 15% this quarter.',
      'details': 'Detailed analysis of sales performance across all product categories.',
      'conclusions': 'Strong growth in the mobile app category.',
    },
    'product_description': {
      'product_name': 'Smart Watch Pro',
      'price': '299.99',
      'category': 'Electronics',
      'description': 'Advanced smartwatch with health monitoring features.',
      'features': ['Heart rate monitoring', 'GPS tracking', 'Water resistant', '7-day battery'],
      'in_stock': true,
    },
  };

  // Audio test configurations
  static const List<Map<String, dynamic>> audioConfigs = [
    {
      'sample_rate': 8000,
      'channels': 1,
      'format': 'PCM_S16',
      'duration': 1.0,
    },
    {
      'sample_rate': 16000,
      'channels': 1,
      'format': 'PCM_F32',
      'duration': 5.0,
    },
    {
      'sample_rate': 44100,
      'channels': 2,
      'format': 'PCM_S16',
      'duration': 3.0,
    },
    {
      'sample_rate': 48000,
      'channels': 2,
      'format': 'PCM_F32',
      'duration': 2.0,
    },
  ];

  // Image test configurations
  static const List<Map<String, dynamic>> imageConfigs = [
    {
      'width': 224,
      'height': 224,
      'format': 'RGB',
      'channels': 3,
    },
    {
      'width': 512,
      'height': 512,
      'format': 'RGBA',
      'channels': 4,
    },
    {
      'width': 1024,
      'height': 768,
      'format': 'RGB',
      'channels': 3,
    },
    {
      'width': 64,
      'height': 64,
      'format': 'GRAYSCALE',
      'channels': 1,
    },
  ];

  // LoRA adapter test configurations
  static const List<Map<String, dynamic>> loraConfigs = [
    {
      'name': 'style_adapter',
      'scale': 1.0,
      'rank': 16,
      'alpha': 32,
    },
    {
      'name': 'domain_adapter',
      'scale': 0.8,
      'rank': 8,
      'alpha': 16,
    },
    {
      'name': 'language_adapter',
      'scale': 1.2,
      'rank': 32,
      'alpha': 64,
    },
  ];

  // Performance test parameters
  static const Map<String, dynamic> performanceParams = {
    'context_sizes': [512, 1024, 2048, 4096, 8192],
    'thread_counts': [1, 2, 4, 8],
    'batch_sizes': [1, 4, 8, 16, 32],
    'max_tokens_ranges': [50, 100, 200, 500, 1000],
    'temperature_values': [0.1, 0.3, 0.5, 0.7, 0.9, 1.0],
    'top_p_values': [0.1, 0.3, 0.5, 0.7, 0.9, 1.0],
    'top_k_values': [10, 20, 40, 80, 100],
    'repeat_penalty_values': [1.0, 1.05, 1.1, 1.15, 1.2],
  };

  // Error test cases
  static const List<Map<String, dynamic>> errorTestCases = [
    {
      'type': 'invalid_model_path',
      'params': {'model_path': '/nonexistent/model.gguf'},
      'expected_error': 'MODEL_LOAD_FAILED',
    },
    {
      'type': 'invalid_context_size',
      'params': {'context_size': -1},
      'expected_error': 'INVALID_PARAM',
    },
    {
      'type': 'invalid_thread_count',
      'params': {'threads': 0},
      'expected_error': 'INVALID_PARAM',
    },
    {
      'type': 'empty_prompt',
      'params': {'prompt': ''},
      'expected_error': 'INVALID_PARAM',
    },
    {
      'type': 'invalid_temperature',
      'params': {'temperature': -1.0},
      'expected_error': 'INVALID_PARAM',
    },
    {
      'type': 'invalid_max_tokens',
      'params': {'max_tokens': 0},
      'expected_error': 'INVALID_PARAM',
    },
  ];

  // Security test inputs
  static const List<String> maliciousInputs = [
    '../../../etc/passwd',
    '\\..\\..\\windows\\system32\\config\\sam',
    '<script>alert("xss")</script>',
    '${"\x00" * 1000}', // Null bytes
    'A' * 100000, // Very long string
    '\n\r\t\x0c\x0b', // Control characters
    '🔥' * 1000, // Unicode flood
    'SELECT * FROM users; DROP TABLE users;', // SQL injection attempt
    '{{7*7}}', // Template injection
    '\${system("rm -rf /")}', // Command injection
  ];

  // Stress test configurations
  static const Map<String, dynamic> stressTestParams = {
    'concurrent_requests': [5, 10, 20, 50, 100],
    'memory_pressure_mb': [100, 500, 1000, 2000],
    'long_running_minutes': [1, 5, 10, 30],
    'rapid_fire_requests': [100, 500, 1000, 5000],
  };

  // Helper methods to generate test data

  /// Creates a mock GGUF model file with specified size
  static Uint8List createMockGGUFModel({int sizeMB = 1}) {
    final sizeBytes = sizeMB * 1024 * 1024;
    final data = Uint8List(sizeBytes);

    // GGUF header
    data.setRange(0, 4, [0x47, 0x47, 0x55, 0x46]); // "GGUF"
    data.setRange(4, 8, [0x03, 0x00, 0x00, 0x00]); // version 3
    data.setRange(8, 12, [0x00, 0x00, 0x00, 0x00]); // tensor count
    data.setRange(12, 16, [0x00, 0x00, 0x00, 0x00]); // metadata kv count

    // Fill rest with random data
    final random = Random(42); // Seed for reproducibility
    for (int i = 16; i < sizeBytes; i++) {
      data[i] = random.nextInt(256);
    }

    return data;
  }

  /// Creates mock image data in PNG format
  static Uint8List createMockPNGImage({int width = 100, int height = 100}) {
    final random = Random(42);
    final imageData = <int>[];

    // PNG signature
    imageData.addAll([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    // IHDR chunk
    imageData.addAll([0x00, 0x00, 0x00, 0x0D]); // chunk length
    imageData.addAll([0x49, 0x48, 0x44, 0x52]); // "IHDR"
    imageData.addAll(_int32ToBytes(width));
    imageData.addAll(_int32ToBytes(height));
    imageData.addAll([0x08, 0x06, 0x00, 0x00, 0x00]); // bit depth, color type, etc.
    imageData.addAll([0x1F, 0x15, 0xC4, 0x89]); // CRC (placeholder)

    // IDAT chunk with mock compressed data
    final mockImageSize = width * height * 4; // RGBA
    imageData.addAll(_int32ToBytes(mockImageSize + 100)); // chunk length
    imageData.addAll([0x49, 0x44, 0x41, 0x54]); // "IDAT"

    // Mock compressed image data
    for (int i = 0; i < mockImageSize + 100; i++) {
      imageData.add(random.nextInt(256));
    }
    imageData.addAll([0x00, 0x00, 0x00, 0x00]); // CRC (placeholder)

    // IEND chunk
    imageData.addAll([0x00, 0x00, 0x00, 0x00]); // chunk length
    imageData.addAll([0x49, 0x45, 0x4E, 0x44]); // "IEND"
    imageData.addAll([0xAE, 0x42, 0x60, 0x82]); // CRC

    return Uint8List.fromList(imageData);
  }

  /// Creates mock audio data in WAV format
  static Uint8List createMockWAVAudio({
    int sampleRate = 44100,
    int channels = 2,
    double durationSeconds = 1.0,
  }) {
    const bitsPerSample = 16;
    final bytesPerSample = bitsPerSample ~/ 8;
    final numSamples = (sampleRate * durationSeconds * channels).round();
    final dataSize = numSamples * bytesPerSample;
    final fileSize = 36 + dataSize;

    final wavData = <int>[];

    // RIFF header
    wavData.addAll([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    wavData.addAll(_int32ToBytes(fileSize - 8));
    wavData.addAll([0x57, 0x41, 0x56, 0x45]); // "WAVE"

    // fmt chunk
    wavData.addAll([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    wavData.addAll([0x10, 0x00, 0x00, 0x00]); // chunk size
    wavData.addAll([0x01, 0x00]); // audio format (PCM)
    wavData.addAll(_int16ToBytes(channels));
    wavData.addAll(_int32ToBytes(sampleRate));
    wavData.addAll(_int32ToBytes(sampleRate * channels * bytesPerSample));
    wavData.addAll(_int16ToBytes(channels * bytesPerSample));
    wavData.addAll(_int16ToBytes(bitsPerSample));

    // data chunk
    wavData.addAll([0x64, 0x61, 0x74, 0x61]); // "data"
    wavData.addAll(_int32ToBytes(dataSize));

    // Generate sine wave audio data
    final random = Random(42);
    for (int i = 0; i < numSamples; i++) {
      final sample = (sin(2 * pi * 440 * i / sampleRate) * 16383).round();
      wavData.addAll(_int16ToBytes(sample + random.nextInt(200) - 100)); // Add some noise
    }

    return Uint8List.fromList(wavData);
  }

  /// Creates mock LoRA adapter data
  static Uint8List createMockLoRAAdapter({int sizeMB = 1}) {
    final sizeBytes = sizeMB * 1024 * 1024;
    final data = Uint8List(sizeBytes);

    // Mock LoRA header
    data.setRange(0, 4, [0x4C, 0x6F, 0x52, 0x41]); // "LoRA"
    data.setRange(4, 8, [0x01, 0x00, 0x00, 0x00]); // version
    data.setRange(8, 12, [0x10, 0x00, 0x00, 0x00]); // rank
    data.setRange(12, 16, [0x20, 0x00, 0x00, 0x00]); // alpha

    // Fill with mock weight data
    final random = Random(42);
    for (int i = 16; i < sizeBytes; i++) {
      data[i] = random.nextInt(256);
    }

    return data;
  }

  static List<int> _int32ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }

  static List<int> _int16ToBytes(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
    ];
  }

  /// Generates a random string of specified length
  static String generateRandomString(int length, {bool alphanumeric = true}) {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    const alphaChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

    final sourceChars = alphanumeric ? chars : alphaChars;
    return List.generate(length, (index) => sourceChars[random.nextInt(sourceChars.length)]).join();
  }

  /// Generates test prompts of various lengths
  static List<String> generateTestPrompts(int count) {
    final random = Random(42);
    final prompts = <String>[];

    for (int i = 0; i < count; i++) {
      final length = random.nextInt(500) + 10; // 10-510 characters
      final prompt = generateRandomString(length, alphanumeric: false);
      prompts.add('Test prompt $i: $prompt');
    }

    return prompts;
  }
}