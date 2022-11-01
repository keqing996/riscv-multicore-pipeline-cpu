import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import sys
import os

# Import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from infrastructure import run_test_simple

@cocotb.test()
async def regfile_test(dut):
    """Test Register File."""

    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Initialize inputs
    dut.write_enable.value = 0
    dut.rs1_index.value = 0
    dut.rs2_index.value = 0
    dut.rd_index.value = 0
    dut.write_data.value = 0
    
    await Timer(10, units="ns")

    # Test 1: Read x0 -> Should be 0
    dut.rs1_index.value = 0
    await Timer(1, units="ns")
    assert dut.rs1_read_data.value == 0, "x0 read mismatch"

    # Test 2: Write to x0 -> Should stay 0
    dut.write_enable.value = 1
    dut.rd_index.value = 0
    dut.write_data.value = 0xDEADBEEF
    await RisingEdge(dut.clk)
    dut.write_enable.value = 0
    await Timer(1, units="ns")
    
    dut.rs1_index.value = 0
    await Timer(1, units="ns")
    assert dut.rs1_read_data.value == 0, "x0 was written!"

    # Test 3: Write to R1, Read R1 later
    val = 0xCAFEBABE
    dut.write_enable.value = 1
    dut.rd_index.value = 1
    dut.write_data.value = val
    await RisingEdge(dut.clk)
    dut.write_enable.value = 0
    await Timer(1, units="ns")
    
    dut.rs1_index.value = 1
    await Timer(1, units="ns")
    assert dut.rs1_read_data.value == val, f"R1 read mismatch. Expected {hex(val)}, got {hex(dut.rs1_read_data.value)}"

    # Test 4: Write-Through Forwarding
    # Write to R2, Read R2 in same cycle
    val2 = 0x12345678
    dut.write_enable.value = 1
    dut.rd_index.value = 2
    dut.write_data.value = val2
    dut.rs1_index.value = 2 # Read same register
    
    await Timer(1, units="ns") # Wait for combinational logic
    assert dut.rs1_read_data.value == val2, "Forwarding mismatch"
    
    await RisingEdge(dut.clk) # Latch it
    dut.write_enable.value = 0
    await Timer(1, units="ns")
    assert dut.rs1_read_data.value == val2, "Stored value mismatch"

    # Test 5: Dual Read
    dut.rs1_index.value = 1
    dut.rs2_index.value = 2
    await Timer(1, units="ns")
    assert dut.rs1_read_data.value == val, "Dual Read Port 1 mismatch"
    assert dut.rs2_read_data.value == val2, "Dual Read Port 2 mismatch"

    dut._log.info("Regfile Test Passed!")

def test_regfile():
    run_test_simple(
        module_name="test_regfile",
        toplevel="regfile",
        rtl_files=["core/regfile.v"],
        file_path=__file__
    )
