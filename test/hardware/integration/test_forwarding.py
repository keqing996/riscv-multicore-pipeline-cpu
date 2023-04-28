import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_all_rtl_files

# Program Layout:
# 0x00: ADDI x1, x0, 10      (x1 = 10)
# 0x04: ADD  x2, x1, x1      (x2 = 20) -> Tests GPR Forwarding (EX->EX)
# 0x08: ADDI x3, x0, 0x40    (x3 = 0x40)
# 0x0C: CSRRW x0, mtvec, x3  (mtvec = 0x40)
# 0x10: ECALL                (Trap to 0x40) -> Tests CSR Forwarding (mtvec)
# ...
# 0x40: ADDI x4, x0, 0x80    (x4 = 0x80)
# 0x44: CSRRW x0, mepc, x4   (mepc = 0x80)
# 0x48: MRET                 (Return to 0x80) -> Tests CSR Forwarding (mepc)
# ...
# 0x80: ADDI x10, x0, 1      (Success)
# 0x84: EBREAK

PROGRAM_SIZE = 256
PROGRAM = ["00000013"] * PROGRAM_SIZE # Initialize with NOPs

# Instructions
PROGRAM[0] = "00a00093" # 0x00: ADDI x1, x0, 10
PROGRAM[1] = "00108133" # 0x04: ADD x2, x1, x1
PROGRAM[2] = "04000193" # 0x08: ADDI x3, x0, 0x40
PROGRAM[3] = "30519073" # 0x0C: CSRRW x0, mtvec, x3
PROGRAM[4] = "00000073" # 0x10: ECALL

# Handler at 0x40 (Index 16)
PROGRAM[16] = "08000213" # 0x40: ADDI x4, x0, 0x80
PROGRAM[17] = "34121073" # 0x44: CSRRW x0, mepc, x4
PROGRAM[18] = "30200073" # 0x48: MRET

# Target at 0x80 (Index 32)
PROGRAM[32] = "00100513" # 0x80: ADDI x10, x0, 1
PROGRAM[33] = "00100073" # 0x84: EBREAK

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_forwarding_program(dut):
    create_hex_file("program.hex")
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    # Run simulation
    for i in range(200):
        await RisingEdge(dut.clk)
        try:
            pc = dut.u_tile_0.u_core.u_backend.id_ex_program_counter.value.integer
            x2 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[2].value.integer
            x10 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[10].value.integer
            
            dut._log.info(f"Cycle {i}: PC={hex(pc)}, x2={x2}, x10={x10}")
            
            if pc == 0x84: # EBREAK
                break
        except Exception:
            pass
            
    for _ in range(5):
        await RisingEdge(dut.clk)

    # Check GPR Forwarding Result
    x2 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[2].value.integer
    assert x2 == 20, f"GPR Forwarding Failed: x2 should be 20, got {x2}"
    
    # Check CSR Forwarding Result (Reached end of program)
    x10 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[10].value.integer
    assert x10 == 1, f"CSR Forwarding Failed: x10 should be 1, got {x10}"

def test_forwarding():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="chip_top",
        verilog_sources=get_all_rtl_files()
    )
