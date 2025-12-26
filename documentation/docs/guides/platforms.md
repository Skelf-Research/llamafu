# Platform Notes

Platform-specific considerations and optimizations for Llamafu.

## Android

### Minimum Requirements

- API Level 21 (Android 5.0 Lollipop)
- ARM64 or ARM32 processor
- 2GB+ RAM recommended

### Gradle Configuration

```groovy
android {
    defaultConfig {
        minSdkVersion 21
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
    }
}
```

### Architecture Support

| ABI | Devices | Performance |
|-----|---------|-------------|
| arm64-v8a | Modern phones (2015+) | Best |
| armeabi-v7a | Older phones | Slower |
| x86_64 | Emulators, Chromebooks | Good |

### Memory Management

Android aggressively kills background apps. Handle this:

```dart
class ModelManager extends WidgetsBindingObserver {
  Llamafu? _llamafu;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Consider releasing model in low-memory situations
    }
  }
}
```

### Recommended Models

| Device RAM | Max Model Size | Quantization |
|------------|---------------|--------------|
| 4GB | ~500MB | Q4_0 |
| 6GB | ~1GB | Q4_K_M |
| 8GB+ | ~2GB | Q4_K_M or Q8_0 |

### Proguard Rules

Add to `android/app/proguard-rules.pro`:

```proguard
-keep class com.llamafu.** { *; }
-keepclassmembers class * {
    native <methods>;
}
```

## iOS

### Minimum Requirements

- iOS 12.0+
- A7 chip or later (iPhone 5s+)
- 2GB+ RAM recommended

### Metal GPU Acceleration

Metal is automatically enabled on supported devices:

```dart
final llamafu = await Llamafu.init(
  modelPath: modelPath,
  gpuLayers: 99,  // Full GPU offload
);
```

Devices with Metal support:
- iPhone 5s and later
- iPad Air and later
- iPad mini 2 and later

### App Store Guidelines

When submitting to App Store:

1. **Model Bundling** - Large models may require On-Demand Resources
2. **Privacy** - All inference is on-device, no data leaves the device
3. **Memory** - Test on lowest-supported device

### Podfile Configuration

```ruby
platform :ios, '12.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
    end
  end
end
```

### Recommended Models

| Device | Max Model Size | Notes |
|--------|---------------|-------|
| iPhone SE (1st) | ~500MB | Very limited |
| iPhone X/XS | ~1GB | GPU helps |
| iPhone 12+ | ~2GB | Excellent |
| iPad Pro | ~4GB | Best iOS experience |

## macOS

### Minimum Requirements

- macOS 10.15 (Catalina)+
- Intel or Apple Silicon

### Apple Silicon Optimization

Apple Silicon Macs provide excellent performance:

```dart
// Full GPU offload on M1/M2/M3
final llamafu = await Llamafu.init(
  modelPath: modelPath,
  gpuLayers: 99,
);
```

Performance comparison (Llama 2 7B Q4):

| Chip | Tokens/sec |
|------|------------|
| M1 | ~25 |
| M1 Pro | ~35 |
| M2 | ~30 |
| M2 Pro | ~45 |
| M3 | ~40 |

### Entitlements

For sandboxed apps, add to entitlements:

```xml
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

### Code Signing

Signed apps may need additional entitlements for dynamic libraries:

```xml
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

## Linux

### Distribution Support

Tested on:
- Ubuntu 20.04+
- Debian 11+
- Fedora 35+
- Arch Linux

### Dependencies

```bash
# Ubuntu/Debian
sudo apt-get install libgomp1

# Fedora
sudo dnf install libgomp

# Arch
sudo pacman -S openmp
```

### CUDA Support

For NVIDIA GPU acceleration:

```bash
# Install CUDA toolkit
sudo apt-get install nvidia-cuda-toolkit

# Build with CUDA
cmake -B build -DLLAMAFU_ENABLE_CUDA=ON
```

### Running in Docker

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY build/libllamafu.so /usr/lib/
COPY your-flutter-app /app

WORKDIR /app
CMD ["./your_flutter_app"]
```

## Windows

### Minimum Requirements

- Windows 10 version 1903+
- Visual C++ Redistributable 2019+
- 4GB+ RAM recommended

### Visual C++ Runtime

Users need the Visual C++ Redistributable:

```
https://aka.ms/vs/17/release/vc_redist.x64.exe
```

Or bundle it with your installer.

### Build Requirements

- Visual Studio 2019 or later
- C++ Desktop development workload
- Windows 10 SDK

### CUDA Support

For NVIDIA GPUs:

1. Install CUDA Toolkit
2. Add to PATH: `C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.0\bin`
3. Build with CUDA flag

### Path Considerations

Windows uses backslashes, but Llamafu accepts forward slashes:

```dart
// Both work
'C:/models/model.gguf'
'C:\\models\\model.gguf'
```

## Web (Experimental)

Llamafu does not currently support web platform due to:

- No native FFI support
- WebAssembly performance limitations
- Memory constraints

For web deployment, consider:
- Server-side inference with API
- WebLLM (separate library)

## Performance Comparison

Typical performance across platforms (SmolLM 135M Q8):

| Platform | Device | Tokens/sec |
|----------|--------|------------|
| Android | Pixel 7 | ~40 |
| Android | Samsung S23 | ~45 |
| iOS | iPhone 13 | ~50 |
| iOS | iPhone 15 Pro | ~70 |
| macOS | M2 MacBook | ~80 |
| Linux | i7-12700 | ~60 |
| Linux | Ryzen 5900X | ~65 |
| Windows | i7-12700 | ~55 |

## Troubleshooting by Platform

### Android: "Library not found"

Ensure native libraries are in the correct location:
```
android/src/main/jniLibs/
├── arm64-v8a/libllamafu.so
└── armeabi-v7a/libllamafu.so
```

### iOS: "Symbol not found"

Run `pod install` after updating:
```bash
cd ios && pod install
```

### macOS: "Library not loaded"

Check library path:
```bash
otool -L build/libllamafu.dylib
```

### Linux: "libgomp not found"

Install OpenMP:
```bash
sudo apt-get install libgomp1
```

### Windows: "Entry point not found"

Ensure VC++ Runtime is installed and matching architecture (x64).
