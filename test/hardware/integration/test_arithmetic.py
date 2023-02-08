import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_all_rtl_files


# Machine Code for Arithmetic Operations
# 0: ADDI x1, x0, 10  (x1 = 10)
# 4: ADDI x2, x0, 5   (x2 = 5)
# 8: ADD x3, x1, x2   (x3 = 15)
# C: SUB x4, x1, x2   (x4 = 5)
# 10: AND x5, x1, x2  (x5 = 0)
# 14: OR x6, x1, x2   (x6 = 15)
# 18: XOR x7, x1, x2  (x7 = 15)
# 1C: SLL x8, x1, x2  (x8 = 320)
# 20: SRL x9, x1, x2  (x9 = 0)
# 24: SLT x10, x2, x1 (x10 = 1)
# 28: EBREAK          (Stop)
PROGRAM = [
    "00a00093", # ADDI x1, x0, 10
    "00500113", # ADDI x2, x0, 5
    "002081b3", # ADD x3, x1, x2
    "40208233", # SUB x4, x1, x2
    "0020f2b3", # AND x5, x1, x2
    "0020e333", # OR x6, x1, x2
    "0020c3b3", # XOR x7, x1, x2
    "00209433", # SLL x8, x1, x2
    "002054b3", # SRL x9, x1, x2
    "00112533", # SLT x10, x2, x1
    "00100073", # EBREAK
    "00000013", # NOP
    "00000013", # NOP
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_arithmetic_program(dut):
    """
    Run arithmetic operations test.
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

        if pc_ex == 40: # EBREAK address (0x28)
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
        x7 = dut.u_core.u_backend.u_regfile.registers[7].value.integer
        x8 = dut.u_core.u_backend.u_regfile.registers[8].value.integer
        x9 = dut.u_core.u_backend.u_regfile.registers[9].value.integer
        x10 = dut.u_core.u_backend.u_regfile.registers[10].value.integer
        
        assert x1 == 10, f"x1 should be 10, got {x1}"
        assert x2 == 5, f"x2 should be 5, got {x2}"
        assert x3 == 15, f"x3 should be 15, got {x3}"
        assert x4 == 5, f"x4 should be 5, got {x4}"
        assert x5 == 0, f"x5 should be 0, got {x5}"
        assert x6 == 15, f"x6 should be 15, got {x6}"
        assert x7 == 15, f"x7 should be 15, got {x7}"
        assert x8 == 320, f"x8 should be 320, got {x8}"
        assert x9 == 0, f"x9 should be 0, got {x9}"
        assert x10 == 1, f"x10 should be 1, got {x10}"
        
    except Exception as e:
        dut._log.error(f"Failed to inspect registers: {e}")
        raise e


def test_arithmetic():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="chip_top",
        verilog_sources=get_all_rtl_files()
    )
