import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import os
import sys

# Machine Code for Memory Operations
# 0: LUI x1, 1          (x1 = 0x1000)
# 4: ADDI x2, x0, 0xAB  (x2 = 0xAB)
# 8: SB x2, 0(x1)       (Mem[0x1000] = 0xAB)
# C: ADDI x3, x0, 0xCD
# 10: SB x3, 1(x1)      (Mem[0x1001] = 0xCD)
# 14: ADDI x4, x0, 0xEF
# 18: SB x4, 2(x1)      (Mem[0x1002] = 0xEF)
# 1C: ADDI x5, x0, 0x12
# 20: SB x5, 3(x1)      (Mem[0x1003] = 0x12)
# 24: LW x6, 0(x1)      (x6 = 0x12EFCDAB)
# 28: LB x7, 0(x1)      (x7 = 0xFFFFFFAB)
# 2C: LBU x8, 0(x1)     (x8 = 0x000000AB)
# 30: EBREAK
PROGRAM = [
    "000010b7", # LUI x1, 1
    "0ab00113", # ADDI x2, x0, 0xAB
    "00208023", # SB x2, 0(x1)
    "0cd00193", # ADDI x3, x0, 0xCD
    "003080a3", # SB x3, 1(x1)
    "0ef00213", # ADDI x4, x0, 0xEF
    "00408123", # SB x4, 2(x1)
    "01200293", # ADDI x5, x0, 0x12
    "005081a3", # SB x5, 3(x1)
    "0000a303", # LW x6, 0(x1)
    "00008383", # LB x7, 0(x1)
    "0000c403", # LBU x8, 0(x1)
    "00100073", # EBREAK
    "00000013", # NOP
    "00000013", # NOP
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_memory_ops_program(dut):
    """
    Run memory operations test.
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

        if pc_ex == 48: # EBREAK address (0x30)
            dut._log.info("EBREAK Executed. Stopping.")
            for _ in range(100):
                await RisingEdge(dut.clk)
            break
            
    # Verify State
    try:
        x6 = dut.u_core.u_backend.u_regfile.registers[6].value.integer
        x7 = dut.u_core.u_backend.u_regfile.registers[7].value.integer
        x8 = dut.u_core.u_backend.u_regfile.registers[8].value.integer
        
        # Handle signed values for x6 and x7
        if x6 >= 0x80000000: x6 -= 0x100000000
        if x7 >= 0x80000000: x7 -= 0x100000000
        
        assert x6 == 0x12EFCDAB, f"x6 should be 0x12EFCDAB, got {hex(x6)}"
        assert x7 == -85, f"x7 should be -85 (0xFFFFFFAB), got {x7}" # 0xAB is -85 in 8-bit signed
        assert x8 == 0xAB, f"x8 should be 0xAB, got {hex(x8)}"
        
    except Exception as e:
        dut._log.error(f"Failed to inspect registers: {e}")
        raise e

from backup.infrastructure import run_test_simple
from backup.hardware.integration.common import get_rtl_files

def test_memory_ops():
    run_test_simple(
        module_name="test_memory_ops",
        toplevel="chip_top",
        rtl_files=get_rtl_files("core"),
        file_path=__file__
    )
