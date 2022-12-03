import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import os
import sys

# Machine Code for Hazard Tests
# 0: ADDI x1, x0, 10
# 4: ADDI x2, x0, 20
# 8: ADD x3, x1, x2     (x3 = 30)
# C: ADD x4, x3, x1     (x4 = 40) (RAW Hazard on x3)
# 10: ADD x5, x3, x4    (x5 = 70) (RAW Hazard on x3 and x4)
# 14: LUI x6, 1         (x6 = 0x1000)
# 18: SW x5, 0(x6)      (Mem[0x1000] = 70)
# 1C: LW x7, 0(x6)      (x7 = 70)
# 20: ADD x8, x7, x1    (x8 = 80) (Load-Use Hazard on x7)
# 24: EBREAK
PROGRAM = [
    "00a00093", # ADDI x1, x0, 10
    "01400113", # ADDI x2, x0, 20
    "002081b3", # ADD x3, x1, x2
    "00118233", # ADD x4, x3, x1
    "004182b3", # ADD x5, x3, x4
    "00001337", # LUI x6, 1
    "00532023", # SW x5, 0(x6)
    "00032383", # LW x7, 0(x6)
    "00138433", # ADD x8, x7, x1
    "00100073", # EBREAK
    "00000013", # NOP
    "00000013", # NOP
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_hazards_program(dut):
    """
    Run hazard handling test.
    """
    create_hex_file("program.hex")

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    # Wait for execution
    for i in range(1000):
        await RisingEdge(dut.clk)
        try:
            pc_ex = dut.u_core.u_backend.id_ex_program_counter.value.integer
        except:
            pc_ex = 0

        if pc_ex == 36: # EBREAK address (0x24)
            dut._log.info("EBREAK Executed. Stopping.")
            for _ in range(100):
                await RisingEdge(dut.clk)
            break
            
    # Verify State
    try:
        x3 = dut.u_core.u_backend.u_regfile.registers[3].value.integer
        x4 = dut.u_core.u_backend.u_regfile.registers[4].value.integer
        x5 = dut.u_core.u_backend.u_regfile.registers[5].value.integer
        x7 = dut.u_core.u_backend.u_regfile.registers[7].value.integer
        x8 = dut.u_core.u_backend.u_regfile.registers[8].value.integer
        
        assert x3 == 30, f"x3 should be 30, got {x3}"
        assert x4 == 40, f"x4 should be 40, got {x4}"
        assert x5 == 70, f"x5 should be 70, got {x5}"
        assert x7 == 70, f"x7 should be 70, got {x7}"
        assert x8 == 80, f"x8 should be 80, got {x8}"
        
    except Exception as e:
        dut._log.error(f"Failed to inspect registers: {e}")
        raise e

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from infrastructure import run_test_simple

def test_hazards():
    run_test_simple(
        module_name="test_hazards",
        toplevel="chip_top",
        rtl_files=[
            "system/chip_top.v",
            "core/core.v",
            "core/frontend/frontend.v",
            "core/backend.v",
            "core/alu.v",
            "core/alu_control_unit.v",
            "core/branch_predictor.v",
            "core/branch_unit.v",
            "core/control_unit.v",
            "core/control_status_register_file.v",
            "core/instruction_decoder.v",
            "core/forwarding_unit.v",
            "core/hazard_detection_unit.v",
            "core/immediate_generator.v",
            "core/load_store_unit.v",
            "core/frontend/program_counter.v",
            "core/regfile.v",
            "memory/main_memory.v",
            "cache/instruction_cache.v",
            "peripherals/timer.v",
            "peripherals/uart_simulator.v"
        ],
        file_path=__file__
    )
