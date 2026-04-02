# GoldenFloat C++ Bindings CMake Configuration

cmake_minimum_required(VERSION 3.15)
project(goldenfloat VERSION 1.0.0 LANGUAGES CXX)

# Option to use nlohmann/json for conformance tests (NOT USED - tests use simple JSON parsing)
# option(USE_NLOHMANN_JSON "Use nlohmann/json for conformance tests" OFF)

# Find GoldenFloat shared library
find_library(GOLDENFLOAT NAMES goldenfloat PATHS
    "${CMAKE_SOURCE_DIR}/../../zig-out/lib"
    "${CMAKE_SOURCE_DIR}/../zig-out/lib"
    "${CMAKE_SOURCE_DIR}/../../zig-out/bin"
    "${CMAKE_SOURCE_DIR}/../../build"
    "${CMAKE_SOURCE_DIR}/../../zig-out/lib"
    NO_DEFAULT_PATH
)

if(NOT GOLDENFLOAT)
    message(FATAL_ERROR "GoldenFloat library not found. Run 'zig build shared' in zig-golden-float root.")
endif()

# Include directory for header-only wrapper
include_directories(
    "${CMAKE_SOURCE_DIR}/../src/c"
    "${CMAKE_SOURCE_DIR}/../../src/c"
)

message(STATUS "Found GoldenFloat: ${GOLDENFLOAT}")

# ============================================================================
# Test Target
# ============================================================================

enable_testing()

# Add test executable
add_executable(test_gf16
    tests/test_gf16.cpp
)

# Link against GoldenFloat
target_link_libraries(test_gf16
    PRIVATE
    ${GOLDENFLOAT}
)

# Enable C++17 standard
target_compile_features(test_gf16
    PRIVATE
    cxx_std_17)

# Add compiler warnings
if(MSVC)
    target_compile_options(test_gf16
        PRIVATE
        /W4)
else()
    target_compile_options(test_gf16
        PRIVATE
        -Wall
        -Wextra
        -pedantic)
endif()

# ============================================================================
# Optional: Install Targets
# ============================================================================

option(GOLDENFLOAT_INSTALL "Install GoldenFloat C++ bindings" ON)

if(GOLDENFLOAT_INSTALL)
    include(GNUInstallDirs)
    install(
        FILES include/goldenfloat/gf16.hpp
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/goldenfloat
    )
    message(STATUS "Installation enabled: headers will be installed to ${CMAKE_INSTALL_INCLUDEDIR}/goldenfloat")
endif()

# ============================================================================
# Configuration Summary
// ============================================================================

message(STATUS "")
message(STATUS "GoldenFloat C++ Bindings Configuration:")
message(STATUS "  GoldenFloat Library: ${GOLDENFLOAT}")
message(STATUS "  Install Headers: ${GOLDENFLOAT_INSTALL}")
message(STATUS "")
