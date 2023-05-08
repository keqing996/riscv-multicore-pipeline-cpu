# Function to create a Verilator-based test
# Usage: add_verilog_test(test_name top_module source1.v source2.v ...)
function(add_verilog_test TEST_NAME TOP_MODULE)
    set(VERILOG_SOURCES ${ARGN})
    
    # Create test executable first
    add_executable(${TEST_NAME}
        ${TEST_NAME}.cpp
    )
    
    # Verilate the RTL directly into the target
    verilate(${TEST_NAME}
        SOURCES ${VERILOG_SOURCES}
        TOP_MODULE ${TOP_MODULE}
        PREFIX V${TOP_MODULE}
        VERILATOR_ARGS
            --trace              # Enable VCD tracing
            --trace-structs      # Trace struct members
            --trace-max-array 1024
            -Wall                # Enable warnings
            -Wno-fatal           # Don't make warnings fatal
            -O3                  # Optimize for speed
            --x-assign fast
            --x-initial fast
            --noassert           # Disable assertions for speed
    )
    
    # Link with common utilities
    target_link_libraries(${TEST_NAME} PRIVATE
        tb_common
    )
    
    # Include directories
    target_include_directories(${TEST_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../common
    )
    
    # Add to CTest
    add_test(NAME ${TEST_NAME} 
             COMMAND ${TEST_NAME}
             WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    
    # Set test properties
    set_tests_properties(${TEST_NAME} PROPERTIES
        TIMEOUT 60
        LABELS "unit"
    )
    
    message(STATUS "Added test: ${TEST_NAME} (top=${TOP_MODULE})")
endfunction()

# ============================================================================
# Phase 2: Backend Unit Tests
# ============================================================================

# Test 2.1: ALU
add_verilog_test(test_alu alu
    ${RTL_DIR}/core/backend/alu.v
)

# Test 2.2: Register File
add_verilog_test(test_regfile regfile
    ${RTL_DIR}/core/backend/regfile.v
)

# More tests will be added progressively below...
