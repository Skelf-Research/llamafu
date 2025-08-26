cmake_minimum_required(VERSION 3.4.1)

project(llamafu)

# Set the path to the llama.cpp directory
set(LLAMA_CPP_DIR "/home/dipankar/Github/llama.cpp")

# Add the llama.cpp include directories
include_directories(
    ${LLAMA_CPP_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/common
    ${LLAMA_CPP_DIR}/ggml/include
    ${LLAMA_CPP_DIR}/tools/mtmd
)

# Add the pre-built libraries
add_library(libllama SHARED IMPORTED)
set_target_properties(libllama PROPERTIES IMPORTED_LOCATION
    ${LLAMA_CPP_DIR}/build/bin/libllama.so)

add_library(libggml SHARED IMPORTED)
set_target_properties(libggml PROPERTIES IMPORTED_LOCATION
    ${LLAMA_CPP_DIR}/build/bin/libggml.so)

add_library(libggml_cpu SHARED IMPORTED)
set_target_properties(libggml_cpu PROPERTIES IMPORTED_LOCATION
    ${LLAMA_CPP_DIR}/build/bin/libggml-cpu.so)

add_library(libggml_base SHARED IMPORTED)
set_target_properties(libggml_base PROPERTIES IMPORTED_LOCATION
    ${LLAMA_CPP_DIR}/build/bin/libggml-base.so)

add_library(libmtmd SHARED IMPORTED)
set_target_properties(libmtmd PROPERTIES IMPORTED_LOCATION
    ${LLAMA_CPP_DIR}/build/bin/libmtmd.so)

# Create the llamafu library
add_library(
    llamafu
    SHARED
    llamafu.cpp
)

# For iOS, we need to link the libraries
target_link_libraries(
    llamafu
    libllama
    libggml
    libggml_cpu
    libggml_base
    libmtmd
)

# Create a test program
add_executable(
    test_llamafu
    test_llamafu.cpp
)

target_link_libraries(
    test_llamafu
    llamafu
)