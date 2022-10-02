import sys
import os

# Prevent __pycache__ generation
sys.dont_write_bytecode = True
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

import glob
import pytest
import shutil
import subprocess
from cocotb_test.simulator import run

# Root directory
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
RTL_DIR = os.path.join(ROOT_DIR, "rtl")
TESTS_DIR = os.path.join(ROOT_DIR, "tests")
TOOLS_DIR = os.path.join(ROOT_DIR, "tools")
BUILD_DIR = os.path.join(ROOT_DIR, "build")

# Common Verilog sources
VERILOG_SOURCES = glob.glob(os.path.join(RTL_DIR, "**", "*.v"), recursive=True)
# Add system_top.v (Now chip_top.v in rtl/system, so it's already included by glob)
# VERILOG_SOURCES.append(os.path.join(TESTS_DIR, "common", "system_top.v"))

# Compilation Settings
RISCV_CC = "/opt/homebrew/opt/llvm/bin/clang"
RISCV_OBJCOPY = "/opt/homebrew/opt/llvm/bin/llvm-objcopy"
RISCV_CFLAGS = [
    "--target=riscv32", "-march=rv32i", "-mabi=ilp32",
    "-ffreestanding", "-nostdlib", "-O2", "-g", "-Wall",
    f"-I{os.path.join(TESTS_DIR, 'common')}"
]
LINKER_SCRIPT = os.path.join(TESTS_DIR, "common", "link.ld")
RISCV_LDFLAGS = ["-T", LINKER_SCRIPT]
HEX_GEN_SCRIPT = os.path.join(TOOLS_DIR, "make_hex.py")

def compile_software_test(test_name, test_dir, output_dir):
    """Compiles C code to Hex."""
    print(f"Compiling {test_name}...")
    
    # Source files
    srcs = [
        os.path.join(test_dir, "start.S"),
        os.path.join(test_dir, "main.c"),
        os.path.join(TESTS_DIR, "common", "common.c")
    ]
    
    elf_file = os.path.join(output_dir, f"{test_name}.elf")
    bin_file = os.path.join(output_dir, f"{test_name}.bin")
    hex_file = os.path.join(output_dir, "program.hex")
    
    # 1. Compile to ELF
    cmd_compile = [RISCV_CC] + RISCV_CFLAGS + RISCV_LDFLAGS + srcs + ["-o", elf_file]
    subprocess.check_call(cmd_compile)
    
    # 2. Objcopy to Binary
    cmd_objcopy = [RISCV_OBJCOPY, "-O", "binary", elf_file, bin_file]
    subprocess.check_call(cmd_objcopy)
    
    # 3. Generate Hex
    with open(hex_file, "w") as f:
        subprocess.check_call(["python3", HEX_GEN_SCRIPT, bin_file], stdout=f)
        
    return hex_file

def run_cocotb_test(test_name, is_software=False):
    """Generic runner for a test."""
    test_dir = os.path.join(TESTS_DIR, test_name)
    
    # Unified build directory for this test
    sim_build = os.path.join(BUILD_DIR, test_name)
    
    # Clean and recreate build dir
    if os.path.exists(sim_build):
        shutil.rmtree(sim_build)
    os.makedirs(sim_build)
    
    # Compile if software test
    if is_software:
        compile_software_test(test_name, test_dir, sim_build)
    else:
        # Hardware test: copy existing program.hex from source to build dir
        shutil.copy(os.path.join(test_dir, "program.hex"), os.path.join(sim_build, "program.hex"))

    run(
        verilog_sources=VERILOG_SOURCES,
        toplevel="chip_top",
        module=test_name, # Name of the python module (test_xxx.py)
        python_search=[test_dir], # Where to find the python module
        sim_build=sim_build,
        timescale="1ns/1ps",
        # sim="verilator", # Uncomment to use verilator
    )

# --- Test Definitions ---

def test_simple_alu():
    run_cocotb_test("test_simple_alu")

def test_simple_branch():
    run_cocotb_test("test_simple_branch")

def test_simple_mem():
    run_cocotb_test("test_simple_mem")

def test_simple_full():
    run_cocotb_test("test_simple_full")

def test_alu():
    run_cocotb_test("test_alu", is_software=True)

def test_csr_exception():
    run_cocotb_test("test_csr_exception", is_software=True)

def test_branch_prediction():
    run_cocotb_test("test_branch_prediction", is_software=True)

def test_hazard():
    run_cocotb_test("test_hazard", is_software=False)

if __name__ == "__main__":
    # If run directly, run all tests using pytest
    pytest.main([__file__])
