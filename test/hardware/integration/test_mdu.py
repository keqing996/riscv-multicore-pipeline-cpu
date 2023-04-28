import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from test.driver import run_hardware_test

# Machine Code for MDU Operations
# 0: ADDI x1, x0, 10   (x1 = 10)
# 4: ADDI x2, x0, 5    (x2 = 5)
# 8: MUL x3, x1, x2    (x3 = 50)  -> 022081b3
# C: ADDI x4, x0, 100  (x4 = 100)
# 10: DIV x5, x4, x2   (x5 = 20)  -> 022242b3
# 14: ADDI x6, x0, 7   (x6 = 7)
# 18: REM x7, x4, x6   (x7 = 2)   -> 026263b3
# 1C: EBREAK
PROGRAM = [
    "00a00093", # ADDI x1, x0, 10
    "00500113", # ADDI x2, x0, 5
    "022081b3", # MUL x3, x1, x2
    "06400213", # ADDI x4, x0, 100
    "022242b3", # DIV x5, x4, x2
    "00700313", # ADDI x6, x0, 7
    "026263b3", # REM x7, x4, x6
    "00100073", # EBREAK
    "00000013", # NOP
    "00000013", # NOP
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_mdu_program(dut):
    """
    Run MDU operations test.
    """
    create_hex_file("program.hex")

    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    # Wait for execution
    # MDU operations take ~32 cycles each.
    # 3 MDU ops = ~100 cycles.
    # Plus other ops.
    # 1000 cycles should be enough.
    
    for i in range(1000):
        await RisingEdge(dut.clk)
        try:
            pc_ex = dut.u_tile_0.u_core.u_backend.id_ex_program_counter.value.integer
        except:
            pc_ex = 0

        if pc_ex == 28: # EBREAK address (0x1C)
            dut._log.info("EBREAK Executed. Stopping.")
            for _ in range(100):
                await RisingEdge(dut.clk)
            break
            
    # Verify State
    try:
        x3 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[3].value.integer
        x5 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[5].value.integer
        x7 = dut.u_tile_0.u_core.u_backend.u_regfile.registers[7].value.integer
        
        dut._log.info(f"x3 (MUL 10*5) = {x3}")
        dut._log.info(f"x5 (DIV 100/5) = {x5}")
        dut._log.info(f"x7 (REM 100%7) = {x7}")
        
        assert x3 == 50, f"x3 should be 50, got {x3}"
        assert x5 == 20, f"x5 should be 20, got {x5}"
        assert x7 == 2, f"x7 should be 2, got {x7}"
        
    except Exception as e:
        dut._log.error(f"Failed to inspect registers: {e}")
        raise e


from test.env import get_all_rtl_files

def test_mdu():
    run_hardware_test(
        module_name="test_mdu",
        verilog_sources=get_all_rtl_files(),
        toplevel="chip_top"
    )

if __name__ == "__main__":
    test_mdu()
