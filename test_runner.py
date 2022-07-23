import os
import glob
import pytest
from cocotb_test.simulator import run

# Root directory
ROOT_DIR = os.path.dirname(os.path.abspath(__file__))
RTL_DIR = os.path.join(ROOT_DIR, "rtl")
TESTS_DIR = os.path.join(ROOT_DIR, "tests")

# Common Verilog sources
VERILOG_SOURCES = glob.glob(os.path.join(RTL_DIR, "*.v"))
# Add system_top.v
VERILOG_SOURCES.append(os.path.join(TESTS_DIR, "common", "system_top.v"))

def test_simple_alu():
    test_dir = os.path.join(TESTS_DIR, "test_simple_alu")
    
    # Copy program.hex to build dir is handled by cocotb-test if we pass it?
    # No, cocotb-test runs in a temp dir. We need to ensure program.hex is there.
    # We can use the 'extra_args' or just copy it manually?
    # cocotb-test doesn't easily copy files. 
    # But we can tell it to run in a specific directory or use a setup hook.
    # Actually, simpler: we can pass the hex file path as a parameter to Verilog?
    # But $readmemh usually takes a local path.
    # Let's try to run in the test directory itself? No, that pollutes source.
    
    # Strategy: Use a build_dir inside the test folder or a global build folder.
    # And copy the hex file there.
    
    sim_build = os.path.join(TESTS_DIR, "test_simple_alu", "sim_build")
    if not os.path.exists(sim_build):
        os.makedirs(sim_build)
        
    # Copy hex file
    import shutil
    shutil.copy(os.path.join(test_dir, "program.hex"), os.path.join(sim_build, "program.hex"))

    run(
        verilog_sources=VERILOG_SOURCES,
        toplevel="system_top",
        module="test_simple_alu", # Name of the python module (test_simple_alu.py)
        python_search=[test_dir], # Where to find the python module
        sim_build=sim_build,
        timescale="1ns/1ps",
        # sim="verilator", # Uncomment to use verilator
    )

if __name__ == "__main__":
    test_simple_alu()
