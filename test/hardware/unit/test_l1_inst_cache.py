import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_rtl_dir


@cocotb.test()
async def test_l1_inst_cache_basic(dut):
    """Test L1 instruction cache with simple operations."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.instruction_memory_ready.value = 0
    dut.instruction_memory_read_data.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: Initial miss (cache cold)
    dut.program_counter_address.value = 0x1000
    await RisingEdge(dut.clk)
    
    # Cache should miss and request from memory
    assert dut.stall_cpu.value == 1, "Should stall on miss"
    assert dut.instruction_memory_request.value == 1, "Should request memory"
    
    # Simulate memory responses for cache line fill (4 words)
    for i in range(4):
        dut.instruction_memory_read_data.value = 0x00000013 + i  # NOPs
        dut.instruction_memory_ready.value = 1
        await RisingEdge(dut.clk)
        dut.instruction_memory_ready.value = 0
    
    # Wait for cache update
    await RisingEdge(dut.clk)
    
    # Test 2: Hit on same address
    dut.program_counter_address.value = 0x1000
    await RisingEdge(dut.clk)
    
    assert dut.stall_cpu.value == 0, "Should not stall on hit"
    assert dut.instruction.value == 0x00000013, "Should return cached instruction"
    
    dut._log.info("L1 Instruction Cache test passed")


def test_l1_inst_cache():
    rtl_dir = get_rtl_dir()
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="l1_inst_cache",
        verilog_sources=[rtl_dir / "cache" / "l1_inst_cache.v"]
    )
