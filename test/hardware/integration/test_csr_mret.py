import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_all_rtl_files

PROGRAM = [
    "02000093", # 0x00: ADDI x1, x0, 0x20
    "30509073", # 0x04: CSRRW x0, mtvec, x1
    "00000073", # 0x08: ECALL
    "0aa00513", # 0x0C: ADDI x10, x0, 0xAA
    "00100073", # 0x10: EBREAK
    "00000013", # 0x14: NOP
    "00000013", # 0x18: NOP
    "00000013", # 0x1C: NOP
    "341022f3", # 0x20: CSRRS x5, mepc, x0
    "00428293", # 0x24: ADDI x5, x5, 4
    "34129073", # 0x28: CSRRW x0, mepc, x5
    "30200073", # 0x2C: MRET
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_csr_mret_program(dut):
    create_hex_file("program.hex")
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        try:
            pc = dut.u_core.u_backend.id_ex_program_counter.value.integer
            if pc == 0x10: # EBREAK
                break
        except:
            pass

    x10 = dut.u_core.u_backend.u_regfile.registers[10].value.integer
    assert x10 == 0xAA, f"x10 should be 0xAA, got {x10}"

def test_csr_mret():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="chip_top",
        verilog_sources=get_all_rtl_files()
    )
