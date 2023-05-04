import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_rtl_dir


@cocotb.test()
async def test_memory_subsystem_basic(dut):
    """Test memory subsystem with simple read/write operations."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.icache_mem_req.value = 0
    dut.dcache_mem_req.value = 0
    dut.dcache_mem_we.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Wait for memory initialization to complete
    for _ in range(10):
        await RisingEdge(dut.clk)
    
    # Test 1: I-Cache read
    dut.icache_mem_addr.value = 0x0
    dut.icache_mem_req.value = 1
    
    # Wait for ready signal (simulated latency)
    for i in range(10):
        await RisingEdge(dut.clk)
        if dut.icache_mem_ready.value == 1:
            break
    
    assert dut.icache_mem_ready.value == 1, "I-Cache read should complete"
    try:
        val = int(dut.icache_mem_rdata.value)
        dut._log.info(f"I-Cache read: addr=0x0, data=0x{val:08x}")
    except ValueError:
        dut._log.info(f"I-Cache read: addr=0x0, data={dut.icache_mem_rdata.value}")
    
    dut.icache_mem_req.value = 0
    await RisingEdge(dut.clk)
    
    # Test 2: D-Cache write
    dut.dcache_mem_addr.value = 0x1000
    dut.dcache_mem_wdata.value = 0xDEADBEEF
    dut.dcache_mem_be.value = 0b1111
    dut.dcache_mem_we.value = 1
    dut.dcache_mem_req.value = 1
    
    # Wait for ready
    for i in range(10):
        await RisingEdge(dut.clk)
        if dut.dcache_mem_ready.value == 1:
            break
    
    assert dut.dcache_mem_ready.value == 1, "D-Cache write should complete"
    
    dut.dcache_mem_req.value = 0
    dut.dcache_mem_we.value = 0
    await RisingEdge(dut.clk)
    
    # Test 3: D-Cache read back
    dut.dcache_mem_addr.value = 0x1000
    dut.dcache_mem_req.value = 1
    dut.dcache_mem_we.value = 0
    
    for i in range(10):
        await RisingEdge(dut.clk)
        if dut.dcache_mem_ready.value == 1:
            break
    
    assert dut.dcache_mem_ready.value == 1, "D-Cache read should complete"
    assert dut.dcache_mem_rdata.value == 0xDEADBEEF, f"Read data mismatch: got 0x{dut.dcache_mem_rdata.value:08x}"
    
    dut._log.info("Memory Subsystem test passed")


def test_memory_subsystem():
    rtl_dir = get_rtl_dir()
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="memory_subsystem",
        verilog_sources=[
            rtl_dir / "system" / "memory_subsystem.v",
            rtl_dir / "memory" / "main_memory.v"
        ]
    )
