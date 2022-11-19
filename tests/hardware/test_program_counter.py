import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random
import sys
import os

# Import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from infrastructure import run_test_simple

@cocotb.test()
async def program_counter_test(dut):
    """Test Program Counter."""

    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.data_in.value = 0
    await Timer(10, units="ns")
    dut.rst_n.value = 1
    await Timer(10, units="ns")

    # Check Reset
    assert dut.data_out.value == 0, "Reset Failed"

    # Test Random Values
    for _ in range(20):
        val = random.randint(0, 0xFFFFFFFF)
        dut.data_in.value = val
        
        await RisingEdge(dut.clk)
        await Timer(1, units="ns") # Wait for output to settle
        
        assert dut.data_out.value == val, f"PC Update Failed: Expected {hex(val)}, Got {hex(dut.data_out.value)}"

    dut._log.info("Program Counter Test Passed!")

def test_program_counter():
    run_test_simple(
        module_name="test_program_counter",
        toplevel="program_counter",
        rtl_files=["core/program_counter.v"],
        file_path=__file__
    )
