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
set(RISCV_LDFLAGS -T ${CMAKE_SOURCE_DIR}/software/link.ld)

# --- Software Build ---
# Input files
set(SW_SRC 
    ${CMAKE_SOURCE_DIR}/software/start.S 
    ${CMAKE_SOURCE_DIR}/software/main.c
)
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/software/link.ld)
set(HEX_GEN_SCRIPT ${CMAKE_SOURCE_DIR}/software/make_hex.py)

# Output files (in build directory)
set(SW_ELF ${CMAKE_BINARY_DIR}/software/program.elf)
set(SW_BIN ${CMAKE_BINARY_DIR}/software/program.bin)
set(SW_HEX ${CMAKE_BINARY_DIR}/software/program.hex)

# Create software output directory
file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/software)

# Step 1: Compile & Link (.c/.S -> .elf)
add_custom_command(
    OUTPUT ${SW_ELF}
    COMMAND ${RISCV_CC} ${RISCV_CFLAGS} ${RISCV_LDFLAGS} ${SW_SRC} -o ${SW_ELF}
    DEPENDS ${SW_SRC} ${LINKER_SCRIPT}
    COMMENT "Compiling RISC-V Software: program.elf"
)

# Step 2: Objcopy (.elf -> .bin)
add_custom_command(
    OUTPUT ${SW_BIN}
    COMMAND ${RISCV_OBJCOPY} -O binary ${SW_ELF} ${SW_BIN}
    DEPENDS ${SW_ELF}
    COMMENT "Extracting binary: program.bin"
)

# Step 3: Hex Gen (.bin -> .hex)
add_custom_command(
    OUTPUT ${SW_HEX}
    COMMAND ${PYTHON_EXE} ${HEX_GEN_SCRIPT} ${SW_BIN} > ${SW_HEX}
    DEPENDS ${SW_BIN} ${HEX_GEN_SCRIPT}
    COMMENT "Generating Hex: program.hex"
)

# Target to trigger software build
add_custom_target(software ALL DEPENDS ${SW_HEX})

# --- Hardware Simulation ---
# Source files
file(GLOB RTL_SRCS "${CMAKE_SOURCE_DIR}/rtl/*.v")
set(TB_SRC "${CMAKE_SOURCE_DIR}/tb/core_tb.v")

# Output files
set(SIM_DIR ${CMAKE_BINARY_DIR}/sim)
set(SIM_VVP ${SIM_DIR}/core_tb.vvp)
set(SIM_HEX ${SIM_DIR}/program.hex) # Copy of hex file for simulation

# Create sim output directory
file(MAKE_DIRECTORY ${SIM_DIR})

# Step 1: Compile Verilog (.v -> .vvp)
add_custom_command(
    OUTPUT ${SIM_VVP}
    COMMAND ${IVERILOG_EXE} -o ${SIM_VVP} -I ${CMAKE_SOURCE_DIR}/rtl ${TB_SRC} ${RTL_SRCS}
    DEPENDS ${RTL_SRCS} ${TB_SRC}
    COMMENT "Compiling Verilog: core_tb.vvp"
)

# Step 2: Prepare Simulation (Copy hex file)
add_custom_command(
    OUTPUT ${SIM_HEX}
    COMMAND ${CMAKE_COMMAND} -E copy ${SW_HEX} ${SIM_HEX}
    DEPENDS ${SW_HEX}
    COMMENT "Copying program.hex to sim directory"
)

# Target for compilation
add_custom_target(core_compile ALL DEPENDS ${SIM_VVP} ${SIM_HEX})

# Step 3: Run Simulation
add_custom_target(core_sim
    COMMAND cd ${SIM_DIR} && ${VVP_EXE} ${SIM_VVP}
    DEPENDS core_compile
    COMMENT "Running Simulation..."
    USES_TERMINAL
)
