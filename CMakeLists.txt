# Cross-platform CMake build for Llamafu native module
cmake_minimum_required(VERSION 3.19)

project(llamafu_native VERSION 1.0.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Platform detection
if(ANDROID)
    set(PLATFORM_NAME "android")
    set(ARCH_NAME ${ANDROID_ABI})
elseif(IOS)
    set(PLATFORM_NAME "ios")
    if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
        set(ARCH_NAME "arm64")
    else()
        set(ARCH_NAME "x86_64")
    endif()
elseif(WIN32)
    set(PLATFORM_NAME "windows")
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        set(ARCH_NAME "x64")
    else()
        set(ARCH_NAME "x86")
    endif()
elseif(APPLE)
    set(PLATFORM_NAME "macos")
    if(CMAKE_OSX_ARCHITECTURES MATCHES "arm64")
        set(ARCH_NAME "arm64")
    else()
        set(ARCH_NAME "x86_64")
    endif()
else()
    set(PLATFORM_NAME "linux")
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
        set(ARCH_NAME "arm64")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
        set(ARCH_NAME "x64")
    else()
        set(ARCH_NAME "x86")
    endif()
endif()

message(STATUS "Building for ${PLATFORM_NAME}-${ARCH_NAME}")

# Build configuration
option(BUILD_SHARED_LIBS "Build shared libraries" OFF)
option(LLAMAFU_ENABLE_GPU "Enable GPU support" ON)
option(LLAMAFU_ENABLE_METAL "Enable Metal support (macOS/iOS)" ON)
option(LLAMAFU_ENABLE_CUDA "Enable CUDA support" OFF)
option(LLAMAFU_ENABLE_OPENCL "Enable OpenCL support" OFF)

# Output directories
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib/${PLATFORM_NAME}/${ARCH_NAME})
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib/${PLATFORM_NAME}/${ARCH_NAME})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin/${PLATFORM_NAME}/${ARCH_NAME})

# Initialize llama.cpp submodule if not present
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/CMakeLists.txt")
    find_package(Git REQUIRED)
    message(STATUS "Initializing llama.cpp submodule...")
    execute_process(
        COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        RESULT_VARIABLE git_submodule_result
    )
    if(NOT git_submodule_result EQUAL "0")
        message(FATAL_ERROR "git submodule update --init failed with ${git_submodule_result}")
    endif()
endif()

# Configure llama.cpp build options
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "Build tests" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "Build examples" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "Build server" FORCE)
set(LLAMA_STATIC ON CACHE BOOL "Build static library" FORCE)

# Platform-specific configurations
if(ANDROID)
    set(LLAMA_NATIVE OFF CACHE BOOL "Disable native optimizations for Android" FORCE)
    # Android-specific flags
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
elseif(IOS)
    set(LLAMA_METAL ${LLAMAFU_ENABLE_METAL} CACHE BOOL "Enable Metal for iOS" FORCE)
    set(LLAMA_NATIVE OFF CACHE BOOL "Disable native optimizations for iOS" FORCE)
    # iOS-specific flags
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
elseif(APPLE)
    set(LLAMA_METAL ${LLAMAFU_ENABLE_METAL} CACHE BOOL "Enable Metal for macOS" FORCE)
    # macOS-specific flags
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
elseif(WIN32)
    # Windows-specific configurations
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
else()
    # Linux-specific configurations
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")
endif()

# GPU support configuration
if(LLAMAFU_ENABLE_CUDA AND NOT (ANDROID OR IOS))
    set(LLAMA_CUDA ON CACHE BOOL "Enable CUDA" FORCE)
endif()

if(LLAMAFU_ENABLE_OPENCL AND NOT IOS)
    set(LLAMA_CLBLAST ON CACHE BOOL "Enable OpenCL" FORCE)
endif()

# Add llama.cpp as subdirectory
add_subdirectory(llama.cpp)

# Llamafu native library
set(LLAMAFU_SOURCES
    android/src/main/cpp/llamafu.cpp
    android/src/main/cpp/llamafu.h
)

# Add multimodal support for vision models (LLaVA, nanoLLaVA, etc.)
# Includes CLIP for vision and audio preprocessing for Whisper-style models
set(MTMD_SOURCES
    llama.cpp/tools/mtmd/clip.cpp
    llama.cpp/tools/mtmd/clip.h
    llama.cpp/tools/mtmd/clip-impl.h
    llama.cpp/tools/mtmd/mtmd-audio.cpp
    llama.cpp/tools/mtmd/mtmd-audio.h
    llama.cpp/tools/mtmd/mtmd-helper.cpp
    llama.cpp/tools/mtmd/mtmd-helper.h
    # Model-specific implementations
    llama.cpp/tools/mtmd/models/models.h
    llama.cpp/tools/mtmd/models/cogvlm.cpp
    llama.cpp/tools/mtmd/models/conformer.cpp
    llama.cpp/tools/mtmd/models/glm4v.cpp
    llama.cpp/tools/mtmd/models/internvl.cpp
    llama.cpp/tools/mtmd/models/kimivl.cpp
    llama.cpp/tools/mtmd/models/llama4.cpp
    llama.cpp/tools/mtmd/models/llava.cpp
    llama.cpp/tools/mtmd/models/minicpmv.cpp
    llama.cpp/tools/mtmd/models/pixtral.cpp
    llama.cpp/tools/mtmd/models/qwen2vl.cpp
    llama.cpp/tools/mtmd/models/qwen3vl.cpp
    llama.cpp/tools/mtmd/models/siglip.cpp
    llama.cpp/tools/mtmd/models/whisper-enc.cpp
)

