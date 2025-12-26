# iOS CMake build for Llamafu native module
cmake_minimum_required(VERSION 3.19)

project(llamafu VERSION 1.0.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Set the path to the llama.cpp directory
if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        # Use the git submodule by default
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../llama.cpp")
    endif()
endif()

# Verify that llama.cpp directory exists
if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_DIR}. Please run 'git submodule update --init --recursive' to initialize the llama.cpp submodule.")
endif()

message(STATUS "Using llama.cpp from: ${LLAMA_CPP_DIR}")

# iOS-specific configurations
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC")

# Build options
option(LLAMAFU_ENABLE_METAL "Enable Metal support for iOS" ON)

# Configure llama.cpp build options
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "Build tests" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "Build examples" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "Build server" FORCE)
set(LLAMA_STATIC ON CACHE BOOL "Build static library" FORCE)
set(GGML_STATIC ON CACHE BOOL "Build GGML static" FORCE)
set(LLAMA_NATIVE OFF CACHE BOOL "Disable native optimizations for iOS" FORCE)
set(LLAMA_METAL ${LLAMAFU_ENABLE_METAL} CACHE BOOL "Enable Metal for iOS" FORCE)

# Add the llama.cpp include directories
include_directories(
    ${LLAMA_CPP_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/common
    ${LLAMA_CPP_DIR}/ggml/include
    ${LLAMA_CPP_DIR}/tools/mtmd
)

# Add llama.cpp subdirectory
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)

# Create the llamafu library (shared for Flutter plugin)
add_library(
    llamafu
    SHARED
    llamafu.cpp
)

# Include directories for llamafu
target_include_directories(llamafu PRIVATE
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
    ${LLAMA_CPP_DIR}
    ${LLAMA_CPP_DIR}/common
    ${LLAMA_CPP_DIR}/tools/mtmd
)

# Link libraries
target_link_libraries(
    llamafu
    llama
    ggml
)

# iOS Framework linking
target_link_libraries(
    llamafu
    "-framework Foundation"
    "-framework Accelerate"
)

if(LLAMAFU_ENABLE_METAL)
    target_link_libraries(
        llamafu
        "-framework Metal"
        "-framework MetalKit"
    )
endif()

# Compiler flags
target_compile_options(llamafu PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-unused-variable
    -Wno-unused-function
)

# Release optimizations
target_compile_options(llamafu PRIVATE
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Release>:-DNDEBUG>
    $<$<CONFIG:Release>:-ffast-math>
)

# Debug flags
target_compile_options(llamafu PRIVATE
    $<$<CONFIG:Debug>:-g>
    $<$<CONFIG:Debug>:-O0>
)

# Set library properties for iOS
set_target_properties(llamafu PROPERTIES
    FRAMEWORK TRUE
    MACOSX_FRAMEWORK_IDENTIFIER com.llamafu.native
    VERSION ${PROJECT_VERSION}
    SOVERSION 1
    PUBLIC_HEADER "llamafu.h"
)

# Static library variant for linking
add_library(llamafu_static STATIC llamafu.cpp)

target_include_directories(llamafu_static PRIVATE
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
    ${LLAMA_CPP_DIR}
    ${LLAMA_CPP_DIR}/common
    ${LLAMA_CPP_DIR}/tools/mtmd
)

target_link_libraries(llamafu_static llama ggml)

target_compile_options(llamafu_static PRIVATE
    -Wall
    -Wextra
    -Wno-unused-parameter
    -Wno-unused-variable
    -Wno-unused-function
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:Release>:-DNDEBUG>
)

# Print build summary
message(STATUS "=== Llamafu iOS Build Configuration ===")
message(STATUS "llama.cpp: ${LLAMA_CPP_DIR}")
message(STATUS "Metal Support: ${LLAMAFU_ENABLE_METAL}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "========================================")
