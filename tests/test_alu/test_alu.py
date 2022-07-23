import cocotb
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from cocotb_utils import run_test_common
from uart_monitor import UARTMonitor

@cocotb.test()
async def test_alu(dut):
    """Test ALU Software (C Code)."""
    # Start UART Monitor
    uart = UARTMonitor(dut)
    uart.start()
    
    # Run test (Software tests might take longer)
    # We can run for a fixed time or wait for a specific string in UART
    
    # Let's run in chunks and check for PASS/FAIL
    from cocotb.clock import Clock
    from cocotb.triggers import Timer, RisingEdge
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Run loop
    for _ in range(100000): # Max cycles
        await RisingEdge(dut.clk)
        if "[PASS]" in uart.log:
            return # Success
        if "[FAIL]" in uart.log:
            assert False, f"Test Failed with output:\n{uart.log}"
            
    assert False, f"Test Timed Out. UART Output:\n{uart.log}"
