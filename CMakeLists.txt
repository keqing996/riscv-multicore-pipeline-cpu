cmake_minimum_required(VERSION 3.10)
project(riscv-cpu NONE) 

# --- Configuration ---
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Tools
find_program(IVERILOG_EXE iverilog REQUIRED)
find_program(VVP_EXE vvp REQUIRED)
find_program(PYTHON_EXE python3 REQUIRED)

# RISC-V Toolchain (LLVM/Clang)
set(RISCV_CC "/opt/homebrew/opt/llvm/bin/clang")
set(RISCV_OBJCOPY "/opt/homebrew/opt/llvm/bin/llvm-objcopy")
set(RISCV_OBJDUMP "/opt/homebrew/opt/llvm/bin/llvm-objdump")

# Flags
set(RISCV_CFLAGS 
    --target=riscv32 
    -march=rv32i 
    -mabi=ilp32 
    -ffreestanding 
    -nostdlib 
    -O2 -g -Wall
)
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/software/link.ld)
set(RISCV_LDFLAGS -T ${LINKER_SCRIPT})
set(HEX_GEN_SCRIPT ${CMAKE_SOURCE_DIR}/tools/make_hex.py)

# Create software output directory
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/software)

# --- Macro to add a test case ---
macro(add_riscv_test TEST_NAME)
    set(TEST_DIR ${CMAKE_SOURCE_DIR}/software/${TEST_NAME})
    set(TEST_SRC ${TEST_DIR}/start.S ${TEST_DIR}/main.c)
    
    set(TEST_ELF ${CMAKE_BINARY_DIR}/software/${TEST_NAME}.elf)
    set(TEST_BIN ${CMAKE_BINARY_DIR}/software/${TEST_NAME}.bin)
    set(TEST_HEX ${CMAKE_BINARY_DIR}/software/${TEST_NAME}.hex)

    # Compile & Link
    add_custom_command(
        OUTPUT ${TEST_ELF}
        COMMAND ${RISCV_CC} ${RISCV_CFLAGS} ${RISCV_LDFLAGS} ${TEST_SRC} -o ${TEST_ELF}
        DEPENDS ${TEST_SRC} ${LINKER_SCRIPT}
        COMMENT "Compiling ${TEST_NAME}: ${TEST_NAME}.elf"
    )

    # Objcopy
    add_custom_command(
        OUTPUT ${TEST_BIN}
        COMMAND ${RISCV_OBJCOPY} -O binary ${TEST_ELF} ${TEST_BIN}
        DEPENDS ${TEST_ELF}
        COMMENT "Extracting binary: ${TEST_NAME}.bin"
    )

    # Hex Gen
    add_custom_command(
        OUTPUT ${TEST_HEX}
        COMMAND ${PYTHON_EXE} ${HEX_GEN_SCRIPT} ${TEST_BIN} > ${TEST_HEX}
        DEPENDS ${TEST_BIN} ${HEX_GEN_SCRIPT}
        COMMENT "Generating Hex: ${TEST_NAME}.hex"
    )

    # Target for this test software
    add_custom_target(sw_${TEST_NAME} ALL DEPENDS ${TEST_HEX})

    # Simulation Target
    add_custom_target(sim_${TEST_NAME}
        COMMAND ${CMAKE_COMMAND} -E copy ${TEST_HEX} ${CMAKE_BINARY_DIR}/sim/program.hex
        COMMAND cd ${CMAKE_BINARY_DIR}/sim && ${VVP_EXE} core_tb.vvp
        DEPENDS sw_${TEST_NAME} core_compile_vvp
        COMMENT "Running Simulation for ${TEST_NAME}..."
        USES_TERMINAL
    )
endmacro()

# --- Hardware Simulation Setup ---
# Source files
file(GLOB RTL_SRCS "${CMAKE_SOURCE_DIR}/rtl/*.v")
set(TB_SRC "${CMAKE_SOURCE_DIR}/tb/core_tb.v")

# Output files
set(SIM_DIR ${CMAKE_BINARY_DIR}/sim)
set(SIM_VVP ${SIM_DIR}/core_tb.vvp)

# Create sim output directory
file(MAKE_DIRECTORY ${SIM_DIR})

# Compile Verilog (.v -> .vvp) - Only needs to be done once
add_custom_command(
    OUTPUT ${SIM_VVP}
    COMMAND ${IVERILOG_EXE} -o ${SIM_VVP} -I ${CMAKE_SOURCE_DIR}/rtl ${TB_SRC} ${RTL_SRCS}
    DEPENDS ${RTL_SRCS} ${TB_SRC}
    COMMENT "Compiling Verilog: core_tb.vvp"
)

add_custom_target(core_compile_vvp ALL DEPENDS ${SIM_VVP})

# --- Add Tests ---
add_riscv_test(csr_exception)
add_riscv_test(fibonacci)

# Default sim target (runs csr_exception by default)
add_custom_target(core_sim DEPENDS sim_csr_exception)
