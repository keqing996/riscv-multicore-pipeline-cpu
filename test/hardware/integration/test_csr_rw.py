import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_all_rtl_files

PROGRAM = [
    "0aa00093", # ADDI x1, x0, 0xAA
    "30509173", # CSRRW x2, mtvec, x1
    "05500193", # ADDI x3, x0, 0x55
    "3051a273", # CSRRS x4, mtvec, x3
    "3051b2f3", # CSRRC x5, mtvec, x3
    "00000013", # NOP
    "00000013", # NOP
    "00000013", # NOP
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_csr_rw_program(dut):
    create_hex_file("program.hex")
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    for _ in range(50):
        await RisingEdge(dut.clk)

    # Verify
    # x2 should be old mtvec (0)
    # x4 should be 0xAA
    # x5 should be 0xFF
    # Final mtvec should be 0xAA
    
    x2 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[2].value.integer
    x4 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[4].value.integer
    x5 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[5].value.integer
    mtvec = dut.u_tile_0.u_core.u_backend.u_control_status_register_file.mtvec.value.integer
    
    assert x2 == 0, f"x2 should be 0, got {x2}"
    assert x4 == 0xAA, f"x4 should be 0xAA, got {x4}"
    assert x5 == 0xFF, f"x5 should be 0xFF, got {x5}"
    assert mtvec == 0xAA, f"mtvec should be 0xAA, got {mtvec}"

def test_csr_rw():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="chip_top",
        verilog_sources=get_all_rtl_files()
    )
