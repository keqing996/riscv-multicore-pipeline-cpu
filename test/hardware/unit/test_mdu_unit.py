import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from test.driver import run_hardware_test
import random

# Operations
OP_MUL    = 0b000
OP_MULH   = 0b001
OP_MULHSU = 0b010
OP_MULHU  = 0b011
OP_DIV    = 0b100
OP_DIVU   = 0b101
OP_REM    = 0b110
OP_REMU   = 0b111

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.operation.value = 0
    dut.operand_a.value = 0
    dut.operand_b.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def run_operation(dut, op, a, b):
    dut.operation.value = op
    dut.operand_a.value = a
    dut.operand_b.value = b
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for ready
    while not dut.ready.value:
        await RisingEdge(dut.clk)
        
    return dut.result.value

@cocotb.test()
async def test_mdu_basic(dut):
    """
    Basic MDU Unit Test
    """
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    # Test 1: MUL 10 * 5 = 50
    res = await run_operation(dut, OP_MUL, 10, 5)
    assert res.integer == 50, f"MUL 10*5 failed. Got {res.integer}"
    dut._log.info("MUL 10*5 passed")
    
    # Test 2: DIV 100 / 5 = 20
    res = await run_operation(dut, OP_DIV, 100, 5)
    assert res.integer == 20, f"DIV 100/5 failed. Got {res.integer}"
    dut._log.info("DIV 100/5 passed")
    
    # Test 3: REM 100 % 7 = 2
    res = await run_operation(dut, OP_REM, 100, 7)
    assert res.integer == 2, f"REM 100%7 failed. Got {res.integer}"
    dut._log.info("REM 100%7 passed")

    # Test 4: DIV by 0
    # RISC-V: x / 0 = -1 (all 1s)
    res = await run_operation(dut, OP_DIV, 100, 0)
    assert res.integer == -1 or res.integer == 4294967295, f"DIV by 0 failed. Got {res.integer}"
    dut._log.info("DIV by 0 passed")

    # Test 5: REM by 0
    # RISC-V: x % 0 = x
    res = await run_operation(dut, OP_REM, 123, 0)
    assert res.integer == 123, f"REM by 0 failed. Got {res.integer}"
    dut._log.info("REM by 0 passed")

    # Test 6: Signed MUL (Negative)
    # -10 * 5 = -50
    # -10 is 0xFFFFFFF6
    res = await run_operation(dut, OP_MUL, 0xFFFFFFF6, 5)
    # Result should be -50 (0xFFFFFFCE)
    # cocotb BinaryValue.integer is signed if we treat it so, but let's check unsigned representation or signed
    assert res.signed_integer == -50, f"MUL -10*5 failed. Got {res.signed_integer}"
    dut._log.info("MUL -10*5 passed")

    # Test 7: Signed DIV
    # -100 / 5 = -20
    res = await run_operation(dut, OP_DIV, 0xFFFFFF9C, 5)
    assert res.signed_integer == -20, f"DIV -100/5 failed. Got {res.signed_integer}"
    dut._log.info("DIV -100/5 passed")


def test_mdu_unit():
    run_hardware_test(
        module_name="test_mdu_unit",
        verilog_sources=["core/backend/mdu.v"],
        toplevel="mdu"
    )

if __name__ == "__main__":
    test_mdu_unit()
