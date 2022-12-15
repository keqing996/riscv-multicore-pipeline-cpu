import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import sys
import os

# Add tests directory to path to import infrastructure
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from infrastructure import run_test_simple

@cocotb.test()
async def backend_stall_test(dut):
    """
    Test that backend handles stall_fetch_stage correctly.
    Verifies that when instruction_grant is low (fetch stall),
    the backend inserts a bubble in ID/EX but allows EX/MEM and MEM/WB to proceed.
    """
    dut._log.info("Starting backend_stall_test")
    
    # Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.if_id_program_counter.value = 0
    dut.if_id_instruction.value = 0x00000013 # NOP
    dut.if_id_prediction_taken.value = 0
    dut.if_id_prediction_target.value = 0
    dut.instruction_grant.value = 1 
    dut.data_memory_read_data_in.value = 0
    
    await Timer(20, units="ns")
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
    # We might provide a new instruction on inputs, but it shouldn't be taken if grant is 0 (conceptually)
    # But backend logic uses instruction_grant to stall.
    dut.instruction_grant.value = 0
    dut.if_id_instruction.value = 0x01400113 # ADDI x2, x0, 20 (Next instruction, waiting)
    dut.if_id_program_counter.value = 8
    
    await RisingEdge(dut.clk)
    # End of Cycle 2:
    # Because of our fix:
    # - ID/EX should have been flushed (inserted bubble) because stall_fetch_stage is active.
    # - EX/MEM should have captured the result of ADDI x1 (which was in EX stage during Cycle 2).
    
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
    # End of Cycle 4:
    # ADDI x2 (which was waiting at inputs) should now be latched into ID/EX
    
    # Note: In real hardware, if instruction_grant is 0, the IF/ID register also wouldn't update.
    # Here we are driving backend inputs directly.
    # Since we kept 0x01400113 on the inputs, it should now be in ID/EX.
    
    if dut.id_ex_register_write_enable.value != 1:
        raise ValueError("ID/EX should have valid instruction after stall release")
        
    if dut.id_ex_rd_index.value != 2:
        raise ValueError(f"ID/EX rd should be 2, got {dut.id_ex_rd_index.value}")

    dut._log.info("Cycle 4 Check Passed: Stall released, new instruction in ID/EX")
    dut._log.info("backend_stall_test Passed")


@cocotb.test()
async def backend_alu_test(dut):
    """
    Test basic ALU operations in the backend.
    """
    dut._log.info("Starting backend_alu_test")
    
    # Reset
    dut.rst_n.value = 0
    dut.instruction_grant.value = 1
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 1. ADDI x3, x0, 15 (0x00f00193)
    dut.if_id_instruction.value = 0x00f00193
    dut.if_id_program_counter.value = 0x10
    await RisingEdge(dut.clk)
    
    # 2. ADDI x4, x0, 25 (0x01900213)
    dut.if_id_instruction.value = 0x01900213
    dut.if_id_program_counter.value = 0x14
    await RisingEdge(dut.clk)
    
    # 3. ADD x5, x3, x4 (0x004182b3)
    dut.if_id_instruction.value = 0x004182b3
    dut.if_id_program_counter.value = 0x18
    await RisingEdge(dut.clk)
    
    # 4. NOPs to flush
    dut.if_id_instruction.value = 0x00000013
    for _ in range(5):
        await RisingEdge(dut.clk)
        
    # Verify Register File
    # Accessing regfile internal array
    # u_regfile.registers[i]
    
    x3 = dut.u_regfile.registers[3].value.integer
    x4 = dut.u_regfile.registers[4].value.integer
    x5 = dut.u_regfile.registers[5].value.integer
    
    if x3 != 15: raise ValueError(f"x3 should be 15, got {x3}")
    if x4 != 25: raise ValueError(f"x4 should be 25, got {x4}")
    if x5 != 40: raise ValueError(f"x5 should be 40, got {x5}")
    
    dut._log.info("backend_alu_test Passed")

def test_backend():
    run_test_simple(
        module_name="test_backend",
        toplevel="backend",
        rtl_files=[
            "core/backend/backend.v",
            "core/backend/alu.v",
            "core/backend/alu_control_unit.v",
            "core/backend/branch_unit.v",
            "core/backend/control_unit.v",
            "core/backend/control_status_register_file.v",
            "core/backend/instruction_decoder.v",
            "core/backend/forwarding_unit.v",
            "core/backend/hazard_detection_unit.v",
            "core/backend/immediate_generator.v",
            "core/backend/load_store_unit.v",
            "core/backend/regfile.v",
            "peripherals/timer.v",
            "peripherals/uart_simulator.v"
        ],
        file_path=__file__
    )
