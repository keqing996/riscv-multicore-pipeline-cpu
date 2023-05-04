import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_rtl_dir


@cocotb.test()
async def test_l2_cache_basic(dut):
    """Test L2 cache with simple read operations."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.s_en.value = 0
    dut.s_we.value = 0
    dut.mem_ready.value = 0
    dut.mem_rdata.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: Read miss
    dut.s_addr.value = 0x1000
    dut.s_we.value = 0
    dut.s_en.value = 1
    dut.s_be.value = 0b1111
    await RisingEdge(dut.clk)
    
    # Should not be ready immediately (miss)
    assert dut.s_ready.value == 0, "Should not be ready on miss"
    assert dut.mem_req.value == 1, "Should request memory"
    
    # Simulate memory responses for cache line fill (4 words)
    for i in range(4):
        dut.mem_rdata.value = 0x10000000 + (i << 8)
        dut.mem_ready.value = 1
        await RisingEdge(dut.clk)
        dut.mem_ready.value = 0
    
    # Wait for update
    await RisingEdge(dut.clk)
    
    # Test 2: Read hit
    dut.s_addr.value = 0x1000
    dut.s_en.value = 1
    dut.s_we.value = 0
    await RisingEdge(dut.clk)
    
    assert dut.s_ready.value == 1, "Should be ready on hit"
    assert dut.s_rdata.value == 0x10000000, "Should return cached data"
    
    dut._log.info("L2 Cache test passed")


def test_l2_cache():
    rtl_dir = get_rtl_dir()
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="l2_cache",
        verilog_sources=[rtl_dir / "cache" / "l2_cache.v"]
    )
