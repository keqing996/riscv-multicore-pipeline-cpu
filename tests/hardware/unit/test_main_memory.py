import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random
import sys
import os

from tests.infrastructure import run_test_simple

@cocotb.test()
async def main_memory_test(dut):
    """Test Main Memory (Dual Port)."""

    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Initialize
    dut.address_a.value = 0
    dut.address_b.value = 0
    dut.write_data_b.value = 0
    dut.write_enable_b.value = 0
    dut.byte_enable_b.value = 0
    
    await Timer(20, unit="ns")

    # 1. Write Word (Port B)
    addr = 0x100
    data = 0xDEADBEEF
    
    dut.address_b.value = addr
    dut.write_data_b.value = data
    dut.write_enable_b.value = 1
    dut.byte_enable_b.value = 0b1111 # Full word
    
    await RisingEdge(dut.clk)
    dut.write_enable_b.value = 0
    await Timer(1, unit="ns")
    
    # 2. Read Word (Port B)
    dut.address_b.value = addr
    await RisingEdge(dut.clk) # Read is synchronous
    await Timer(1, unit="ns")
    assert dut.read_data_b.value == data, "Port B Read Mismatch"

    # 3. Read Word (Port A)
    dut.address_a.value = addr
    await RisingEdge(dut.clk) # Read is synchronous
    await Timer(1, unit="ns")
    assert dut.read_data_a.value == data, "Port A Read Mismatch"

    # 4. Byte Writes (Port B)
    # Write 0xAA to byte 0
    addr2 = 0x200
    dut.address_b.value = addr2
    dut.write_data_b.value = 0x000000AA
    dut.write_enable_b.value = 1
    dut.byte_enable_b.value = 0b0001
    await RisingEdge(dut.clk)
    
    # Write 0xBB to byte 1
    dut.write_data_b.value = 0x0000BB00
    dut.byte_enable_b.value = 0b0010
    await RisingEdge(dut.clk)
    
    # Write 0xCC to byte 2
    dut.write_data_b.value = 0x00CC0000
    dut.byte_enable_b.value = 0b0100
    await RisingEdge(dut.clk)
    
    # Write 0xDD to byte 3
    dut.write_data_b.value = 0xDD000000
    dut.byte_enable_b.value = 0b1000
    await RisingEdge(dut.clk)
    
    dut.write_enable_b.value = 0
    
    # Read Full Word
    dut.address_b.value = addr2
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.read_data_b.value == 0xDDCCBBAA, "Byte Write Mismatch"

    dut._log.info("Main Memory Test Passed!")

def test_main_memory():
    run_test_simple(
        module_name="test_main_memory",
        toplevel="main_memory",
        rtl_files=["memory/main_memory.v"],
        file_path=__file__
    )
