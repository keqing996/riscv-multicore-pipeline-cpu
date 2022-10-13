import cocotb
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from uart_monitor import UARTMonitor

@cocotb.test()
async def test_branch_prediction(dut):
    """Test Branch Prediction Software (C Code)."""
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
    # This might take some cycles due to loops
    for _ in range(200000): # Max cycles
        await RisingEdge(dut.clk)
        if "Branch Prediction Test Done" in uart.log:
            if "[FAIL]" in uart.log:
                 assert False, f"Test Failed with output:\n{uart.log}"
            return # Success
            
    assert False, f"Test Timed Out. UART Output:\n{uart.log}"
