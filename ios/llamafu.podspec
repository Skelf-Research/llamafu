#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint llamafu.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'llamafu'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter package for running language models on device.'
  s.description      = <<-DESC
A Flutter package for running language models on device with support for completion,
instruct mode, tool calling, streaming, constrained generation, multimodal inference,
and LoRA adapters. Powered by llama.cpp for efficient on-device inference.
                       DESC
  s.homepage         = 'https://github.com/dipankar/llamafu'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Llamafu Team' => 'email@example.com' }
  s.source           = { :path => '.' }

  # Platform requirements
  s.platform = :ios, '12.0'
  s.ios.deployment_target = '12.0'

  # Swift version (for any Swift glue code)
  s.swift_version = '5.0'

  # Flutter dependency
  s.dependency 'Flutter'

  # Source files - llamafu wrapper
  s.source_files = 'Classes/**/*.{h,cpp,m,mm}'

  # Public headers
  s.public_header_files = 'Classes/llamafu.h', 'Classes/LlamafuPlugin.h'

  # llama.cpp source files - include all necessary files
  # Note: These paths are relative to the ios/ directory
  llama_cpp_path = '../llama.cpp'

  # Preserve paths for proper include resolution
  s.preserve_paths = [
    "#{llama_cpp_path}/**/*"
  ]

  # Header search paths
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',

    # C++ settings
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'GCC_ENABLE_CPP_EXCEPTIONS' => 'YES',
    'GCC_ENABLE_CPP_RTTI' => 'YES',

    # Header search paths for llama.cpp
    'HEADER_SEARCH_PATHS' => [
      '$(inherited)',
      '"${PODS_ROOT}/../.symlinks/plugins/llamafu/ios/../llama.cpp"',
      '"${PODS_ROOT}/../.symlinks/plugins/llamafu/ios/../llama.cpp/include"',
      '"${PODS_ROOT}/../.symlinks/plugins/llamafu/ios/../llama.cpp/ggml/include"',
      '"${PODS_ROOT}/../.symlinks/plugins/llamafu/ios/../llama.cpp/common"',
      '"${PODS_TARGET_SRCROOT}/../llama.cpp"',
      '"${PODS_TARGET_SRCROOT}/../llama.cpp/include"',
      '"${PODS_TARGET_SRCROOT}/../llama.cpp/ggml/include"',
      '"${PODS_TARGET_SRCROOT}/../llama.cpp/common"',
    ].join(' '),

    # Library search paths
    'LIBRARY_SEARCH_PATHS' => '$(inherited) "${PODS_ROOT}/../.symlinks/plugins/llamafu/ios/Frameworks"',

    # Compiler flags
    'OTHER_CFLAGS' => '-DGGML_USE_ACCELERATE -DGGML_USE_METAL',
    'OTHER_CPLUSPLUSFLAGS' => '-DGGML_USE_ACCELERATE -DGGML_USE_METAL -std=c++17',

    # Exclude simulator architectures without support
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',

    # Enable bitcode (optional, can be disabled)
    'ENABLE_BITCODE' => 'NO',

    # Optimization
    'GCC_OPTIMIZATION_LEVEL' => '3',

    # Suppress warnings from llama.cpp
    'GCC_WARN_INHIBIT_ALL_WARNINGS' => 'NO',
    'CLANG_WARN_DOCUMENTATION_COMMENTS' => 'NO',
  }

  # User target xcconfig
  s.user_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
  }

  # Required frameworks
  s.frameworks = [
    'Foundation',
    'Accelerate',
    'Metal',
    'MetalKit',
    'CoreML',
  ]

  # Weak frameworks (available on newer iOS versions)
  s.weak_frameworks = ['MetalPerformanceShaders']

  # Static library linking
  s.libraries = ['c++']

  # Vendored libraries - if pre-built llama.cpp is available
  # s.vendored_libraries = 'Frameworks/libllama.a', 'Frameworks/libggml.a'

  # Vendored frameworks - alternative approach
  # s.vendored_frameworks = 'Frameworks/llama.xcframework'

  # Resource bundles (for any resources needed)
  # s.resource_bundles = {
  #   'llamafu' => ['Classes/**/*.metal']
  # }

  # Prepare command - build llama.cpp if needed
  s.prepare_command = <<-CMD
    echo "Preparing llamafu iOS build..."

    # Check if llama.cpp submodule is initialized
    if [ ! -f "../llama.cpp/CMakeLists.txt" ]; then
      echo "Initializing llama.cpp submodule..."
      cd .. && git submodule update --init --recursive
    fi

    echo "llama.cpp ready for iOS build"
  CMD

  # Script phase to build llama.cpp (if using script-based build)
  # This runs during pod install
  s.script_phase = {
    :name => 'Build llama.cpp for iOS',
    :script => <<-SCRIPT
      echo "Note: llama.cpp will be built as part of the Xcode project."
      echo "Ensure llama.cpp submodule is initialized with: git submodule update --init --recursive"
    SCRIPT,
    :execution_position => :before_compile,
    :shell_path => '/bin/bash'
  }

  # Module map for proper C++ interop
  s.module_map = 'Classes/module.modulemap'
end
