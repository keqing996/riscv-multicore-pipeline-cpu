import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import sys
import os

# Add tests directory to path to import infrastructure
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
from infrastructure import run_test_simple, BACKEND_RTL_FILES

@cocotb.test()
async def backend_stall_test(dut):
    """
    Test that backend handles stall_fetch_stage correctly.
    Verifies that when instruction_grant is low (fetch stall),
    the backend inserts a bubble in ID/EX but allows EX/MEM and MEM/WB to proceed.
    """
    dut._log.info("Starting backend_stall_test")
    
    # Clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.if_id_program_counter.value = 0
    dut.if_id_instruction.value = 0x00000013 # NOP
    dut.if_id_prediction_taken.value = 0
    dut.if_id_prediction_target.value = 0
    dut.instruction_grant.value = 1 
    dut.data_memory_read_data_in.value = 0
    dut.data_memory_busy.value = 0
    
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # 1. Feed Instruction 1: ADDI x1, x0, 10 (0x00a00093)
    # This instruction will enter ID stage
    dut.if_id_instruction.value = 0x00a00093 
    dut.if_id_program_counter.value = 4
    dut.instruction_grant.value = 1
    
    await RisingEdge(dut.clk)
    # End of Cycle 1:
    # ADDI x1 is latched into ID/EX pipeline register
    
    # 2. Stall Fetch (instruction_grant = 0)
    # We simulate a cache miss or busy fetch stage.
    dut.instruction_grant.value = 0
    dut.if_id_instruction.value = 0x01400113 # ADDI x2, x0, 20 (Next instruction, waiting)
    dut.if_id_program_counter.value = 8
    
    # Debug prints before clock edge
    await Timer(1, unit="ns") # Wait a bit for signals to settle
    # dut._log.info(f"Before Clock Edge: instruction_grant={dut.instruction_grant.value}, stall_fetch_stage={dut.stall_fetch_stage.value}")

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns") # Wait for values to propagate
    # End of Cycle 2:
    
    # Check ID/EX (Bubble)
    # Accessing internal signals. Note: signal names might be mangled or hierarchical.
    # In backend.v: reg id_ex_register_write_enable
    if dut.id_ex_register_write_enable.value != 0:
        raise ValueError(f"ID/EX should be bubbled (reg_write=0), got {dut.id_ex_register_write_enable.value}")
        
    # Check EX/MEM (ADDI x1 result)
    # In backend.v: reg ex_mem_register_write_enable
    if dut.ex_mem_register_write_enable.value != 1:
        raise ValueError(f"EX/MEM should have valid instruction (reg_write=1), got {dut.ex_mem_register_write_enable.value}")
    
    if dut.ex_mem_rd_index.value != 1:
        raise ValueError(f"EX/MEM rd should be 1, got {dut.ex_mem_rd_index.value}")
        
    dut._log.info("Cycle 2 Check Passed: ID/EX bubbled, EX/MEM valid")

    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    # End of Cycle 3:
    # - EX/MEM should now have the bubble (from ID/EX)
    # - MEM/WB should have the ADDI x1 result
    
    if dut.ex_mem_register_write_enable.value != 0:
        raise ValueError("EX/MEM should now be bubbled")
        
    if dut.mem_wb_register_write_enable.value != 1:
        raise ValueError("MEM/WB should have valid instruction")
        
    if dut.mem_wb_rd_index.value != 1:
        raise ValueError("MEM/WB rd should be 1")
        
    dut._log.info("Cycle 3 Check Passed: EX/MEM bubbled, MEM/WB valid")
    
    # Release Stall
    dut.instruction_grant.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    # End of Cycle 4:
    # ADDI x2 (which was waiting at inputs) should now be latched into ID/EX
    
    if dut.id_ex_register_write_enable.value != 1:
        raise ValueError("ID/EX should have valid instruction after stall release")
        
    if dut.id_ex_rd_index.value != 2:
        raise ValueError(f"ID/EX rd should be 2, got {dut.id_ex_rd_index.value}")

    dut._log.info("Cycle 4 Check Passed: Stall released, new instruction in ID/EX")
    dut._log.info("backend_stall_test Passed")

