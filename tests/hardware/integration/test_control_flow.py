import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import os
import sys

# Machine Code for Control Flow
# 0: ADDI x1, x0, 10  (x1 = 10)
# 4: ADDI x2, x0, 10  (x2 = 10)
# 8: BEQ x1, x2, 8    (Jump to 10)
# C: ADDI x3, x0, 1   (Skipped)
# 10: ADDI x4, x0, 5  (x4 = 5)
# 14: JAL x5, 8       (Jump to 1C, x5 = 18)
# 18: ADDI x6, x0, 1  (Skipped)
# 1C: EBREAK          (Stop)
PROGRAM = [
    "00a00093", # ADDI x1, x0, 10
    "00a00113", # ADDI x2, x0, 10
    "00208463", # BEQ x1, x2, 8
    "00100193", # ADDI x3, x0, 1
    "00500213", # ADDI x4, x0, 5
    "008002ef", # JAL x5, 8
    "00100313", # ADDI x6, x0, 1
    "00100073", # EBREAK
    "00000013", # NOP
    "00000013", # NOP
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_control_flow_program(dut):
    """
    Run control flow test.
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

        if pc_ex == 28: # EBREAK address (0x1C)
            dut._log.info("EBREAK Executed. Stopping.")
            for _ in range(100):
                await RisingEdge(dut.clk)
            break
            
    # Verify State
    try:
        x1 = dut.u_core.u_backend.u_regfile.registers[1].value.integer
        x2 = dut.u_core.u_backend.u_regfile.registers[2].value.integer
        x3 = dut.u_core.u_backend.u_regfile.registers[3].value.integer
        x4 = dut.u_core.u_backend.u_regfile.registers[4].value.integer
        x5 = dut.u_core.u_backend.u_regfile.registers[5].value.integer
        x6 = dut.u_core.u_backend.u_regfile.registers[6].value.integer
        
        assert x1 == 10, f"x1 should be 10, got {x1}"
        assert x2 == 10, f"x2 should be 10, got {x2}"
        assert x3 == 0, f"x3 should be 0, got {x3}"
        assert x4 == 5, f"x4 should be 5, got {x4}"
        assert x5 == 0x18, f"x5 should be 0x18, got {x5}"
        assert x6 == 0, f"x6 should be 0, got {x6}"
        
    except Exception as e:
        dut._log.error(f"Failed to inspect registers: {e}")
        raise e

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
from infrastructure import run_test_simple, CHIP_TOP_RTL_FILES

def test_control_flow():
    run_test_simple(
        module_name="test_control_flow",
        toplevel="chip_top",
        rtl_files=CHIP_TOP_RTL_FILES,
        file_path=__file__
    )
