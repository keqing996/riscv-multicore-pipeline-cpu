import cocotb
import sys
import os

# Add tests directory to path to import cocotb_utils
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from cocotb_utils import run_test_common

@cocotb.test()
async def test_simple_alu(dut):
    """Test Simple ALU Logic."""
    await run_test_common(dut, cycles=200)
    
    # Verification
    # Check x3 register (index 3)
    # Hierarchy: system_top -> u_core -> u_regfile -> registers
    reg_val = dut.u_core.u_regfile.registers[3].value
    
    expected_val = 30
    assert reg_val == expected_val, f"Register x3 mismatch! Expected {expected_val}, got {reg_val}"
