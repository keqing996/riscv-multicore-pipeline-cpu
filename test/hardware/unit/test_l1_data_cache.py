import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_rtl_dir


@cocotb.test()
async def test_l1_data_cache_basic(dut):
    """Test L1 data cache with read/write operations."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.cpu_read_enable.value = 0
    dut.cpu_write_enable.value = 0
    dut.mem_ready.value = 0
    dut.mem_read_data.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: Read miss
    dut.cpu_address.value = 0x2000
    dut.cpu_read_enable.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info(f"State: {dut.state.value}, Stall: {dut.stall_cpu.value}, MemReq: {dut.mem_request.value}")

    # Should stall and request memory
    assert dut.stall_cpu.value == 1, "Should stall on read miss"
    assert dut.mem_request.value == 1, f"Should request memory, state={dut.state.value}"
    
    # Simulate memory responses for cache line fill (4 words)
    for i in range(4):
        dut.mem_read_data.value = 0xAABBCC00 + i
        dut.mem_ready.value = 1
        await RisingEdge(dut.clk)
        dut.mem_ready.value = 0
    
    # Wait for update and access done
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test 2: Read hit
    dut.cpu_address.value = 0x2000
    dut.cpu_read_enable.value = 1
    await RisingEdge(dut.clk)
    
    assert dut.stall_cpu.value == 0, "Should not stall on hit"
    assert dut.cpu_read_data.value == 0xAABBCC00, "Should return cached data"
    
    dut.cpu_read_enable.value = 0
    await RisingEdge(dut.clk)
    
    # Test 3: Write (write-through)
    dut.cpu_address.value = 0x2004
    dut.cpu_write_data.value = 0x12345678
    dut.cpu_byte_enable.value = 0b1111
    dut.cpu_write_enable.value = 1
    await RisingEdge(dut.clk)
    
    # Should stall and write to memory
    assert dut.stall_cpu.value == 1, "Should stall on write"
    assert dut.mem_request.value == 1, "Should request memory"
    assert dut.mem_write_enable.value == 1, "Should write"
    
    dut.mem_ready.value = 1
    await RisingEdge(dut.clk)
    dut.mem_ready.value = 0
    dut.cpu_write_enable.value = 0
    await RisingEdge(dut.clk)
    
    dut._log.info("L1 Data Cache test passed")


def test_l1_data_cache():
    rtl_dir = get_rtl_dir()
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="l1_data_cache",
        verilog_sources=[rtl_dir / "cache" / "l1_data_cache.v"]
    )
