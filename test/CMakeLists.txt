# Test subdirectory

# Add common test utilities library
add_library(tb_common STATIC
    common/tb_base.cpp
)

target_include_directories(tb_common PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/common
    ${VERILATOR_ROOT}/include
    ${VERILATOR_ROOT}/include/vltstd
)

# Collect all RTL files needed for chip_top
set(CHIP_TOP_RTL_FILES
    # System
    ${CMAKE_SOURCE_DIR}/rtl/system/chip_top.v
    ${CMAKE_SOURCE_DIR}/rtl/system/memory_subsystem.v
    
    # Core
    ${CMAKE_SOURCE_DIR}/rtl/core/core_tile.v
    ${CMAKE_SOURCE_DIR}/rtl/core/core.v
    
    # Backend
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/backend.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/control_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/regfile.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/alu.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/alu_control_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/branch_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/forwarding_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/control_status_register_file.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/hazard_detection_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/immediate_generator.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/instruction_decoder.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/load_store_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/mdu.v
    
    # Frontend
    ${CMAKE_SOURCE_DIR}/rtl/core/frontend/frontend.v
    ${CMAKE_SOURCE_DIR}/rtl/core/frontend/program_counter.v
    ${CMAKE_SOURCE_DIR}/rtl/core/frontend/branch_predictor.v
    
    # Cache
    ${CMAKE_SOURCE_DIR}/rtl/cache/l1_inst_cache.v
    ${CMAKE_SOURCE_DIR}/rtl/cache/l1_data_cache.v
    ${CMAKE_SOURCE_DIR}/rtl/cache/l1_arbiter.v
    ${CMAKE_SOURCE_DIR}/rtl/cache/l2_cache.v
    
    # Interconnect
    ${CMAKE_SOURCE_DIR}/rtl/interconnect/bus_arbiter.v
    ${CMAKE_SOURCE_DIR}/rtl/interconnect/bus_interconnect.v
    
    # Memory
    ${CMAKE_SOURCE_DIR}/rtl/memory/main_memory.v
    
    # Peripherals
    ${CMAKE_SOURCE_DIR}/rtl/peripherals/timer.v
    ${CMAKE_SOURCE_DIR}/rtl/peripherals/uart_simulator.v
)

# Backend-only RTL files (for test_backend)
set(BACKEND_RTL_FILES
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/backend.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/control_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/regfile.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/alu.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/alu_control_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/branch_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/forwarding_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/control_status_register_file.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/hazard_detection_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/immediate_generator.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/instruction_decoder.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/load_store_unit.v
    ${CMAKE_SOURCE_DIR}/rtl/core/backend/mdu.v
    ${CMAKE_SOURCE_DIR}/rtl/peripherals/timer.v
)

# Create a shared verilated RTL library for chip_top (for integration tests)
add_library(verilated_chip_top OBJECT ${CHIP_TOP_RTL_FILES})

verilate(verilated_chip_top
    SOURCES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    PREFIX Vchip_top
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

# Create a shared verilated RTL library for backend (for backend integration test)
add_library(verilated_backend OBJECT ${BACKEND_RTL_FILES})

verilate(verilated_backend
    SOURCES ${BACKEND_RTL_FILES}
    TOP_MODULE backend
    PREFIX Vbackend
    VERILATOR_ARGS
        --trace
        --trace-structs
        --trace-max-array 1024
        --public
        -Wall
        -Wno-fatal
        -O3
        --x-assign fast
        --x-initial fast
        --noassert
)

# Add test subdirectories
add_subdirectory(unit_test)
add_subdirectory(integration_test)
