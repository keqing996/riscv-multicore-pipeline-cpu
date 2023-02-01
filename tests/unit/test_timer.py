import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import sys
import os

# Import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from infrastructure import run_test_simple

@cocotb.test()
async def timer_test(dut):
    """Test Timer Peripheral."""

    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.write_enable.value = 0
    dut.address.value = 0
    dut.write_data.value = 0
    
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    await Timer(10, unit="ns")

    # Addresses
    MTIME_L    = 0x40004000
    MTIME_H    = 0x40004004
    MTIMECMP_L = 0x40004008
    MTIMECMP_H = 0x4000400C

    # 1. Check Initial State
    # mtime should be small (reset to 0 and counting)
    dut.address.value = MTIME_L
    await Timer(1, unit="ns")
    mtime_l = int(dut.read_data.value)
    assert mtime_l < 100, "mtime should start near 0"
    
    # mtimecmp should be max
    dut.address.value = MTIMECMP_L
    await Timer(1, unit="ns")
    assert int(dut.read_data.value) == 0xFFFFFFFF, "mtimecmp_l init failed"
    
    dut.address.value = MTIMECMP_H
    await Timer(1, unit="ns")
    assert int(dut.read_data.value) == 0xFFFFFFFF, "mtimecmp_h init failed"
    
    # Interrupt should be 0
    assert dut.interrupt_request.value == 0, "Interrupt should be 0 initially"

    # 2. Set Compare Value
    # Set mtimecmp to current mtime + 20
    # Read current mtime again to be sure
    dut.address.value = MTIME_L
    await Timer(1, unit="ns")
    current_time = int(dut.read_data.value)
    
    target_time = current_time + 40 # Wait 40 cycles
    
    # Write MTIMECMP_L
    dut.address.value = MTIMECMP_L
    dut.write_data.value = target_time
    dut.write_enable.value = 1
    await RisingEdge(dut.clk)
    
    # Write MTIMECMP_H (0)
    dut.address.value = MTIMECMP_H
    dut.write_data.value = 0
    await RisingEdge(dut.clk)
    dut.write_enable.value = 0
    
    # 3. Wait for Interrupt
    # Wait enough cycles (target_time - current_time + margin)
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.interrupt_request.value == 1:
            break
        
    assert dut.interrupt_request.value == 1, f"Interrupt did not fire. Target={target_time}"

    # 4. Clear Interrupt (by increasing mtimecmp)
    dut.address.value = MTIMECMP_L
    dut.write_data.value = 0xFFFFFFFF
    dut.write_enable.value = 1
    await RisingEdge(dut.clk)
    dut.write_enable.value = 0
    await Timer(1, unit="ns")
    
    assert dut.interrupt_request.value == 0, "Interrupt did not clear"

    dut._log.info("Timer Test Passed!")

def test_timer():
    run_test_simple(
        module_name="test_timer",
        toplevel="timer",
        rtl_files=["peripherals/timer.v"],
        file_path=__file__
    )
