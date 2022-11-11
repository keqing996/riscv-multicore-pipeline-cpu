import cocotb
from cocotb.triggers import Timer
import random
import sys
import os

# Import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from infrastructure import run_test_simple

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

@cocotb.test()
async def alu_control_unit_test(dut):
    """Test ALU Control Unit."""

    # Helper to check output
    async def check(alu_op, funct3, funct7, expected_ctrl, name):
        dut.alu_operation_code.value = alu_op
        dut.function_3.value = funct3
        dut.function_7.value = funct7
        await Timer(1, units="ns")
        
        got = int(dut.alu_control_code.value)
        assert got == expected_ctrl, f"{name} Failed: Op={bin(alu_op)}, F3={bin(funct3)}, F7={bin(funct7)}, Expected={bin(expected_ctrl)}, Got={bin(got)}"

    # 1. Load/Store/AUIPC (ALU_OP = 000) -> ADD
    await check(0b000, 0, 0, ALU_ADD, "LW/SW/AUIPC")

    # 2. Branch (ALU_OP = 001)
    await check(0b001, 0b000, 0, ALU_SUB, "BEQ")
    await check(0b001, 0b001, 0, ALU_SUB, "BNE")
    await check(0b001, 0b100, 0, ALU_SLT, "BLT")
    await check(0b001, 0b101, 0, ALU_SLT, "BGE")
    await check(0b001, 0b110, 0, ALU_SLTU, "BLTU")
    await check(0b001, 0b111, 0, ALU_SLTU, "BGEU")

    # 3. R-Type (ALU_OP = 010)
    await check(0b010, 0b000, 0b0000000, ALU_ADD, "ADD")
    await check(0b010, 0b000, 0b0100000, ALU_SUB, "SUB")
    await check(0b010, 0b001, 0, ALU_SLL, "SLL")
    await check(0b010, 0b010, 0, ALU_SLT, "SLT")
    await check(0b010, 0b011, 0, ALU_SLTU, "SLTU")
    await check(0b010, 0b100, 0, ALU_XOR, "XOR")
    await check(0b010, 0b101, 0b0000000, ALU_SRL, "SRL")
    await check(0b010, 0b101, 0b0100000, ALU_SRA, "SRA")
    await check(0b010, 0b110, 0, ALU_OR, "OR")
    await check(0b010, 0b111, 0, ALU_AND, "AND")

    # 4. I-Type (ALU_OP = 011)
    await check(0b011, 0b000, 0, ALU_ADD, "ADDI")
    await check(0b011, 0b001, 0, ALU_SLL, "SLLI")
    await check(0b011, 0b010, 0, ALU_SLT, "SLTI")
    await check(0b011, 0b011, 0, ALU_SLTU, "SLTIU")
    await check(0b011, 0b100, 0, ALU_XOR, "XORI")
    await check(0b011, 0b101, 0b0000000, ALU_SRL, "SRLI")
    await check(0b011, 0b101, 0b0100000, ALU_SRA, "SRAI")
    await check(0b011, 0b110, 0, ALU_OR, "ORI")
    await check(0b011, 0b111, 0, ALU_AND, "ANDI")

    # 5. LUI (ALU_OP = 100) -> LUI
    await check(0b100, 0, 0, ALU_LUI, "LUI")

    dut._log.info("ALU Control Unit Test Passed!")

def test_alu_control_unit():
    run_test_simple(
        module_name="test_alu_control_unit",
        toplevel="alu_control_unit",
        rtl_files=["core/alu_control_unit.v"],
        file_path=__file__
    )
