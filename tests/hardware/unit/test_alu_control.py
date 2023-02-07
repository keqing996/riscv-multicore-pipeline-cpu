import cocotb
from cocotb.triggers import Timer
import sys
import os

from tests.infrastructure import run_test_simple

@cocotb.test()
async def test_alu_control_xor(dut):
    # ALU_XOR = 4'b0100
    
    # R-type (010), funct3=100 (XOR), funct7=0000000
    dut.alu_operation_code.value = 0b010
    dut.function_3.value = 0b100
    dut.function_7.value = 0b0000000
    
    await Timer(1, units="ns")
    
    control_code = dut.alu_control_code.value.integer
    assert control_code == 0b0100, f"Expected XOR (4), got {control_code}"

@cocotb.test()
async def test_alu_control_sub(dut):
    # ALU_SUB = 4'b1000
    
    # R-type (010), funct3=000 (ADD/SUB), funct7=0100000 (SUB)
    dut.alu_operation_code.value = 0b010
    dut.function_3.value = 0b000
    dut.function_7.value = 0b0100000 # Bit 5 is 1
    
    await Timer(1, units="ns")
    
    control_code = dut.alu_control_code.value.integer
    assert control_code == 0b1000, f"Expected SUB (8), got {control_code}"

def test_alu_control_runner():
    run_test_simple(
        module_name="test_alu_control",
        toplevel="alu_control_unit",
        rtl_files=["core/backend/alu_control_unit.v"],
        file_path=__file__
    )
