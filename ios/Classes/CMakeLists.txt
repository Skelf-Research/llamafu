cmake_minimum_required(VERSION 3.4.1)

project(llamafu)

# Set the path to the llama.cpp directory
if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        # Use the git submodule by default
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../llama.cpp")
    endif()
endif()

# Verify that llama.cpp directory exists
if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_DIR}. Please run 'git submodule update --init --recursive' to initialize the llama.cpp submodule.")
endif()

# Add the llama.cpp include directories
include_directories(
    ${LLAMA_CPP_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/common
    ${LLAMA_CPP_DIR}/ggml/include
    ${LLAMA_CPP_DIR}/tools/mtmd
)

# Build llama.cpp as part of our build process
set(GGML_STATIC ON)
set(LLAMA_STATIC ON)
set(LLAMA_BUILD_TESTS OFF)
set(LLAMA_BUILD_EXAMPLES OFF)
set(LLAMA_BUILD_SERVER OFF)

# Add llama.cpp subdirectory
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)

# Create the llamafu library
add_library(
    llamafu
    SHARED
    llamafu.cpp
)

# For iOS, we need to link the libraries
target_link_libraries(
    llamafu
    llama
    ggml
)

# Create a test program
add_executable(
    test_llamafu
    test_llamafu.cpp
)

target_link_libraries(
    test_llamafu
    llamafu
    llama
    ggml
)