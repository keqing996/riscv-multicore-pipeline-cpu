import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from pathlib import Path
from typing import List, Union
from test.driver import run_software_test
from test.env import get_all_rtl_files

@cocotb.test()
async def fibonacci_test(dut):
    """
    Run Fibonacci C program.
    """
    # Clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    
    # Wait for EBREAK
    ebreak_detected = False
    for i in range(200000): # 200k cycles
        await RisingEdge(dut.clk)

        # Check for EBREAK in EX stage (id_ex_program_counter)
        # EBREAK is at 0xC.
        try:
            pc_ex = dut.u_core.u_backend.id_ex_program_counter.value.integer
            if pc_ex == 0xC:
                dut._log.info(f"EBREAK detected in EX stage at cycle {i}")
                ebreak_detected = True
                break
        except:
            pass

    if not ebreak_detected:
        raise TimeoutError("Simulation timed out without hitting EBREAK")

    # Wait a few cycles for pipeline to flush/writeback
    for _ in range(10):
        await RisingEdge(dut.clk)

    # Dump Registers
    dut._log.info("Register Dump:")
    for r in range(32):
        try:
            val = dut.u_core.u_backend.u_regfile.registers[r].value
            dut._log.info(f"x{r}: {val}")
        except:
            pass

    # Check Result in x10 (a0)
    try:
        x10 = dut.u_core.u_backend.u_regfile.registers[10].value.integer
        expected = 55 # fib(10)
        assert x10 == expected, f"Fibonacci Failed: Expected {expected}, Got {x10}"
        dut._log.info(f"Fibonacci Passed: Result {x10}")
    except Exception as e:
        dut._log.error(f"Verification failed: {e}")
        raise e

def test_fibonacci():
    run_software_test(
        module_name=Path(__file__).stem,
        toplevel="chip_top",
        verilog_sources=get_all_rtl_files(),
        c_sources=[
            "test_fibonacci/main.c",
            "test_fibonacci/start.S"
        ],
        c_includes=[]
    )
