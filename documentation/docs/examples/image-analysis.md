# Example: Image Analysis

Analyze images using vision-language models with Llamafu.

## Overview

This example demonstrates:
- Loading a vision model (VLM)
- Processing images from camera/gallery
- Generating image descriptions
- Asking questions about images

## Prerequisites

- Vision model (e.g., nanoLLaVA, LLaVA)
- Multimodal projector file (mmproj)
- `image_picker` package for camera/gallery access

```yaml
dependencies:
  llamafu: ^1.0.0
  image_picker: ^1.0.0
```

## Full Source Code

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:llamafu/llamafu.dart';

void main() {
  runApp(const ImageAnalysisApp());
}

class ImageAnalysisApp extends StatelessWidget {
  const ImageAnalysisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Analysis',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ImageAnalysisScreen(),
    );
  }
}

class ImageAnalysisScreen extends StatefulWidget {
  const ImageAnalysisScreen({super.key});

  @override
  State<ImageAnalysisScreen> createState() => _ImageAnalysisScreenState();
}

class _ImageAnalysisScreenState extends State<ImageAnalysisScreen> {
  Llamafu? _llamafu;
  File? _selectedImage;
  String _analysis = '';
  bool _isLoading = true;
  bool _isAnalyzing = false;
  final _questionController = TextEditingController();
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initModel();
  }

  Future<void> _initModel() async {
    try {
      _llamafu = await Llamafu.init(
        modelPath: 'assets/models/nanollava.gguf',
        mmprojPath: 'assets/models/nanollava-mmproj.gguf',
        contextSize: 2048,
      );

      if (!_llamafu!.isMultimodal) {
        throw Exception('Model does not support vision');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load vision model: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,  // Resize for efficiency
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _analysis = '';
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _analyzeImage(String prompt) async {
    if (_selectedImage == null || _llamafu == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _analysis = '';
    });

    try {
      // Read and encode image
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Create media input
      final imageInput = MediaInput(
        type: MediaType.image,
        data: base64Image,
        sourceType: DataSource.base64,
      );

      // Generate analysis with streaming
      await for (final token in _llamafu!.multimodalCompleteStream(
        prompt: prompt,
        mediaInputs: [imageInput],
        maxTokens: 300,
        temperature: 0.7,
      )) {
        setState(() {
          _analysis += token;
        });
      }
    } catch (e) {
      _showError('Analysis failed: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _askQuestion() {
    final question = _questionController.text.trim();
    if (question.isNotEmpty) {
      _analyzeImage(question);
      _questionController.clear();
    }
  }

  @override
  void dispose() {
    _llamafu?.dispose();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Analysis'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageSection(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  _buildQuestionInput(),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 16),
                  _buildAnalysisResult(),
                ],
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _selectedImage != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.contain,
              ),
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Select an image to analyze'),
                ],
              ),
            ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.camera),
          icon: const Icon(Icons.camera_alt),
          label: const Text('Camera'),
        ),
        ElevatedButton.icon(
          onPressed: () => _pickImage(ImageSource.gallery),
          icon: const Icon(Icons.photo_library),
          label: const Text('Gallery'),
        ),
      ],
    );
  }

  Widget _buildQuestionInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              hintText: 'Ask a question about the image...',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _askQuestion(),
            enabled: _selectedImage != null && !_isAnalyzing,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.send),
          onPressed: _selectedImage != null && !_isAnalyzing
              ? _askQuestion
              : null,
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _QuickActionChip(
          label: 'Describe',
          onPressed: _selectedImage != null && !_isAnalyzing
              ? () => _analyzeImage('Describe this image in detail.')
              : null,
        ),
        _QuickActionChip(
          label: 'Objects',
          onPressed: _selectedImage != null && !_isAnalyzing
              ? () => _analyzeImage('List all objects visible in this image.')
              : null,
        ),
        _QuickActionChip(
          label: 'Colors',
          onPressed: _selectedImage != null && !_isAnalyzing
              ? () => _analyzeImage('What are the main colors in this image?')
              : null,
        ),
        _QuickActionChip(
          label: 'Text',
          onPressed: _selectedImage != null && !_isAnalyzing
              ? () => _analyzeImage('Read any text visible in this image.')
              : null,
        ),
      ],
    );
  }

  Widget _buildAnalysisResult() {
    if (_isAnalyzing && _analysis.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_analysis.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Analysis',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isAnalyzing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const Divider(),
          SelectableText(_analysis),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _QuickActionChip({
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
```

## Key Concepts

### Loading Vision Model

```dart
_llamafu = await Llamafu.init(
  modelPath: 'nanollava.gguf',
  mmprojPath: 'nanollava-mmproj.gguf',  // Required!
);
```

### Creating MediaInput

```dart
final bytes = await imageFile.readAsBytes();
final base64Image = base64Encode(bytes);

final imageInput = MediaInput(
  type: MediaType.image,
  data: base64Image,
  sourceType: DataSource.base64,
);
```

### Multimodal Completion

```dart
final response = await _llamafu.multimodalComplete(
  prompt: 'Describe this image:',
  mediaInputs: [imageInput],
  maxTokens: 300,
);
```

## Tips

### Image Preprocessing

Resize images for better performance:

```dart
final pickedFile = await _picker.pickImage(
  source: source,
  maxWidth: 768,   // Vision models typically use 224-768px
  maxHeight: 768,
);
```

### Multiple Images

Compare or analyze multiple images:

```dart
final inputs = [
  MediaInput(type: MediaType.image, data: image1Base64),
  MediaInput(type: MediaType.image, data: image2Base64),
];

final comparison = await _llamafu.multimodalComplete(
  prompt: 'Compare these two images. What are the differences?',
  mediaInputs: inputs,
);
```

### Caching

For repeated analysis of the same image:

```dart
// Pre-process image
final result = await _llamafu.processImage(imageInput);
print('Image tokens: ${result.nTokens}');

// Use vision cache
await _llamafu.multimodalComplete(
  prompt: 'New question about the same image',
  mediaInputs: [imageInput],
  useVisionCache: true,  // Reuse processed image
);
```
