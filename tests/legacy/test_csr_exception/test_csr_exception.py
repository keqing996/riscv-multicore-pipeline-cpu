import cocotb
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from cocotb_utils import run_test_common
from uart_monitor import UARTMonitor

@cocotb.test()
async def test_csr_exception(dut):
    """Test CSR & Exception Software (C Code)."""
    # Start UART Monitor
    uart = UARTMonitor(dut)
    uart.start()
    
    from cocotb.clock import Clock
    from cocotb.triggers import Timer, RisingEdge
    
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Run loop
    for _ in range(200000): # Max cycles (might need more for timer interrupt)
        await RisingEdge(dut.clk)
        if "[PASS]" in uart.log:
            return # Success
        if "[FAIL]" in uart.log:
            assert False, f"Test Failed with output:\n{uart.log}"
            
    assert False, f"Test Timed Out. UART Output:\n{uart.log}"