# Create unified native static library
add_library(llamafu_native STATIC ${LLAMAFU_SOURCES} ${MTMD_SOURCES})

# Include directories for static lib
target_include_directories(llamafu_native PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/include
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/ggml/include
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/tools/mtmd
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/vendor
)

# Link with llama.cpp
target_link_libraries(llamafu_native PRIVATE llama ggml)

# Create shared library for FFI (desktop testing and runtime)
add_library(llamafu SHARED ${LLAMAFU_SOURCES} ${MTMD_SOURCES})

target_include_directories(llamafu PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/include
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/ggml/include
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/tools/mtmd
    ${CMAKE_CURRENT_SOURCE_DIR}/llama.cpp/vendor
)

target_link_libraries(llamafu PRIVATE llama ggml)

# Set shared library output to build directory root for easy loading
set_target_properties(llamafu PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}
)

# Platform-specific linking for both static and shared libraries
if(APPLE)
    if(IOS)
        target_link_libraries(llamafu_native PRIVATE
            "-framework Foundation"
            "-framework Accelerate"
        )
        target_link_libraries(llamafu PRIVATE
            "-framework Foundation"
            "-framework Accelerate"
        )
        if(LLAMAFU_ENABLE_METAL)
            target_link_libraries(llamafu_native PRIVATE
                "-framework Metal"
                "-framework MetalKit"
            )
            target_link_libraries(llamafu PRIVATE
                "-framework Metal"
                "-framework MetalKit"
            )
        endif()
    else()
        target_link_libraries(llamafu_native PRIVATE
            "-framework Foundation"
            "-framework Accelerate"
        )
        target_link_libraries(llamafu PRIVATE
            "-framework Foundation"
            "-framework Accelerate"
        )
        if(LLAMAFU_ENABLE_METAL)
            target_link_libraries(llamafu_native PRIVATE
                "-framework Metal"
                "-framework MetalKit"
            )
            target_link_libraries(llamafu PRIVATE
                "-framework Metal"
                "-framework MetalKit"
            )
        endif()
    endif()
elseif(ANDROID)
    target_link_libraries(llamafu_native PRIVATE
        log
        android
    )
    target_link_libraries(llamafu PRIVATE
        log
        android
    )
elseif(WIN32)
    target_link_libraries(llamafu_native PRIVATE
        ws2_32
        winmm
    )
    target_link_libraries(llamafu PRIVATE
        ws2_32
        winmm
    )
else()
    target_link_libraries(llamafu_native PRIVATE
        pthread
        dl
        m
    )
    target_link_libraries(llamafu PRIVATE
        pthread
        dl
        m
    )
endif()

# Compiler-specific flags for both static and shared libraries
set(LLAMAFU_TARGETS llamafu_native llamafu)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    foreach(target ${LLAMAFU_TARGETS})
        target_compile_options(${target} PRIVATE
            -Wall
            -Wextra
            -Wpedantic
            -Wno-unused-parameter
            -Wno-unused-variable
            -Wno-unused-function
        )

        # Release optimizations
        target_compile_options(${target} PRIVATE
            $<$<CONFIG:Release>:-O3>
            $<$<CONFIG:Release>:-DNDEBUG>
            $<$<CONFIG:Release>:-ffast-math>
        )

        # Debug flags
        target_compile_options(${target} PRIVATE
            $<$<CONFIG:Debug>:-g>
            $<$<CONFIG:Debug>:-O0>
        )
    endforeach()
elseif(MSVC)
    foreach(target ${LLAMAFU_TARGETS})
        target_compile_options(${target} PRIVATE
            /W4
            /wd4100  # Unreferenced formal parameter
            /wd4201  # Nameless struct/union
        )

        # Release optimizations
        target_compile_options(${target} PRIVATE
            $<$<CONFIG:Release>:/O2>
            $<$<CONFIG:Release>:/DNDEBUG>
        )
    endforeach()
endif()

# Installation
install(TARGETS llamafu_native
    ARCHIVE DESTINATION lib/${PLATFORM_NAME}/${ARCH_NAME}
    LIBRARY DESTINATION lib/${PLATFORM_NAME}/${ARCH_NAME}
    RUNTIME DESTINATION bin/${PLATFORM_NAME}/${ARCH_NAME}
)

# Install headers
install(FILES android/src/main/cpp/llamafu.h
    DESTINATION include
)

# Package configuration
set(CPACK_PACKAGE_NAME "llamafu-native")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_DESCRIPTION "Llamafu Native Module")
set(CPACK_GENERATOR "TGZ;ZIP")
set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${PROJECT_VERSION}-${PLATFORM_NAME}-${ARCH_NAME}")

include(CPack)

# Print build summary
message(STATUS "=== Llamafu Native Build Configuration ===")
message(STATUS "Platform: ${PLATFORM_NAME}")
message(STATUS "Architecture: ${ARCH_NAME}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "GPU Support: ${LLAMAFU_ENABLE_GPU}")
message(STATUS "Metal Support: ${LLAMAFU_ENABLE_METAL}")
message(STATUS "CUDA Support: ${LLAMAFU_ENABLE_CUDA}")
message(STATUS "OpenCL Support: ${LLAMAFU_ENABLE_OPENCL}")
message(STATUS "Output Directory: ${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
message(STATUS "==========================================")