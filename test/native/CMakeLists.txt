# CMakeLists.txt for Llamafu Native Tests
cmake_minimum_required(VERSION 3.19)

project(llamafu_native_tests VERSION 1.0.0 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(GTest REQUIRED)
find_package(GMock REQUIRED)

# Include directories
include_directories(
    ${CMAKE_SOURCE_DIR}/android/src/main/cpp
    ${CMAKE_SOURCE_DIR}/llama.cpp/include
    ${CMAKE_SOURCE_DIR}/llama.cpp/ggml/include
    ${CMAKE_SOURCE_DIR}/llama.cpp
    ${GTEST_INCLUDE_DIRS}
    ${GMOCK_INCLUDE_DIRS}
)

# Test source files
set(TEST_SOURCES
    test_llamafu_native.cpp
)

# Main source files to test
set(LLAMAFU_SOURCES
    ${CMAKE_SOURCE_DIR}/android/src/main/cpp/llamafu.cpp
    ${CMAKE_SOURCE_DIR}/android/src/main/cpp/llamafu.h
)

# Create test executable
add_executable(llamafu_native_tests
    ${TEST_SOURCES}
    ${LLAMAFU_SOURCES}
)

# Link libraries
target_link_libraries(llamafu_native_tests
    ${GTEST_LIBRARIES}
    ${GMOCK_LIBRARIES}
    pthread
)

# Add llama.cpp libraries if available
if(TARGET llama)
    target_link_libraries(llamafu_native_tests llama ggml)
endif()

# Platform-specific linking
if(APPLE)
    target_link_libraries(llamafu_native_tests
        "-framework Foundation"
        "-framework Accelerate"
    )
elseif(WIN32)
    target_link_libraries(llamafu_native_tests
        ws2_32
        winmm
    )
else()
    target_link_libraries(llamafu_native_tests
        dl
        m
    )
endif()

# Compiler flags
target_compile_options(llamafu_native_tests PRIVATE
    -Wall
    -Wextra
    -Wpedantic
    -Wno-unused-parameter
    -Wno-unused-variable
)

# Enable testing
enable_testing()

# Add test to CTest
add_test(
    NAME llamafu_native_unit_tests
    COMMAND llamafu_native_tests
)

# Set test properties
set_tests_properties(llamafu_native_unit_tests PROPERTIES
    TIMEOUT 300
    LABELS "unit;native"
)

# Memory test with Valgrind (if available)
find_program(VALGRIND_EXECUTABLE valgrind)
if(VALGRIND_EXECUTABLE)
    add_test(
        NAME llamafu_native_memory_test
        COMMAND ${VALGRIND_EXECUTABLE}
            --tool=memcheck
            --leak-check=full
            --show-leak-kinds=all
            --error-exitcode=1
            $<TARGET_FILE:llamafu_native_tests>
    )
    set_tests_properties(llamafu_native_memory_test PROPERTIES
        TIMEOUT 600
        LABELS "memory;native"
    )
endif()

# Coverage target (if lcov is available)
find_program(LCOV_EXECUTABLE lcov)
if(LCOV_EXECUTABLE)
    target_compile_options(llamafu_native_tests PRIVATE --coverage)
    target_link_libraries(llamafu_native_tests --coverage)

    add_custom_target(coverage
        COMMAND ${LCOV_EXECUTABLE} --directory . --capture --output-file coverage.info
        COMMAND ${LCOV_EXECUTABLE} --remove coverage.info '/usr/*' --output-file coverage.info
        COMMAND ${LCOV_EXECUTABLE} --list coverage.info
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
        COMMENT "Generating coverage report"
    )
endif()

# Custom test targets
add_custom_target(run_native_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --label-regex "unit|native"
    DEPENDS llamafu_native_tests
    COMMENT "Running native unit tests"
)

add_custom_target(run_memory_tests
    COMMAND ${CMAKE_CTEST_COMMAND} --output-on-failure --label-regex "memory"
    DEPENDS llamafu_native_tests
    COMMENT "Running memory tests"
)

# Performance test executable (separate from unit tests)
add_executable(llamafu_performance_native
    test_performance_native.cpp
    ${LLAMAFU_SOURCES}
)

target_link_libraries(llamafu_performance_native
    pthread
)

if(TARGET llama)
    target_link_libraries(llamafu_performance_native llama ggml)
endif()

# Platform-specific linking for performance tests
if(APPLE)
    target_link_libraries(llamafu_performance_native
        "-framework Foundation"
        "-framework Accelerate"
    )
elseif(WIN32)
    target_link_libraries(llamafu_performance_native
        ws2_32
        winmm
    )
else()
    target_link_libraries(llamafu_performance_native
        dl
        m
    )
endif()

# Add performance test
add_test(
    NAME llamafu_native_performance
    COMMAND llamafu_performance_native
)

set_tests_properties(llamafu_native_performance PROPERTIES
    TIMEOUT 1800  # 30 minutes
    LABELS "performance;native"
)

# Installation
install(TARGETS llamafu_native_tests llamafu_performance_native
    RUNTIME DESTINATION bin/test
)

# Print configuration summary
message(STATUS "=== Native Test Configuration ===")
message(STATUS "GTest found: ${GTEST_FOUND}")
message(STATUS "GMock found: ${GMOCK_FOUND}")
message(STATUS "Valgrind: ${VALGRIND_EXECUTABLE}")
message(STATUS "Coverage: ${LCOV_EXECUTABLE}")
message(STATUS "==================================")