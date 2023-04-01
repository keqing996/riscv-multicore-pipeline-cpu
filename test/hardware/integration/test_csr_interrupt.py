import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_all_rtl_files

PROGRAM = [
    "04000093", # 0x00: ADDI x1, x0, 0x40
    "30509073", # 0x04: CSRRW x0, mtvec, x1
    "00800093", # 0x08: ADDI x1, x0, 0x8
    "3000a073", # 0x0C: CSRRS x0, mstatus, x1
    "08000093", # 0x10: ADDI x1, x0, 0x80
    "3040a073", # 0x14: CSRRS x0, mie, x1
    "400040b7", # 0x18: LUI x1, 0x40004
    "00808093", # 0x1C: ADDI x1, x1, 8
    "06400113", # 0x20: ADDI x2, x0, 100
    "0020a023", # 0x24: SW x2, 0(x1)
    "0000006f", # 0x28: J 0x28
    "00000013", # 0x2C: NOP
    "00000013", # 0x30: NOP
    "00000013", # 0x34: NOP
    "00000013", # 0x38: NOP
    "00000013", # 0x3C: NOP
    "00100513", # 0x40: ADDI x10, x0, 1
    "00100073", # 0x44: EBREAK
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_csr_interrupt_program(dut):
    create_hex_file("program.hex")
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    # Wait for interrupt (timer counts up to 100)
    # 100 cycles * 10ns = 1000ns.
    # Give it enough time.
    
    for _ in range(500):
        await RisingEdge(dut.clk)
        try:
            pc = dut.u_core.u_backend.id_ex_program_counter.value.integer
            if pc == 0x44: # EBREAK
                break
        except:
            pass

    x10 = dut.u_core.u_backend.u_regfile.registers[10].value.integer
    assert x10 == 1, f"x10 should be 1 (Interrupt Handler Executed), got {x10}"

def test_csr_interrupt():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="chip_top",
        verilog_sources=get_all_rtl_files()
    )
