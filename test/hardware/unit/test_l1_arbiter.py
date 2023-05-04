import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_rtl_dir


@cocotb.test()
async def test_l1_arbiter_basic(dut):
    """Test L1 arbiter with simple read requests."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.icache_req.value = 0
    dut.dcache_req.value = 0
    dut.dcache_we.value = 0
    dut.m_ready.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: I-Cache request
    dut.icache_addr.value = 0x1000
    dut.icache_req.value = 1
    dut.m_rdata.value = 0xDEADBEEF
    await RisingEdge(dut.clk)
    
    # Arbiter should forward request
    assert dut.m_req.value == 1, "m_req should be high"
    assert dut.m_addr.value == 0x1000, "Address should be forwarded"
    
    # Simulate memory ready
    dut.m_ready.value = 1
    await RisingEdge(dut.clk)
    
    # Check response
    assert dut.icache_ready.value == 1, "icache_ready should be high"
    assert dut.icache_rdata.value == 0xDEADBEEF, "Data should be forwarded"
    
    # Release
    dut.icache_req.value = 0
    dut.m_ready.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test 2: D-Cache request (priority)
    dut.dcache_addr.value = 0x2000
    dut.dcache_req.value = 1
    dut.dcache_we.value = 0
    dut.icache_addr.value = 0x3000
    dut.icache_req.value = 1
    await RisingEdge(dut.clk)
    
    # D-Cache should have priority
    assert dut.m_addr.value == 0x2000, "D-Cache should have priority"
    
    dut.m_ready.value = 1
    await RisingEdge(dut.clk)
    
    dut.dcache_req.value = 0
    dut.m_ready.value = 0
    await RisingEdge(dut.clk)
    
    # Now I-Cache should get access
    assert dut.m_addr.value == 0x3000, "I-Cache should get access now"
    
    dut._log.info("L1 Arbiter test passed")


def test_l1_arbiter():
    rtl_dir = get_rtl_dir()
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="l1_arbiter",
        verilog_sources=[rtl_dir / "cache" / "l1_arbiter.v"]
    )
