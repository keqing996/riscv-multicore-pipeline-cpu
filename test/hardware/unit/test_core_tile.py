import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_all_rtl_files


@cocotb.test()
async def test_core_tile_basic(dut):
    """Test core tile basic initialization and bus interface."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
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
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="core_tile",
        verilog_sources=get_all_rtl_files()
    )
