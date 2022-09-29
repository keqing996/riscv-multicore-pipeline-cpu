import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_hazard(dut):
    """Test Load-Use Hazard Stall"""
    
    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    # Wait for a few cycles
    for _ in range(20):
        await RisingEdge(dut.clk)
        
    # Check if PC advances past the stall
    # The program has 2 instructions + NOPs.
    # 0x00: LW
    # 0x04: ADD (Stall here)
    # 0x08: NOP
    
    # We expect PC to eventually reach 0x10 or more.
    
    final_pc = int(dut.u_core.program_counter_current.value)
    dut._log.info(f"Final PC: {final_pc}")
    
    assert final_pc > 0x08, f"PC stuck at {final_pc}, expected > 0x08"
