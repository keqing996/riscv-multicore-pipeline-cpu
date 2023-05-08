import cocotb
from cocotb.triggers import RisingEdge, Timer, NextTimeStep, with_timeout
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_rtl_dir
import os
import signal

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_core_tile_basic(dut):
    """Test core tile basic initialization and bus interface."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.hart_id.value = 0
    dut.bus_ready.value = 0
    dut.bus_rdata.value = 0
    dut.timer_irq.value = 0
    await Timer(20, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Let core run for a bit
    for i in range(50):
        await RisingEdge(dut.clk)
        
        # If core makes a bus request, respond immediately
        if dut.bus_req.value == 1:
            dut.bus_rdata.value = 0x00000013  # NOP instruction
            dut.bus_ready.value = 1
            try:
                addr_val = int(dut.bus_addr.value)
                we_val = int(dut.bus_we.value)
                dut._log.info(f"Bus request: addr=0x{addr_val:08x}, we={we_val}")
            except ValueError:
                dut._log.info(f"Bus request: addr={dut.bus_addr.value}, we={dut.bus_we.value}")
        else:
            dut.bus_ready.value = 0
    
    dut._log.info("Core Tile basic test completed (no hang)")


def test_core_tile():
    rtl_dir = get_rtl_dir()
    verilog_sources = list((rtl_dir / "core").rglob("*.v")) + \
                      list((rtl_dir / "cache").rglob("*.v")) + \
                      list((rtl_dir / "interconnect").rglob("*.v"))
    
    try:
        run_hardware_test(
            module_name=Path(__file__).stem,
            toplevel="core_tile",
            verilog_sources=verilog_sources,
            has_reset=False  # Disable reset workaround to avoid early release
        )
    finally:
        # Ensure any stray VVP processes are killed
        os.system("pkill -9 -f 'vvp.*core_tile' 2>/dev/null")
