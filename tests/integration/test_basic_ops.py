import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import os

# Machine Code for:
# 0: ADDI x1, x0, 10  (x1 = 10)
# 4: ADDI x2, x0, 20  (x2 = 20)
# 8: ADD x3, x1, x2   (x3 = 30)
# C: LUI x5, 1        (x5 = 0x1000)
# 10: SW x3, 0(x5)    (Mem[0x1000] = 30)
# 14: LW x4, 0(x5)    (x4 = 30)
# 18: EBREAK          (Stop)
PROGRAM = [
    "00a00093", # ADDI x1, x0, 10
    "01400113", # ADDI x2, x0, 20
    "002081b3", # ADD x3, x1, x2
    "000012b7", # LUI x5, 1
    "0032a023", # SW x3, 0(x5)
    "0002a203", # LW x4, 0(x5)
    "00100073", # EBREAK
    "00000013", # NOP
    "00000013", # NOP
    "00000013", # NOP
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")
        # Fill the rest with NOPs or zeros if needed, but readmemh handles partial
        
@cocotb.test()
async def test_basic_ops_program(dut):
    """
    Run a simple assembly program on the full chip.
    """
    # Create hex file in the current directory (where simulation runs)
    create_hex_file("program.hex")

    # Clock Generation
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    # Wait for execution
    for i in range(500):
        await RisingEdge(dut.clk)
        
        try:
            pc_ex = dut.u_core.id_ex_program_counter.value.integer
        except:
            pc_ex = 0

        if pc_ex == 24: # EBREAK instruction address (0x18)
            dut._log.info("EBREAK Executed. Stopping.")
            # Wait for pipeline to flush and writeback
            for _ in range(100):
                await RisingEdge(dut.clk)
            
            # Check Memory Content directly
            try:
                mem_val = dut.u_main_memory.memory[1024].value.integer
                dut._log.info(f"Memory[0x1000] = {mem_val}")
            except Exception as e:
                dut._log.warning(f"Failed to read memory: {e}")
                
            break
            
    # Verify State
    try:
        x1 = dut.u_core.u_regfile.registers[1].value.integer
        x2 = dut.u_core.u_regfile.registers[2].value.integer
        x3 = dut.u_core.u_regfile.registers[3].value.integer
        x4 = dut.u_core.u_regfile.registers[4].value.integer
        x5 = dut.u_core.u_regfile.registers[5].value.integer
        
        assert x1 == 10, f"x1 should be 10, got {x1}"
        assert x2 == 20, f"x2 should be 20, got {x2}"
        assert x3 == 30, f"x3 should be 30, got {x3}"
        assert x5 == 0x1000, f"x5 should be 0x1000, got {x5}"
        assert x4 == 30, f"x4 should be 30, got {x4}"
        
    except Exception as e:
        dut._log.error(f"Failed to inspect registers: {e}")
        raise e

import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from infrastructure import run_test_simple

def test_basic_ops():
    run_test_simple(
        module_name="test_basic_ops",
        toplevel="chip_top",
        rtl_files=[
            "system/chip_top.v",
            "core/core.v",
            "core/alu.v",
            "core/alu_control_unit.v",
            "core/branch_predictor.v",
            "core/branch_unit.v",
            "core/control_unit.v",
            "core/control_status_register_file.v",
            "core/instruction_decoder.v",
            "core/forwarding_unit.v",
            "core/hazard_detection_unit.v",
            "core/immediate_generator.v",
            "core/load_store_unit.v",
            "core/program_counter.v",
            "core/regfile.v",
            "memory/main_memory.v",
            "cache/instruction_cache.v",
            "peripherals/timer.v",
            "peripherals/uart_simulator.v"
        ],
        file_path=__file__
    )
