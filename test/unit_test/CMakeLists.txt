# Unit Tests - Each unit test compiles only the RTL it needs

# Function to create a Verilator-based test
# Modern interface: add_verilog_test(NAME <name> SOURCES <cpp> RTL_FILES <v files> TOP_MODULE <top> LABELS <labels>)
function(add_verilog_test)
    cmake_parse_arguments(ARG "" "NAME;TOP_MODULE" "SOURCES;RTL_FILES;LABELS" ${ARGN})
    
    if(NOT ARG_NAME)
        message(FATAL_ERROR "add_verilog_test: NAME is required")
    endif()
    if(NOT ARG_SOURCES)
        message(FATAL_ERROR "add_verilog_test: SOURCES is required")
    endif()
    if(NOT ARG_RTL_FILES)
        message(FATAL_ERROR "add_verilog_test: RTL_FILES is required")
    endif()
    
    # If TOP_MODULE not specified, use NAME without test_ prefix
    if(NOT ARG_TOP_MODULE)
        string(REPLACE "test_" "" ARG_TOP_MODULE "${ARG_NAME}")
    endif()
    
    # Create test executable first
    add_executable(${ARG_NAME} ${ARG_SOURCES})
    
    # Verilate the RTL directly into the target
    verilate(${ARG_NAME}
        SOURCES ${ARG_RTL_FILES}
        TOP_MODULE ${ARG_TOP_MODULE}
        PREFIX V${ARG_TOP_MODULE}
        VERILATOR_ARGS
            --trace              # Enable VCD tracing
            --trace-structs      # Trace struct members
            --trace-max-array 1024
            --public             # Make internal signals accessible
            -Wall                # Enable warnings
            -Wno-fatal           # Don't make warnings fatal
            -O3                  # Optimize for speed
            --x-assign fast
            --x-initial fast
            --noassert           # Disable assertions for speed
    )
    
    # Link with common utilities
    target_link_libraries(${ARG_NAME} PRIVATE tb_common)
    
    # Include directories
    target_include_directories(${ARG_NAME} PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/../common
    )
    
    # Add to CTest with hierarchical naming
    add_test(NAME unit_test/${ARG_NAME} 
             COMMAND ${ARG_NAME}
             WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    
    # Set test properties
    set_tests_properties(unit_test/${ARG_NAME} PROPERTIES TIMEOUT 60)
    
    # Add labels if specified (including hierarchical labels)
    if(ARG_LABELS)
        set_tests_properties(unit_test/${ARG_NAME} PROPERTIES LABELS "unit_test;${ARG_LABELS}")
    else()
        set_tests_properties(unit_test/${ARG_NAME} PROPERTIES LABELS "unit_test")
    endif()
    
    message(STATUS "Added test: ${ARG_NAME} (top=${ARG_TOP_MODULE})")
endfunction()

# ============================================================================
# Phase 2: Backend Unit Tests
# ============================================================================

# Test 2.1: ALU
add_verilog_test(
    NAME test_alu
    SOURCES test_alu.cpp
    RTL_FILES ${RTL_DIR}/core/backend/alu.v
    LABELS "unit;backend"
)

# Test 2.2: Register File
add_verilog_test(
    NAME test_regfile
    SOURCES test_regfile.cpp
    RTL_FILES ${RTL_DIR}/core/backend/regfile.v
    LABELS "unit;backend"
)

# Test 2.3: Branch Unit
add_verilog_test(
    NAME test_branch_unit
    SOURCES test_branch_unit.cpp
    RTL_FILES ${RTL_DIR}/core/backend/branch_unit.v
    LABELS "unit;backend"
)

# Test 2.4: ALU Control Unit
add_verilog_test(
    NAME test_alu_control_unit
    SOURCES test_alu_control_unit.cpp
    RTL_FILES ${RTL_DIR}/core/backend/alu_control_unit.v
    LABELS "unit;backend"
)

# Test 2.5: Immediate Generator
add_verilog_test(
    NAME test_immediate_generator
    SOURCES test_immediate_generator.cpp
    RTL_FILES ${RTL_DIR}/core/backend/immediate_generator.v
    LABELS "unit;backend"
)

# Test 2.6: Instruction Decoder
add_verilog_test(
    NAME test_instruction_decoder
    SOURCES test_instruction_decoder.cpp
    RTL_FILES ${RTL_DIR}/core/backend/instruction_decoder.v
    LABELS "unit;backend"
)

# Test 2.7: Forwarding Unit
add_verilog_test(
    NAME test_forwarding_unit
    SOURCES test_forwarding_unit.cpp
    RTL_FILES ${RTL_DIR}/core/backend/forwarding_unit.v
    LABELS "unit;backend"
)

# Test 2.8: Hazard Detection Unit
add_verilog_test(
    NAME test_hazard_detection_unit
    SOURCES test_hazard_detection_unit.cpp
    RTL_FILES ${RTL_DIR}/core/backend/hazard_detection_unit.v
    LABELS "unit;backend"
)

# Test 2.9: Control Unit
add_verilog_test(
    NAME test_control_unit
    SOURCES test_control_unit.cpp
    RTL_FILES ${RTL_DIR}/core/backend/control_unit.v
    LABELS "unit;backend"
)

# Test 2.10: Load Store Unit
add_verilog_test(
    NAME test_load_store_unit
    SOURCES test_load_store_unit.cpp
    RTL_FILES ${RTL_DIR}/core/backend/load_store_unit.v
    LABELS "unit;backend"
)

# Test 2.11: CSR File
add_verilog_test(
    NAME test_control_status_register_file
    SOURCES test_control_status_register_file.cpp
    RTL_FILES ${RTL_DIR}/core/backend/control_status_register_file.v
    LABELS "unit;backend"
)

# Test 2.12: MDU (Multiply-Divide Unit)
add_verilog_test(
    NAME test_mdu_unit
    SOURCES test_mdu_unit.cpp
    RTL_FILES ${RTL_DIR}/core/backend/mdu.v
    LABELS "unit;backend"
    TOP_MODULE mdu
)

# ============================================================================
# Phase 3: Frontend Unit Tests
# ============================================================================

# Test 3.1: Program Counter
add_verilog_test(
    NAME test_program_counter
    SOURCES test_program_counter.cpp
    RTL_FILES ${RTL_DIR}/core/frontend/program_counter.v
    LABELS "unit;frontend"
)

# Test 3.2: Branch Predictor
add_verilog_test(
    NAME test_branch_predictor
    SOURCES test_branch_predictor.cpp
    RTL_FILES ${RTL_DIR}/core/frontend/branch_predictor.v
    LABELS "unit;frontend"
)

# ============================================================================
# Phase 4: Interconnect Unit Tests
# ============================================================================

# Test 4.1: Bus Arbiter
add_verilog_test(
    NAME test_bus_arbiter
    SOURCES test_bus_arbiter.cpp
    RTL_FILES ${RTL_DIR}/interconnect/bus_arbiter.v
    LABELS "unit;interconnect"
)

# ============================================================================
# Phase 5: Peripheral Unit Tests
# ============================================================================

# Test 5.1: Timer
add_verilog_test(
    NAME test_timer
    SOURCES test_timer.cpp
    RTL_FILES ${RTL_DIR}/peripherals/timer.v
    LABELS "unit;peripheral"
)

# ============================================================================
# Phase 6: Memory Unit Tests
# ============================================================================

# Test 6.1: Main Memory
add_verilog_test(
    NAME test_main_memory
    SOURCES test_main_memory.cpp
    RTL_FILES ${RTL_DIR}/memory/main_memory.v
    LABELS "unit;memory"
)

# ============================================================================
# Phase 7: Cache Unit Tests
# ============================================================================

# Test 7.1: L1 Arbiter
add_verilog_test(
    NAME test_l1_arbiter
    SOURCES test_l1_arbiter.cpp
    RTL_FILES ${RTL_DIR}/cache/l1_arbiter.v
    LABELS "unit;cache"
)

# Test 7.2: L1 Instruction Cache
add_verilog_test(
    NAME test_l1_inst_cache
    SOURCES test_l1_inst_cache.cpp
    RTL_FILES ${RTL_DIR}/cache/l1_inst_cache.v
    LABELS "unit;cache"
)

# Test 7.3: L1 Data Cache
add_verilog_test(
    NAME test_l1_data_cache
    SOURCES test_l1_data_cache.cpp
    RTL_FILES ${RTL_DIR}/cache/l1_data_cache.v
    LABELS "unit;cache"
)

# Test 7.4: L2 Cache
add_verilog_test(
    NAME test_l2_cache
    SOURCES test_l2_cache.cpp
    RTL_FILES ${RTL_DIR}/cache/l2_cache.v
    LABELS "unit;cache"
)

# ============================================================================
# Phase 8: System Integration Tests
# ============================================================================

# Test 8.1: Memory Subsystem
add_verilog_test(
    NAME test_memory_subsystem
    SOURCES test_memory_subsystem.cpp
    RTL_FILES 
        ${RTL_DIR}/system/memory_subsystem.v
        ${RTL_DIR}/memory/main_memory.v
        ${RTL_DIR}/cache/l1_arbiter.v
        ${RTL_DIR}/cache/l1_inst_cache.v
        ${RTL_DIR}/cache/l1_data_cache.v
        ${RTL_DIR}/cache/l2_cache.v
    LABELS "unit;system;integration"
)

# ============================================================================
# Phase 9: Core Tile Integration Test (originally hung with Cocotb!)
# ============================================================================

add_verilog_test(
    NAME test_core_tile
    SOURCES test_core_tile.cpp
    RTL_FILES 
        ${RTL_DIR}/core/core_tile.v
        ${RTL_DIR}/core/core.v
        ${RTL_DIR}/core/frontend/frontend.v
        ${RTL_DIR}/core/frontend/program_counter.v
        ${RTL_DIR}/core/frontend/branch_predictor.v
        ${RTL_DIR}/core/backend/backend.v
        ${RTL_DIR}/core/backend/regfile.v
        ${RTL_DIR}/core/backend/alu.v
        ${RTL_DIR}/core/backend/alu_control_unit.v
        ${RTL_DIR}/core/backend/branch_unit.v
        ${RTL_DIR}/core/backend/control_unit.v
        ${RTL_DIR}/core/backend/instruction_decoder.v
        ${RTL_DIR}/core/backend/immediate_generator.v
        ${RTL_DIR}/core/backend/load_store_unit.v
        ${RTL_DIR}/core/backend/forwarding_unit.v
        ${RTL_DIR}/core/backend/hazard_detection_unit.v
        ${RTL_DIR}/core/backend/control_status_register_file.v
        ${RTL_DIR}/core/backend/mdu.v
        ${RTL_DIR}/cache/l1_inst_cache.v
        ${RTL_DIR}/cache/l1_data_cache.v
        ${RTL_DIR}/cache/l1_arbiter.v
    LABELS "unit;integration;core_tile"
)
