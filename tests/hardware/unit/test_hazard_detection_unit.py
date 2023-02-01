import cocotb
from cocotb.triggers import Timer
import sys
import os

# Import infrastructure
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
from infrastructure import run_test_simple

@cocotb.test()
async def hazard_detection_unit_test(dut):
    """Test Hazard Detection Unit."""

    # Helper to check output
    async def check(rs1_id, rs2_id, rd_ex, mem_read_ex, expected_stall, name):
        dut.rs1_index_decode.value = rs1_id
        dut.rs2_index_decode.value = rs2_id
        dut.rd_index_execute.value = rd_ex
        dut.memory_read_enable_execute.value = mem_read_ex
        
        await Timer(1, units="ns")
        
        got = int(dut.stall_pipeline.value)
        assert got == expected_stall, f"{name} Failed: Expected={expected_stall}, Got={got}"

    # 1. No Hazard (No Load in EX)
    await check(1, 2, 3, 0, 0, "No Hazard (No Load)")

    # 2. No Hazard (Load in EX, but no dependency)
    await check(1, 2, 3, 1, 0, "No Hazard (Load, No Dep)")

    # 3. Load-Use Hazard on RS1
    # EX is Load to R1. ID uses R1.
    await check(1, 2, 1, 1, 1, "Hazard RS1")

    # 4. Load-Use Hazard on RS2
    # EX is Load to R2. ID uses R2.
    await check(1, 2, 2, 1, 1, "Hazard RS2")

    # 5. x0 Check (Never stall for x0)
    # EX is Load to x0 (unlikely but possible in logic). ID uses x0.
    await check(0, 2, 0, 1, 0, "x0 Hazard Check")

    dut._log.info("Hazard Detection Unit Test Passed!")

def test_hazard_detection_unit():
    run_test_simple(
        module_name="test_hazard_detection_unit",
        toplevel="hazard_detection_unit",
        rtl_files=["core/backend/hazard_detection_unit.v"],
        file_path=__file__
    )
