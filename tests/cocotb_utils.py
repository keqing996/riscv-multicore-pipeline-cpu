import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def run_test_common(dut, cycles=200):
    """Common test setup: Clock, Reset, Run."""
    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset
    await reset_dut(dut)
    
    # Run for specified cycles
    for _ in range(cycles):
        await RisingEdge(dut.clk)
