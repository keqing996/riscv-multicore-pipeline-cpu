import sys
import os
import glob
import subprocess
import shutil
from cocotb_test.simulator import run as cocotb_run

# Root directory
ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RTL_DIR = os.path.join(ROOT_DIR, "rtl")
TESTS_DIR = os.path.join(ROOT_DIR, "tests")
TOOLS_DIR = os.path.join(ROOT_DIR, "tools")
BUILD_DIR = os.path.join(ROOT_DIR, "build")

# Common Verilog sources
VERILOG_SOURCES = glob.glob(os.path.join(RTL_DIR, "**", "*.v"), recursive=True)

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

def run_test(test_name, toplevel, module_name, verilog_sources=None, python_search=None, **kwargs):
    """
    Wrapper around cocotb_test.simulator.run to enforce consistent build directories.
    """
    if verilog_sources is None:
        verilog_sources = list(VERILOG_SOURCES)
    else:
        verilog_sources = list(verilog_sources)
        
    if python_search is None:
        python_search = []
        
    # Centralized build directory: build/<test_name>
    sim_build = os.path.join(BUILD_DIR, test_name)

    # Clean up sim_build directory if it exists
    if os.path.exists(sim_build):
        shutil.rmtree(sim_build)
    
    # Ensure PYTHONDONTWRITEBYTECODE is passed to the simulator process
    extra_env = kwargs.get("extra_env", {})
    extra_env["PYTHONDONTWRITEBYTECODE"] = "1"
    kwargs["extra_env"] = extra_env

    # Manually generate wave dump module to ensure VCD generation
    os.makedirs(sim_build, exist_ok=True)
    dump_file = os.path.join(sim_build, f"dump_{test_name}.v")
    
    dump_vars_content = f"        $dumpvars(0, {toplevel});"

    with open(dump_file, "w") as f:
        f.write(f"""
module dump_waves;
    initial begin
        $dumpfile("dump.vcd");
{dump_vars_content}
    end
endmodule
""")
    
    verilog_sources.append(dump_file)

    # Remove waves from kwargs if present to avoid conflict
    kwargs.pop("waves", None)

    # Add dump_waves to toplevel to ensure it is simulated
    sim_toplevel = [toplevel, "dump_waves"]

    cocotb_run(
        verilog_sources=verilog_sources,
        toplevel=sim_toplevel,
        module=module_name,
        python_search=python_search,
        sim_build=sim_build,
        waves=False,
        timescale="1ns/1ps",
        **kwargs
    )

def run_test_simple(module_name, toplevel, rtl_files, file_path):
    """
    Simplified wrapper for running hardware tests.
    Resolves RTL paths relative to RTL_DIR.
    """
    tests_dir = os.path.dirname(os.path.abspath(file_path))
    
    # Resolve RTL files
    abs_rtl_files = [os.path.join(RTL_DIR, f) for f in rtl_files]
    
    run_test(
        test_name=module_name,
        toplevel=toplevel,
        module_name=module_name,
        python_search=[tests_dir],
        verilog_sources=abs_rtl_files
    )

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
