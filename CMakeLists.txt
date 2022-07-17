cmake_minimum_required(VERSION 3.10)
project(riscv-cpu NONE) 

# --- Configuration ---
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
enable_testing() # Enable CTest

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
    -I${CMAKE_SOURCE_DIR}/tests/common
)
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/tests/common/link.ld)
set(RISCV_LDFLAGS -T ${LINKER_SCRIPT})
set(HEX_GEN_SCRIPT ${CMAKE_SOURCE_DIR}/tools/make_hex.py)

# --- Hardware Simulation Setup ---
# Source files
file(GLOB RTL_SRCS "${CMAKE_SOURCE_DIR}/rtl/*.v")

# Output files
set(SIM_DIR ${CMAKE_BINARY_DIR}/sim)
file(MAKE_DIRECTORY ${SIM_DIR})

# --- Test Discovery & Configuration ---
file(GLOB CHILDREN RELATIVE ${CMAKE_SOURCE_DIR}/tests ${CMAKE_SOURCE_DIR}/tests/*)

foreach(TEST_NAME ${CHILDREN})
    if(IS_DIRECTORY ${CMAKE_SOURCE_DIR}/tests/${TEST_NAME})
        set(TEST_DIR ${CMAKE_SOURCE_DIR}/tests/${TEST_NAME})
        set(TEST_TB ${TEST_DIR}/test_tb.v)
        set(SIM_VVP ${SIM_DIR}/${TEST_NAME}.vvp)

        # 1. Determine Test Type (Software vs Pure Hex)
        if(EXISTS ${TEST_DIR}/main.c)
            # --- Software Test (Compile C -> Hex) ---
            set(TEST_SRC ${TEST_DIR}/start.S ${TEST_DIR}/main.c ${CMAKE_SOURCE_DIR}/tests/common/common.c)
            set(TEST_ELF ${CMAKE_BINARY_DIR}/tests/${TEST_NAME}.elf)
            set(TEST_BIN ${CMAKE_BINARY_DIR}/tests/${TEST_NAME}.bin)
            set(TEST_HEX ${CMAKE_BINARY_DIR}/tests/${TEST_NAME}.hex)

            file(MAKE_DIRECTORY ${CMAKE_BINARY_DIR}/tests)

            # Compile & Link
            add_custom_command(
                OUTPUT ${TEST_ELF}
                COMMAND ${RISCV_CC} ${RISCV_CFLAGS} ${RISCV_LDFLAGS} ${TEST_SRC} -o ${TEST_ELF}
                DEPENDS ${TEST_SRC} ${LINKER_SCRIPT} ${CMAKE_SOURCE_DIR}/tests/common/common.h
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

            add_custom_target(sw_${TEST_NAME} ALL DEPENDS ${TEST_HEX})
            set(TEST_DEPENDS sw_${TEST_NAME})
            set(HEX_FILE ${TEST_HEX})

        elseif(EXISTS ${TEST_DIR}/program.hex)
            # --- Pure Hex Test (Use existing Hex) ---
            set(HEX_FILE ${TEST_DIR}/program.hex)
            set(TEST_DEPENDS "") # No compilation needed
        else()
            message(STATUS "Skipping ${TEST_NAME}: No main.c or program.hex found.")
            continue()
        endif()

        # 2. Compile Testbench (Specific to this test)
        if(EXISTS ${TEST_TB})
            add_custom_command(
                OUTPUT ${SIM_VVP}
                COMMAND ${IVERILOG_EXE} -g2012 -o ${SIM_VVP} -I ${CMAKE_SOURCE_DIR}/rtl ${TEST_TB} ${RTL_SRCS}
                DEPENDS ${RTL_SRCS} ${TEST_TB}
                COMMENT "Compiling Verilog for ${TEST_NAME}"
            )
            add_custom_target(compile_${TEST_NAME} ALL DEPENDS ${SIM_VVP})
        else()
            message(WARNING "No testbench found for ${TEST_NAME} at ${TEST_TB}")
            continue()
        endif()

        # 3. Add CTest
        add_test(
            NAME ${TEST_NAME}
            COMMAND ${PYTHON_EXE} ${CMAKE_SOURCE_DIR}/tools/run_test.py
                    --vvp ${VVP_EXE}
                    --sim-dir ${SIM_DIR}
                    --sim-file ${TEST_NAME}.vvp
                    --hex ${HEX_FILE}
                    --name ${TEST_NAME}
        )
        # Ensure dependencies are met
        if(TEST_DEPENDS)
            set_tests_properties(${TEST_NAME} PROPERTIES DEPENDS "${TEST_DEPENDS};compile_${TEST_NAME}")
        else()
            set_tests_properties(${TEST_NAME} PROPERTIES DEPENDS "compile_${TEST_NAME}")
        endif()

        # 4. Legacy Make Target (make sim_xxx)
        add_custom_target(sim_${TEST_NAME}
            COMMAND ${PYTHON_EXE} ${CMAKE_SOURCE_DIR}/tools/run_test.py
                    --vvp ${VVP_EXE}
                    --sim-dir ${SIM_DIR}
                    --sim-file ${TEST_NAME}.vvp
                    --hex ${HEX_FILE}
                    --name ${TEST_NAME}
            DEPENDS ${TEST_DEPENDS} compile_${TEST_NAME}
            COMMENT "Running Simulation for ${TEST_NAME}..."
            USES_TERMINAL
        )

    endif()
endforeach()
