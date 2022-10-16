import cocotb
from cocotb.triggers import Timer
import random
import os
import sys

# Add tests directory to path to import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from infrastructure import VERILOG_SOURCES, run_test

def sign_extend(value, bits):
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)

@cocotb.test()
async def immediate_generator_test(dut):
    """Test Immediate Generator for all instruction types."""

    # Opcodes
    OP_I_ARITH = 0b0010011
    OP_I_LOAD  = 0b0000011
    OP_I_JALR  = 0b1100111
    OP_S_STORE = 0b0100011
    OP_B_BRANCH= 0b1100011
    OP_U_LUI   = 0b0110111
    OP_U_AUIPC = 0b0010111
    OP_J_JAL   = 0b1101111

    # Helper to build instruction
    def build_instr(opcode, rd=0, funct3=0, rs1=0, rs2=0, funct7=0, imm=0):
        # This is a generic builder, but we construct specific fields based on type manually below
        pass

    for _ in range(50):
        # --- I-Type Test ---
        # imm[11:0] -> inst[31:20]
        imm_val = random.randint(-2048, 2047)
        imm_bits = imm_val & 0xFFF
        inst = (imm_bits << 20) | (random.randint(0, 31) << 15) | (0 << 12) | (random.randint(0, 31) << 7) | OP_I_ARITH
        
        dut.instruction.value = inst
        await Timer(1, units="ns")
        
        expected = imm_val
        got = int(dut.immediate.value)
        if got >= 0x80000000: got -= 0x100000000 # Convert to signed
        
        assert got == expected, f"I-Type Failed: Inst={hex(inst)}, Expected={expected}, Got={got}"

        # --- S-Type Test ---
        # imm[11:5] -> inst[31:25], imm[4:0] -> inst[11:7]
        imm_val = random.randint(-2048, 2047)
        imm_bits = imm_val & 0xFFF
        imm_11_5 = (imm_bits >> 5) & 0x7F
        imm_4_0 = imm_bits & 0x1F
        inst = (imm_11_5 << 25) | (random.randint(0, 31) << 20) | (random.randint(0, 31) << 15) | (0 << 12) | (imm_4_0 << 7) | OP_S_STORE
        
        dut.instruction.value = inst
        await Timer(1, units="ns")
        
        expected = imm_val
        got = int(dut.immediate.value)
        if got >= 0x80000000: got -= 0x100000000
        
        assert got == expected, f"S-Type Failed: Inst={hex(inst)}, Expected={expected}, Got={got}"

        # --- B-Type Test ---
        # imm[12|10:5] -> inst[31:25], imm[4:1|11] -> inst[11:7]
        # Re-mapping:
        # inst[31] = imm[12]
        # inst[30:25] = imm[10:5]
        # inst[11:8] = imm[4:1]
        # inst[7] = imm[11]
        imm_val = random.randint(-4096, 4094) & 0xFFFFFFFE # Even number
        imm_bits = imm_val & 0x1FFF
        
        bit_12 = (imm_bits >> 12) & 1
        bit_11 = (imm_bits >> 11) & 1
        bits_10_5 = (imm_bits >> 5) & 0x3F
        bits_4_1 = (imm_bits >> 1) & 0xF
        
        inst = (bit_12 << 31) | (bits_10_5 << 25) | (random.randint(0, 31) << 20) | (random.randint(0, 31) << 15) | (0 << 12) | (bit_11 << 7) | (bits_4_1 << 8) | OP_B_BRANCH
        
        dut.instruction.value = inst
        await Timer(1, units="ns")
        
        expected = imm_val
        got = int(dut.immediate.value)
        if got >= 0x80000000: got -= 0x100000000
        
        assert got == expected, f"B-Type Failed: Inst={hex(inst)}, Expected={expected}, Got={got}"

        # --- U-Type Test ---
        # imm[31:12] -> inst[31:12]
        imm_val = random.randint(0, 0xFFFFF) << 12 # Upper 20 bits
        if imm_val >= 0x80000000: imm_val -= 0x100000000 # Signed representation
        
        imm_bits = (imm_val >> 12) & 0xFFFFF
        inst = (imm_bits << 12) | (random.randint(0, 31) << 7) | OP_U_LUI
        
        dut.instruction.value = inst
        await Timer(1, units="ns")
        
        expected = imm_val
        got = int(dut.immediate.value)
        if got >= 0x80000000: got -= 0x100000000
        
        assert got == expected, f"U-Type Failed: Inst={hex(inst)}, Expected={expected}, Got={got}"

        # --- J-Type Test ---
        # imm[20|10:1|11|19:12]
        # inst[31] = imm[20]
        # inst[30:21] = imm[10:1]
        # inst[20] = imm[11]
        # inst[19:12] = imm[19:12]
        imm_val = random.randint(-1048576, 1048574) & 0xFFFFFFFE
        imm_bits = imm_val & 0x1FFFFF
        
        bit_20 = (imm_bits >> 20) & 1
        bits_19_12 = (imm_bits >> 12) & 0xFF
        bit_11 = (imm_bits >> 11) & 1
        bits_10_1 = (imm_bits >> 1) & 0x3FF
        
        inst = (bit_20 << 31) | (bits_10_1 << 21) | (bit_11 << 20) | (bits_19_12 << 12) | (random.randint(0, 31) << 7) | OP_J_JAL
        
        dut.instruction.value = inst
        await Timer(1, units="ns")
        
        expected = imm_val
        got = int(dut.immediate.value)
        if got >= 0x80000000: got -= 0x100000000
        
        assert got == expected, f"J-Type Failed: Inst={hex(inst)}, Expected={expected}, Got={got}"

    dut._log.info("Immediate Generator Test Passed!")

# Pytest Runner
import pytest

def test_immediate_generator():
    """Pytest wrapper for Immediate Generator test."""
    tests_dir = os.path.dirname(os.path.abspath(__file__))
    # Get RTL directory from infrastructure import or relative path
    rtl_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(tests_dir))), "rtl")
    
    run_test(
        test_name="test_immediate_generator",
        toplevel="immediate_generator",
        module_name="test_immediate_generator",
        python_search=[tests_dir],
        verilog_sources=[os.path.join(rtl_dir, "core", "immediate_generator.v")]
    )
