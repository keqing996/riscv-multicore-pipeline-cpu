import cocotb
from cocotb.triggers import Timer
import random
import sys
import os

# Import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from infrastructure import run_test_simple

@cocotb.test()
async def instruction_decoder_test(dut):
    """Test Instruction Decoder."""

    for _ in range(100):
        # Generate random instruction
        inst = random.randint(0, 0xFFFFFFFF)
        
        dut.instruction.value = inst
        await Timer(1, units="ns")
        
        # Extract expected fields
        expected_opcode = inst & 0x7F
        expected_rd = (inst >> 7) & 0x1F
        expected_funct3 = (inst >> 12) & 0x7
        expected_rs1 = (inst >> 15) & 0x1F
        expected_rs2 = (inst >> 20) & 0x1F
        expected_funct7 = (inst >> 25) & 0x7F
        
        # Check outputs
        assert int(dut.opcode.value) == expected_opcode, f"Opcode Mismatch: Inst={hex(inst)}"
        assert int(dut.rd.value) == expected_rd, f"RD Mismatch: Inst={hex(inst)}"
        assert int(dut.function_3.value) == expected_funct3, f"Funct3 Mismatch: Inst={hex(inst)}"
        assert int(dut.rs1.value) == expected_rs1, f"RS1 Mismatch: Inst={hex(inst)}"
        assert int(dut.rs2.value) == expected_rs2, f"RS2 Mismatch: Inst={hex(inst)}"
        assert int(dut.function_7.value) == expected_funct7, f"Funct7 Mismatch: Inst={hex(inst)}"

    dut._log.info("Instruction Decoder Test Passed!")

def test_instruction_decoder():
    run_test_simple(
        module_name="test_instruction_decoder",
        toplevel="instruction_decoder",
        rtl_files=["core/backend/instruction_decoder.v"],
        file_path=__file__
    )
