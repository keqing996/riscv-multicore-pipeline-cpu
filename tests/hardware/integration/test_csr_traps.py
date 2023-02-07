import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import os
import sys

# Machine Code for CSR and Trap Tests
# 0: ADDI x1, x0, 16    (x1 = 16)
# 4: CSRRW x2, mtvec, x1 (mtvec = 16)
# 8: CSRRS x3, mtvec, x0 (x3 = 16)
# C: ECALL              (Trap to 16)
# 10: ADDI x4, x0, 1    (x4 = 1) (Handler)
# 14: EBREAK            (Stop)
PROGRAM = [
    "01000093", # ADDI x1, x0, 16
    "30509173", # CSRRW x2, mtvec, x1
    "305021f3", # CSRRS x3, mtvec, x0
    "00000073", # ECALL
    "00100213", # ADDI x4, x0, 1
    "00100073", # EBREAK
    "00000013", # NOP
    "00000013", # NOP
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_csr_traps_program(dut):
    """
    Run CSR and Trap test.
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

        if pc_ex == 20: # EBREAK address (0x14)
            dut._log.info("EBREAK Executed. Stopping.")
            for _ in range(100):
                await RisingEdge(dut.clk)
            break
            
    # Verify State
    try:
        x3 = dut.u_core.u_backend.u_regfile.registers[3].value.integer
        x4 = dut.u_core.u_backend.u_regfile.registers[4].value.integer
        
        # Check CSRs (Need to access internal signals or via CSR instructions)
        # We can check x3 which read mtvec
        assert x3 == 16, f"x3 (mtvec) should be 16, got {x3}"
        
        # Check if handler executed
        assert x4 == 1, f"x4 should be 1 (Handler executed), got {x4}"
        
        # Check mcause and mepc in CSR file
        # Note: Accessing internal signals might be tricky depending on hierarchy
        # dut.u_core.u_control_status_register_file.mcause
        # dut.u_core.u_control_status_register_file.mepc
        
        # mcause for ECALL is 11
        # mepc should be 0xC (Address of ECALL)
        
        # We can try to read them if they are exposed or just rely on the fact that we jumped correctly
        
    except Exception as e:
        dut._log.error(f"Failed to inspect registers: {e}")
        raise e

from tests.infrastructure import run_test_simple
from tests.hardware.integration.common import get_rtl_files

def test_csr_traps():
    run_test_simple(
        module_name="test_csr_traps",
        toplevel="chip_top",
        rtl_files=get_rtl_files("core"),
        file_path=__file__
    )
