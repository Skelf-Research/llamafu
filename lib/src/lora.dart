/// LoRA (Low-Rank Adaptation) adapter management for Llamafu.
///
/// Provides a clean API for loading, applying, and managing LoRA adapters
/// for model fine-tuning and specialization.

/// Information about a loaded LoRA adapter.
class AdapterInfo {
  /// Unique identifier for the adapter.
  final String id;

  /// File path of the adapter.
  final String path;

  /// Display name.
  final String name;

  /// Description of what the adapter does.
  final String? description;

  /// Current scale factor (0.0 - 1.0).
  final double scale;

  /// Whether the adapter is currently active.
  final bool isActive;

  /// Number of parameters in the adapter.
  final int parameterCount;

  /// Target modules the adapter modifies.
  final List<String> targetModules;

  const AdapterInfo({
    required this.id,
    required this.path,
    required this.name,
    this.description,
    required this.scale,
    required this.isActive,
    required this.parameterCount,
    required this.targetModules,
  });

  @override
  String toString() => 'AdapterInfo($name, scale: $scale, active: $isActive)';
}

/// A loaded LoRA adapter with lifecycle management.
///
/// Example:
/// ```dart
/// final adapter = await lora.load('path/to/adapter.gguf');
///
/// // Apply with default scale
/// await adapter.apply();
///
/// // Adjust scale dynamically
/// await adapter.setScale(0.5);
///
/// // Remove when done
/// await adapter.remove();
/// ```
class Adapter {
  final dynamic _llamafu;
  final dynamic _nativeHandle;
  final String _path;
  String _name;
  String? _description;
  double _scale;
  bool _isActive = false;

  Adapter._(
    this._llamafu,
    this._nativeHandle,
    this._path, {
    String? name,
    String? description,
    double scale = 1.0,
  })  : _name = name ?? _path.split('/').last.replaceAll('.gguf', ''),
        _description = description,
        _scale = scale;

  /// Get adapter information.
  AdapterInfo get info => AdapterInfo(
        id: _nativeHandle.toString(),
        path: _path,
        name: _name,
        description: _description,
        scale: _scale,
        isActive: _isActive,
        parameterCount: 0, // Would come from native
        targetModules: [],
      );

  /// Current scale factor.
  double get scale => _scale;

  /// Whether adapter is currently applied.
  bool get isActive => _isActive;

  /// Adapter name.
  String get name => _name;

  /// Adapter file path.
  String get path => _path;

  /// Apply this adapter to the model.
  ///
  /// [scale] controls the adapter's influence (0.0 to 1.0).
  /// Default is 1.0 (full effect).
  Future<void> apply({double? scale}) async {
    final effectiveScale = scale ?? _scale;
    await _llamafu.applyLoraAdapter(_nativeHandle, effectiveScale);
    _scale = effectiveScale;
    _isActive = true;
  }

  /// Update the scale of an active adapter.
  Future<void> setScale(double scale) async {
    if (!_isActive) {
      throw StateError('Adapter must be applied before setting scale');
    }
    await _llamafu.setLoraAdapterScale(_nativeHandle, scale);
    _scale = scale;
  }

  /// Remove this adapter from the model.
  Future<void> remove() async {
    if (_isActive) {
      await _llamafu.removeLoraAdapter(_nativeHandle);
      _isActive = false;
    }
  }

  /// Unload and free the adapter resources.
  Future<void> unload() async {
    await remove();
    await _llamafu.unloadLoraAdapter(_nativeHandle);
  }

  @override
  String toString() => 'Adapter($_name, scale: $_scale, active: $_isActive)';
}

/// Manager for LoRA adapters with high-level operations.
///
/// Provides a clean interface for loading, managing, and combining
/// multiple LoRA adapters.
///
/// Example:
/// ```dart
/// final lora = Lora(llamafu);
///
/// // Load adapters
/// final codeAdapter = await lora.load('code-adapter.gguf');
/// final styleAdapter = await lora.load('style-adapter.gguf');
///
/// // Apply single adapter
/// await codeAdapter.apply(scale: 0.8);
///
/// // Or apply multiple
/// await lora.applyMultiple([
///   (codeAdapter, 0.6),
///   (styleAdapter, 0.4),
/// ]);
///
/// // List active adapters
/// for (final adapter in lora.active) {
///   print('${adapter.name}: ${adapter.scale}');
/// }
///
/// // Clear all
/// await lora.clearAll();
/// ```
class Lora {
  final dynamic _llamafu;
  final List<Adapter> _adapters = [];