@cocotb.test()
async def backend_data_stall_test(dut):
    """
    Test that backend handles data_memory_busy (Data Cache Stall) correctly.
    Verifies that when data_memory_busy is high, the ENTIRE backend (MEM/WB, EX/MEM, ID/EX) stalls.
    """
    dut._log.info("Starting backend_data_stall_test")
    
    # Clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.if_id_program_counter.value = 0
    dut.if_id_instruction.value = 0x00000013 # NOP
    dut.instruction_grant.value = 1 
    dut.data_memory_busy.value = 0
    
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # 1. Feed Instruction 1: ADDI x1, x0, 10 (0x00a00093) -> ID
    dut.if_id_instruction.value = 0x00a00093 
    dut.if_id_program_counter.value = 4
    await RisingEdge(dut.clk)
    
    # 2. Feed Instruction 2: ADDI x2, x0, 20 (0x01400113) -> ID (Instr 1 -> EX)
    dut.if_id_instruction.value = 0x01400113
    dut.if_id_program_counter.value = 8
    await RisingEdge(dut.clk)
    
    # 3. Feed Instruction 3: ADDI x3, x0, 30 (0x01e00193) -> ID (Instr 2 -> EX, Instr 1 -> MEM)
    dut.if_id_instruction.value = 0x01e00193
    dut.if_id_program_counter.value = 12
    await RisingEdge(dut.clk)
    
    # End of Cycle 3:
    # MEM: Instr 1 (ADDI x1)
    # EX:  Instr 2 (ADDI x2)
    # ID:  Instr 3 (ADDI x3)
    
    # 4. Assert Data Stall (data_memory_busy = 1)
    dut.data_memory_busy.value = 1
    # Keep inputs stable (frontend would stall too)
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    # End of Cycle 4:
    # Everything should be FROZEN.
    # MEM/WB should NOT have updated (still Instr 1).
    # EX/MEM should still hold Instr 2.
    # ID/EX should still hold Instr 3.
    
    # Check MEM/WB (Should be Instr 1: ADDI x1, rd=1)
    if dut.mem_wb_rd_index.value != 1:
        raise ValueError(f"MEM/WB should hold Instr 1 (rd=1), got {dut.mem_wb_rd_index.value}")

    # Check EX/MEM (Should be Instr 2: ADDI x2, rd=2)
    if dut.ex_mem_rd_index.value != 2:
        raise ValueError(f"EX/MEM should hold Instr 2 (rd=2), got {dut.ex_mem_rd_index.value}")
        
    # Check ID/EX (Should be Instr 3: ADDI x3, rd=3)
    if dut.id_ex_rd_index.value != 3:
        raise ValueError(f"ID/EX should hold Instr 3 (rd=3), got {dut.id_ex_rd_index.value}")
        
    dut._log.info("Cycle 4 Check Passed: Pipeline Frozen")
    
    # 5. Release Stall
    dut.data_memory_busy.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    # End of Cycle 5:
    # Pipeline advances.
    # MEM/WB: Instr 2
    # EX/MEM: Instr 3
    # ID/EX: Instr 4 (or bubble/garbage if no new input)
    
    if dut.mem_wb_rd_index.value != 2:
        raise ValueError(f"MEM/WB should have Instr 2 (rd=2), got {dut.mem_wb_rd_index.value}")
        
    if dut.ex_mem_rd_index.value != 3:
        raise ValueError(f"EX/MEM should have Instr 3 (rd=3), got {dut.ex_mem_rd_index.value}")

    dut._log.info("Cycle 5 Check Passed: Pipeline Advanced")
    dut._log.info("backend_data_stall_test Passed")

from infrastructure import run_test_simple
from .common import get_rtl_files

def test_backend():
    run_test_simple(
        module_name="test_backend",
        toplevel="backend",
        rtl_files=get_rtl_files("backend"),
        file_path=__file__
    )
