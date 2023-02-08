import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test

@cocotb.test()
async def instruction_cache_test(dut):
    """Test Instruction Cache."""

    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.program_counter_address.value = 0
    dut.instruction_memory_read_data.value = 0
    dut.instruction_memory_ready.value = 0
    
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    await Timer(10, unit="ns")

    # 1. Miss and Refill
    # Request Address 0x1000 (Tag=0x100, Index=0, Offset=0)
    addr = 0x1000
    dut.program_counter_address.value = addr
    
    await Timer(1, unit="ns")
    assert dut.stall_cpu.value == 1, "Should stall on miss"
    assert dut.instruction_memory_request.value == 1, "Should request memory"
    
    # Simulate Memory Response (4 words)
    # Word 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.instruction_memory_address.value == 0x1000, "Mem Addr 0 Mismatch"
    dut.instruction_memory_read_data.value = 0xAAAAAAAA
    dut.instruction_memory_ready.value = 1
    
    # Word 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.instruction_memory_address.value == 0x1004, "Mem Addr 1 Mismatch"
    dut.instruction_memory_read_data.value = 0xBBBBBBBB
    
    # Word 2
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.instruction_memory_address.value == 0x1008, "Mem Addr 2 Mismatch"
    dut.instruction_memory_read_data.value = 0xCCCCCCCC
    
    # Word 3
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.instruction_memory_address.value == 0x100C, "Mem Addr 3 Mismatch"
    dut.instruction_memory_read_data.value = 0xDDDDDDDD
    
    # Update State
    await RisingEdge(dut.clk)
    dut.instruction_memory_ready.value = 0
    
    # Back to IDLE (Hit)
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.stall_cpu.value == 0, "Should not stall after refill"
    assert dut.instruction.value == 0xAAAAAAAA, "Instruction 0 Mismatch"

    # 2. Hit (Same Block, Different Offset)
    # Offset 4 (Word 1)
    dut.program_counter_address.value = 0x1004
    await Timer(1, unit="ns")
    assert dut.stall_cpu.value == 0, "Should hit Word 1"
    assert dut.instruction.value == 0xBBBBBBBB, "Instruction 1 Mismatch"
    
    # Offset 8 (Word 2)
    dut.program_counter_address.value = 0x1008
    await Timer(1, unit="ns")
    assert dut.instruction.value == 0xCCCCCCCC, "Instruction 2 Mismatch"
    
    # Offset 12 (Word 3)
    dut.program_counter_address.value = 0x100C
    await Timer(1, unit="ns")
    assert dut.instruction.value == 0xDDDDDDDD, "Instruction 3 Mismatch"

    # 3. Miss (Different Index)
    # Address 0x2000 (Index=0x00, Tag=0x200) -> Conflict Miss (Same Index 0)
    # Wait, Index bits=8. 
    # 0x1000: 0001 0000 0000 0000 -> Index 0
    # 0x2000: 0010 0000 0000 0000 -> Index 0
    # Yes, conflict.
    
    dut.program_counter_address.value = 0x2000
    await Timer(1, unit="ns")
    assert dut.stall_cpu.value == 1, "Should stall on conflict miss"
    
    # Refill again...
    dut.instruction_memory_ready.value = 1
    dut.instruction_memory_read_data.value = 0x11111111
    
    # Wait for FETCH_0 state
    await RisingEdge(dut.clk) 
    # Now in FETCH_0. Data is 0x11111111.
    
    # Wait for FETCH_1 state
    await RisingEdge(dut.clk) 
    # Now in FETCH_1. Update to Word 1.
    dut.instruction_memory_read_data.value = 0x22222222
    
    # Wait for FETCH_2 state
    await RisingEdge(dut.clk) 
    # Now in FETCH_2. Update to Word 2.
    dut.instruction_memory_read_data.value = 0x33333333
    
    # Wait for FETCH_3 state
    await RisingEdge(dut.clk) 
    # Now in FETCH_3. Update to Word 3.
    dut.instruction_memory_read_data.value = 0x44444444
    
    await RisingEdge(dut.clk) # Update
    dut.instruction_memory_ready.value = 0
    
    await RisingEdge(dut.clk) # Idle
    await Timer(1, unit="ns")
    assert dut.instruction.value == 0x11111111, "New Block Instruction Mismatch"

    dut._log.info("Instruction Cache Test Passed!")

def test_instruction_cache():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="instruction_cache",
        verilog_sources=["cache/instruction_cache.v"]
    )