  /// Create a LoRA manager for the given Llamafu instance.
  Lora(this._llamafu);

  /// Get all loaded adapters.
  List<Adapter> get all => List.unmodifiable(_adapters);

  /// Get currently active adapters.
  List<Adapter> get active => _adapters.where((a) => a.isActive).toList();

  /// Get inactive (loaded but not applied) adapters.
  List<Adapter> get inactive => _adapters.where((a) => !a.isActive).toList();

  /// Number of loaded adapters.
  int get count => _adapters.length;

  /// Number of active adapters.
  int get activeCount => _adapters.where((a) => a.isActive).length;

  /// Load a LoRA adapter from file.
  ///
  /// [path] is the path to the .gguf adapter file.
  /// [name] is an optional display name.
  /// [description] describes what the adapter does.
  /// [autoApply] if true, applies the adapter immediately.
  /// [scale] is the initial scale factor.
  Future<Adapter> load(
    String path, {
    String? name,
    String? description,
    bool autoApply = false,
    double scale = 1.0,
  }) async {
    final handle = await _llamafu.loadLoraAdapter(path);

    final adapter = Adapter._(
      _llamafu,
      handle,
      path,
      name: name,
      description: description,
      scale: scale,
    );

    _adapters.add(adapter);

    if (autoApply) {
      await adapter.apply();
    }

    return adapter;
  }

  /// Load multiple adapters at once.
  Future<List<Adapter>> loadMultiple(List<String> paths) async {
    final adapters = <Adapter>[];
    for (final path in paths) {
      adapters.add(await load(path));
    }
    return adapters;
  }

  /// Apply multiple adapters with specified scales.
  ///
  /// Scales should sum to <= 1.0 for balanced effect.
  Future<void> applyMultiple(List<(Adapter, double)> adaptersWithScales) async {
    for (final (adapter, scale) in adaptersWithScales) {
      await adapter.apply(scale: scale);
    }
  }

  /// Remove all active adapters.
  Future<void> removeAll() async {
    for (final adapter in active) {
      await adapter.remove();
    }
  }

  /// Unload all adapters and free resources.
  Future<void> clearAll() async {
    for (final adapter in _adapters) {
      await adapter.unload();
    }
    _adapters.clear();
  }

  /// Unload a specific adapter.
  Future<void> unload(Adapter adapter) async {
    await adapter.unload();
    _adapters.remove(adapter);
  }

  /// Find adapter by name.
  Adapter? findByName(String name) {
    try {
      return _adapters.firstWhere((a) => a.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Find adapter by path.
  Adapter? findByPath(String path) {
    try {
      return _adapters.firstWhere((a) => a.path == path);
    } catch (_) {
      return null;
    }
  }

  /// Check if a path is compatible with the current model.
  Future<bool> isCompatible(String path) async {
    return await _llamafu.validateLoraCompatibility(path);
  }

  /// Get adapter info for all loaded adapters.
  List<AdapterInfo> getInfo() => _adapters.map((a) => a.info).toList();
}

/// Preset LoRA configurations for common use cases.
class LoraPresets {
  /// Code generation optimization.
  static const code = LoraPreset(
    name: 'Code',
    description: 'Optimized for code generation',
    recommendedScale: 0.8,
  );

  /// Creative writing style.
  static const creative = LoraPreset(
    name: 'Creative',
    description: 'Enhanced creative writing',
    recommendedScale: 0.7,
  );

  /// Instruction following.
  static const instruct = LoraPreset(
    name: 'Instruct',
    description: 'Better instruction following',
    recommendedScale: 0.9,
  );

  /// Chat/conversation style.
  static const chat = LoraPreset(
    name: 'Chat',
    description: 'Conversational responses',
    recommendedScale: 0.75,
  );
}

/// A preset configuration for LoRA usage.
class LoraPreset {
  final String name;
  final String description;
  final double recommendedScale;

  const LoraPreset({
    required this.name,
    required this.description,
    required this.recommendedScale,
  });
}
