import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test

@cocotb.test()
async def branch_predictor_test(dut):
    """Test Branch Predictor (BTB + BHT)."""

    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.program_counter_fetch.value = 0
    dut.program_counter_execute.value = 0
    dut.branch_taken_execute.value = 0
    dut.branch_target_execute.value = 0
    dut.is_branch_execute.value = 0
    dut.is_jump_execute.value = 0
    
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await Timer(10, units="ns")

    # 1. Initial State: Not Taken (BHT=01 Weakly Not Taken)
    pc_test = 0x100
    dut.program_counter_fetch.value = pc_test
    await Timer(1, units="ns")
    assert dut.prediction_taken.value == 0, "Initial prediction should be Not Taken"

    # 2. Train: Taken once (01 -> 10 Weakly Taken)
    # Execute stage updates
    dut.program_counter_execute.value = pc_test
    dut.branch_taken_execute.value = 1
    dut.branch_target_execute.value = 0x200
    dut.is_branch_execute.value = 1
    
    await RisingEdge(dut.clk)
    dut.is_branch_execute.value = 0
    await Timer(1, units="ns")
    
    # Check Prediction (Should be Taken now)
    dut.program_counter_fetch.value = pc_test
    await Timer(1, units="ns")
    assert dut.prediction_taken.value == 1, "Prediction should be Taken after 1 training"
    assert dut.prediction_target.value == 0x200, "Target mismatch"

    # 3. Train: Taken again (10 -> 11 Strongly Taken)
    dut.program_counter_execute.value = pc_test
    dut.branch_taken_execute.value = 1
    dut.branch_target_execute.value = 0x200
    dut.is_branch_execute.value = 1
    
    await RisingEdge(dut.clk)
    dut.is_branch_execute.value = 0
    await Timer(1, units="ns")
    
    # Check Prediction
    assert dut.prediction_taken.value == 1, "Prediction should be Taken (Strong)"

    # 4. Train: Not Taken (11 -> 10 Weakly Taken)
    dut.program_counter_execute.value = pc_test
    dut.branch_taken_execute.value = 0
    dut.is_branch_execute.value = 1
    
    await RisingEdge(dut.clk)
    dut.is_branch_execute.value = 0
    await Timer(1, units="ns")
    
    # Check Prediction (Still Taken)
    assert dut.prediction_taken.value == 1, "Prediction should be Taken (Weak)"

    # 5. Train: Not Taken again (10 -> 01 Weakly Not Taken)
    dut.program_counter_execute.value = pc_test
    dut.branch_taken_execute.value = 0
    dut.is_branch_execute.value = 1
    
    await RisingEdge(dut.clk)
    dut.is_branch_execute.value = 0
    await Timer(1, units="ns")
    
    # Check Prediction (Now Not Taken)
    assert dut.prediction_taken.value == 0, "Prediction should be Not Taken"

    # 6. Aliasing Check (Different PC, same index)
    # Index bits = 6 (bits 7:2). 
    # PC1 = 0x100 (..0001 0000 0000) -> Index 0
    # PC2 = 0x500 (..0101 0000 0000) -> Index 0
    pc_alias = 0x500
    
    # Train PC2 to Taken
    dut.program_counter_execute.value = pc_alias
    dut.branch_taken_execute.value = 1
    dut.branch_target_execute.value = 0x600
    dut.is_branch_execute.value = 1
    
    await RisingEdge(dut.clk)
    dut.is_branch_execute.value = 0
    await Timer(1, units="ns")
    
    # Check PC2 (Should be Taken)
    dut.program_counter_fetch.value = pc_alias
    await Timer(1, units="ns")
    assert dut.prediction_taken.value == 1, "Alias PC should be Taken"
    
    # Check PC1 (Should be Not Taken because tag mismatch)
    dut.program_counter_fetch.value = pc_test
    await Timer(1, units="ns")
    assert dut.prediction_taken.value == 0, "Original PC should be Not Taken (Tag Mismatch)"

    dut._log.info("Branch Predictor Test Passed!")

def test_branch_predictor():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="branch_predictor",
        verilog_sources=["core/frontend/branch_predictor.v"]
    )
