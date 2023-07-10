cmake_minimum_required(VERSION 3.20)

# Find LLVM toolchain (prefer Homebrew version for RISC-V support)
find_program(RISCV_CC 
    NAMES clang
    PATHS /opt/homebrew/opt/llvm/bin
    NO_DEFAULT_PATH
    DOC "LLVM Clang compiler for RISC-V")

if(NOT RISCV_CC)
    find_program(RISCV_CC clang)
endif()

find_program(LLVM_OBJCOPY 
    NAMES llvm-objcopy
    PATHS /opt/homebrew/opt/llvm/bin
    NO_DEFAULT_PATH
    DOC "LLVM objcopy utility")

if(NOT LLVM_OBJCOPY)
    find_program(LLVM_OBJCOPY llvm-objcopy)
endif()

if(NOT RISCV_CC)
    message(FATAL_ERROR "clang not found. Install with: brew install llvm")
endif()

if(NOT LLVM_OBJCOPY)
    message(FATAL_ERROR "llvm-objcopy not found. Install with: brew install llvm")
endif()

message(STATUS "RISC-V Clang: ${RISCV_CC}")
message(STATUS "LLVM objcopy: ${LLVM_OBJCOPY}")

# RISC-V compilation flags
set(RISCV_FLAGS
    --target=riscv32
    -march=rv32i
    -mabi=ilp32
    -ffreestanding
    -nostdlib
    -O2
    -g
    -Wall
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

# Function to compile RISC-V program and create software test
function(add_software_test TEST_NAME)
    cmake_parse_arguments(ARG "" "" "C_SOURCES" ${ARGN})
    
    set(ELF_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.elf)
    set(BIN_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.bin)
    set(DIS_FILE ${CMAKE_CURRENT_BINARY_DIR}/${TEST_NAME}.S)
    
    # Resolve absolute paths for C sources
    set(ABS_C_SOURCES)
    foreach(src ${ARG_C_SOURCES})
        get_filename_component(abs_src ${src} ABSOLUTE BASE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
        list(APPEND ABS_C_SOURCES ${abs_src})
    endforeach()
    
    # Compile C/Assembly to ELF
    add_custom_command(
        OUTPUT ${ELF_FILE}
        COMMAND ${RISCV_CC} ${RISCV_FLAGS}
                -T${CMAKE_CURRENT_SOURCE_DIR}/common/link.ld
                ${ABS_C_SOURCES}
                -o ${ELF_FILE}
        DEPENDS ${ABS_C_SOURCES} ${CMAKE_CURRENT_SOURCE_DIR}/common/link.ld
        COMMENT "Compiling RISC-V program: ${TEST_NAME}"
        VERBATIM
    )
    
    # Extract binary
    add_custom_command(
        OUTPUT ${BIN_FILE}
        COMMAND ${LLVM_OBJCOPY} -O binary ${ELF_FILE} ${BIN_FILE}
        DEPENDS ${ELF_FILE}
        COMMENT "Extracting binary: ${TEST_NAME}.bin"
        VERBATIM
    )
    
    # Generate disassembly (optional, for debugging)
    add_custom_command(
        OUTPUT ${DIS_FILE}
        COMMAND ${LLVM_OBJCOPY} --version > /dev/null 2>&1 || true
        DEPENDS ${ELF_FILE}
        COMMENT "Generating disassembly: ${TEST_NAME}.S"
        VERBATIM
    )
    
    # Create custom target for binary
    add_custom_target(${TEST_NAME}_program
        DEPENDS ${BIN_FILE}
    )
    
    # Create test executable
    add_executable(${TEST_NAME} ${TEST_NAME}.cpp)
    
    # Verilate RTL directly into the test
    verilate(${TEST_NAME}
        SOURCES ${CHIP_TOP_RTL_FILES}
        TOP_MODULE chip_top
        PREFIX Vchip_top
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
    
    # Link with common test utilities
    target_link_libraries(${TEST_NAME} PRIVATE tb_common)
    
    # Include directories
    target_include_directories(${TEST_NAME} PRIVATE 
        ${CMAKE_SOURCE_DIR}/test/hardware/common
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_BINARY_DIR}
    )
    
    # Depend on program binary
    add_dependencies(${TEST_NAME} ${TEST_NAME}_program)
    
    # Define binary path for the test
    target_compile_definitions(${TEST_NAME} PRIVATE
        PROGRAM_BIN_PATH="${BIN_FILE}"
    )
    
    # Add to CTest
    add_test(NAME software/${TEST_NAME} 
             COMMAND ${TEST_NAME}
             WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
    
    set_tests_properties(software/${TEST_NAME} PROPERTIES 
        TIMEOUT 120
        LABELS "software"
    )
    
    message(STATUS "Added software test: ${TEST_NAME}")
endfunction()

# Add software tests
add_software_test(test_fibonacci
    C_SOURCES
        test_fibonacci/main.c
        test_fibonacci/start.S
)

add_software_test(test_csr
    C_SOURCES
        test_csr/main.c
        test_csr/start.S
)
