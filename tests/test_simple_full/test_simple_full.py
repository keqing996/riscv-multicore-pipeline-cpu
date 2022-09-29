import cocotb
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from cocotb_utils import run_test_common

@cocotb.test()
async def test_simple_full(dut):
    """Test Simple Full Logic."""
    await run_test_common(dut, cycles=200)
    
    # Verification
    # Check x4 register (index 4)
    reg_val = dut.u_core.u_regfile.registers[4].value
    
    expected_val = 12
    assert reg_val == expected_val, f"Register x4 mismatch! Expected {expected_val}, got {reg_val}"
