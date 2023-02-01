import cocotb
from cocotb.triggers import Timer
import random
import sys
import os

# Import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from infrastructure import run_test_simple

@cocotb.test()
async def branch_unit_test(dut):
    """Test Branch Unit."""

    # Helper to check output
    async def check(funct3, a, b, expected, name):
        dut.function_3.value = funct3
        dut.operand_a.value = a
        dut.operand_b.value = b
        await Timer(1, units="ns")
        
        got = int(dut.branch_condition_met.value)
        assert got == expected, f"{name} Failed: A={hex(a)}, B={hex(b)}, Expected={expected}, Got={got}"

    # Test Cases
    # BEQ (000)
    await check(0b000, 10, 10, 1, "BEQ Equal")
    await check(0b000, 10, 20, 0, "BEQ Not Equal")

    # BNE (001)
    await check(0b001, 10, 20, 1, "BNE Not Equal")
    await check(0b001, 10, 10, 0, "BNE Equal")

    # BLT (100) - Signed
    await check(0b100, -10 & 0xFFFFFFFF, 10, 1, "BLT Less")
    await check(0b100, 10, -10 & 0xFFFFFFFF, 0, "BLT Greater")
    await check(0b100, 10, 10, 0, "BLT Equal")

    # BGE (101) - Signed
    await check(0b101, 10, -10 & 0xFFFFFFFF, 1, "BGE Greater")
    await check(0b101, 10, 10, 1, "BGE Equal")
    await check(0b101, -10 & 0xFFFFFFFF, 10, 0, "BGE Less")

    # BLTU (110) - Unsigned
    await check(0b110, 10, 20, 1, "BLTU Less")
    await check(0b110, 0xFFFFFFFF, 10, 0, "BLTU Greater (Unsigned)") # -1 is huge in unsigned

    # BGEU (111) - Unsigned
    await check(0b111, 0xFFFFFFFF, 10, 1, "BGEU Greater (Unsigned)")
    await check(0b111, 10, 10, 1, "BGEU Equal")
    await check(0b111, 10, 20, 0, "BGEU Less")

    dut._log.info("Branch Unit Test Passed!")

def test_branch_unit():
    run_test_simple(
        module_name="test_branch_unit",
        toplevel="branch_unit",
        rtl_files=["core/backend/branch_unit.v"],
        file_path=__file__
    )
