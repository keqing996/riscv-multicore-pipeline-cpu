import cocotb
from cocotb.triggers import Timer
import random
import os
import sys

# Add tests directory to path to import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from infrastructure import VERILOG_SOURCES, run_test

# ALU Control Codes (Must match RTL)
ALU_ADD  = 0b0000
ALU_SUB  = 0b1000
ALU_SLL  = 0b0001
ALU_SLT  = 0b0010
ALU_SLTU = 0b0011
ALU_XOR  = 0b0100
ALU_SRL  = 0b0101
ALU_SRA  = 0b1101
ALU_OR   = 0b0110
ALU_AND  = 0b0111
ALU_LUI  = 0b1001

def model_alu(a, b, op):
    """Python model of the ALU for verification."""
    mask = 0xFFFFFFFF
    a = a & mask
    b = b & mask
    
    if op == ALU_ADD:
        return (a + b) & mask
    elif op == ALU_SUB:
        return (a - b) & mask
    elif op == ALU_SLL:
        shift = b & 0x1F
        return (a << shift) & mask
    elif op == ALU_SLT:
        # Signed comparison
        a_signed = a if a < 0x80000000 else a - 0x100000000
        b_signed = b if b < 0x80000000 else b - 0x100000000
        return 1 if a_signed < b_signed else 0
    elif op == ALU_SLTU:
        return 1 if a < b else 0
    elif op == ALU_XOR:
        return a ^ b
    elif op == ALU_SRL:
        shift = b & 0x1F
        return (a >> shift) & mask
    elif op == ALU_SRA:
        shift = b & 0x1F
        # Signed shift
        a_signed = a if a < 0x80000000 else a - 0x100000000
        res = a_signed >> shift
        return res & mask
    elif op == ALU_OR:
        return a | b
    elif op == ALU_AND:
        return a & b
    elif op == ALU_LUI:
        return b
    else:
        return 0

@cocotb.test()
async def alu_basic_test(dut):
    """Test basic ALU operations with random values."""
    
    # Operations to test
    ops = [
        (ALU_ADD, "ADD"),
        (ALU_SUB, "SUB"),
        (ALU_SLL, "SLL"),
        (ALU_SLT, "SLT"),
        (ALU_SLTU, "SLTU"),
        (ALU_XOR, "XOR"),
        (ALU_SRL, "SRL"),
        (ALU_SRA, "SRA"),
        (ALU_OR,  "OR"),
        (ALU_AND, "AND"),
        (ALU_LUI, "LUI")
    ]

    for _ in range(100): # Run 100 random vectors per op
        a = random.randint(0, 0xFFFFFFFF)
        b = random.randint(0, 0xFFFFFFFF)
        
        for op_code, op_name in ops:
            # Drive inputs
            dut.a.value = a
            dut.b.value = b
            dut.alu_control_code.value = op_code
            
            # Wait for combinational logic
            await Timer(1, units="ns")
            
            # Check output
            dut_res = int(dut.result.value)
            expected_res = model_alu(a, b, op_code)
            
            assert dut_res == expected_res, \
                f"ALU {op_name} Failed! A={hex(a)}, B={hex(b)}, Expected={hex(expected_res)}, Got={hex(dut_res)}"

    dut._log.info("ALU Basic Test Passed!")

# Pytest Runner
import pytest

def test_alu():
    """Pytest wrapper for ALU test."""
    tests_dir = os.path.dirname(os.path.abspath(__file__))
    
    run_test(
        test_name="test_alu",
        toplevel="alu",
        module_name="test_alu", # This file name
        python_search=[tests_dir],
        # We can override verilog_sources if we only want specific files
        # verilog_sources=[os.path.join(RTL_DIR, "core", "alu.v")] 
    )

