import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from test.driver import run_hardware_test
from test.env import get_all_rtl_files
from pathlib import Path

@cocotb.test()
async def test_arbiter_basic(dut):
    """
    Test basic arbitration logic.
    """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    dut.m0_enable.value = 0
    dut.m1_enable.value = 0
    dut.bus_ready.value = 0
    
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # 1. M0 Request
    dut.m0_enable.value = 1
    dut.m0_addr.value = 0x1000
    dut.m0_wdata.value = 0xAAAA
    dut.m0_write.value = 1
    
    await Timer(1, units="ns") # Combinational check
    assert dut.bus_enable.value == 1
    assert dut.bus_addr.value == 0x1000
    assert dut.m0_ready.value == 0 # Bus not ready yet
    
    # Bus responds
    dut.bus_ready.value = 1
    await Timer(1, units="ns")
    assert dut.m0_ready.value == 1
    
    await RisingEdge(dut.clk)
    # End of Cycle 1. Transaction Done.
    dut.m0_enable.value = 0
    dut.bus_ready.value = 0
    
    await RisingEdge(dut.clk)
    
    # 2. M1 Request
    dut.m1_enable.value = 1
    dut.m1_addr.value = 0x2000
    dut.m1_write.value = 0
    
    await Timer(1, units="ns")
    assert dut.bus_enable.value == 1
    assert dut.bus_addr.value == 0x2000
    
    dut.bus_ready.value = 1
    dut.bus_rdata.value = 0x5555
    await Timer(1, units="ns")
    assert dut.m1_ready.value == 1
    assert dut.m1_rdata.value == 0x5555
    
    await RisingEdge(dut.clk)
    dut.m1_enable.value = 0
    dut.bus_ready.value = 0
    
    await RisingEdge(dut.clk)
    
    # 3. Concurrent Request (M0 and M1)
    # Priority should be M0 initially (reset state or after M1 access?)
    # Logic: if M1 accessed last, priority -> M0.
    # We just did M1 access. So Priority should be M0.
    
    dut.m0_enable.value = 1
    dut.m0_addr.value = 0x3000
    
    dut.m1_enable.value = 1
    dut.m1_addr.value = 0x4000
    
    await Timer(1, units="ns")
    # Should grant M0
    assert dut.bus_addr.value == 0x3000
    
    # Complete M0
    dut.bus_ready.value = 1
    await RisingEdge(dut.clk)
    
    # Next cycle: Should grant M1 (Round Robin)
    # M0 still asserting enable? Let's say M0 wants another one.
    dut.m0_addr.value = 0x3004
    # M1 still asserting enable.
    
    await Timer(1, units="ns")
    assert dut.bus_addr.value == 0x4000 # M1 granted
    
    # Complete M1
    await RisingEdge(dut.clk)
    
    # Next cycle: Should grant M0 again
    await Timer(1, units="ns")
    assert dut.bus_addr.value == 0x3004
    
    dut._log.info("Arbiter Test Passed")

def test_bus_arbiter():
    run_hardware_test(
        module_name="test_bus_arbiter",
        toplevel="bus_arbiter",
        verilog_sources=[
            Path(get_all_rtl_files()[0].parent.parent / "interconnect/bus_arbiter.v")
        ]
    )
