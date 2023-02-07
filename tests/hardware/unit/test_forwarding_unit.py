import cocotb
from cocotb.triggers import Timer
import sys
import os

from tests.infrastructure import run_test_simple

@cocotb.test()
async def forwarding_unit_test(dut):
    """Test Forwarding Unit."""

    # Helper to check output
    async def check(rs1_ex, rs2_ex, rd_mem, we_mem, rd_wb, we_wb, exp_a, exp_b, name):
        dut.rs1_index_execute.value = rs1_ex
        dut.rs2_index_execute.value = rs2_ex
        dut.rd_index_memory.value = rd_mem
        dut.register_write_enable_memory.value = we_mem
        dut.rd_index_writeback.value = rd_wb
        dut.register_write_enable_writeback.value = we_wb
        
        await Timer(1, units="ns")
        
        got_a = int(dut.forward_a_select.value)
        got_b = int(dut.forward_b_select.value)
        
        assert got_a == exp_a, f"{name} Failed A: Expected={exp_a}, Got={got_a}"
        assert got_b == exp_b, f"{name} Failed B: Expected={exp_b}, Got={got_b}"

    # 1. No Forwarding
    await check(1, 2, 3, 0, 4, 0, 0b00, 0b00, "No Forwarding")

    # 2. EX Hazard (Forward from MEM)
    # RS1 matches RD_MEM, WE_MEM=1
    await check(1, 2, 1, 1, 4, 0, 0b10, 0b00, "EX Hazard A")
    # RS2 matches RD_MEM, WE_MEM=1
    await check(1, 2, 2, 1, 4, 0, 0b00, 0b10, "EX Hazard B")
    # Both match
    await check(1, 1, 1, 1, 4, 0, 0b10, 0b10, "EX Hazard Both")

    # 3. MEM Hazard (Forward from WB)
    # RS1 matches RD_WB, WE_WB=1
    await check(1, 2, 3, 0, 1, 1, 0b01, 0b00, "MEM Hazard A")
    # RS2 matches RD_WB, WE_WB=1
    await check(1, 2, 3, 0, 2, 1, 0b00, 0b01, "MEM Hazard B")

    # 4. Priority (EX Hazard overrides MEM Hazard)
    # RS1 matches both RD_MEM and RD_WB. Should take MEM (0b10)
    await check(1, 2, 1, 1, 1, 1, 0b10, 0b00, "Priority A")
    
    # 5. x0 Check (Never forward x0)
    # RD_MEM = 0, WE_MEM = 1. RS1 = 0. Should be 00.
    await check(0, 2, 0, 1, 4, 0, 0b00, 0b00, "x0 Forwarding A")

    dut._log.info("Forwarding Unit Test Passed!")

def test_forwarding_unit():
    run_test_simple(
        module_name="test_forwarding_unit",
        toplevel="forwarding_unit",
        rtl_files=["core/backend/forwarding_unit.v"],
        file_path=__file__
    )
