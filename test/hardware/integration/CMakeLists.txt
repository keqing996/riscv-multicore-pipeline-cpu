# Integration Tests for full chip_top and backend modules

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

# Integration tests using chip_top
add_verilog_test(
    NAME test_basic_ops
    SOURCES test_basic_ops.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration basic
)

add_verilog_test(
    NAME test_arithmetic
    SOURCES test_arithmetic.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration arithmetic
)

add_verilog_test(
    NAME test_memory_ops
    SOURCES test_memory_ops.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration memory
)

add_verilog_test(
    NAME test_control_flow
    SOURCES test_control_flow.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration control_flow
)

add_verilog_test(
    NAME test_forwarding
    SOURCES test_forwarding.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration forwarding
)

add_verilog_test(
    NAME test_hazards
    SOURCES test_hazards.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration hazards
)

add_verilog_test(
    NAME test_mdu
    SOURCES test_mdu.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration mdu
)

add_verilog_test(
    NAME test_csr_rw
    SOURCES test_csr_rw.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration csr
)

add_verilog_test(
    NAME test_csr_exception
    SOURCES test_csr_exception.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration csr exception
)

add_verilog_test(
    NAME test_csr_interrupt
    SOURCES test_csr_interrupt.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration csr interrupt
)

add_verilog_test(
    NAME test_csr_mret
    SOURCES test_csr_mret.cpp
    RTL_FILES ${CHIP_TOP_RTL_FILES}
    TOP_MODULE chip_top
    LABELS integration csr mret
)

# Backend unit test (tests backend module in isolation)
add_verilog_test(
    NAME test_backend
    SOURCES test_backend.cpp
    RTL_FILES ${BACKEND_RTL_FILES}
    TOP_MODULE backend
    LABELS integration backend
)
