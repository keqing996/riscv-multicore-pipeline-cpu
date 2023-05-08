cmake_minimum_required(VERSION 3.20)
project(riscv_cpu_tests CXX)

# C++ Standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Export compile commands for IDE
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Find Verilator
find_package(verilator HINTS $ENV{VERILATOR_ROOT} /opt/homebrew)
if (NOT verilator_FOUND)
    message(FATAL_ERROR "Verilator not found. Install with: brew install verilator")
endif()

message(STATUS "Found Verilator: ${verilator_DIR}")

# RTL source directory
set(RTL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/rtl)
message(STATUS "RTL directory: ${RTL_DIR}")

# Enable testing
enable_testing()

# Add test subdirectories
add_subdirectory(test)
