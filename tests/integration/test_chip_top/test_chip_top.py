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
async def test_chip_top_simple_program(dut):
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
        
        # Debug: Trace Execution
        try:
            pc_curr = dut.u_core.program_counter_current.value.integer
            pc_ex = dut.u_core.id_ex_program_counter.value.integer
            alu_res = dut.u_core.alu_result_execute.value.integer
            # Handle scalar signals which might be Logic objects
            reg_we_val = dut.u_core.id_ex_register_write_enable.value
            reg_we = int(reg_we_val) if hasattr(reg_we_val, 'integer') else int(reg_we_val)
            
            rd = dut.u_core.id_ex_rd_index.value.integer
            
            dut._log.info(f"Cycle {i}: PC_Curr={pc_curr}, PC_EX={pc_ex}, ALU_Res={alu_res}, RD={rd}, WE={reg_we}")
            
            if pc_ex == 8: # ADD instruction
                dut._log.info(f"EXECUTE ADD: PC={pc_ex}, ALU_Res={alu_res}, RD={rd}, WE={reg_we}")
                # Check inputs
                op_a = dut.u_core.alu_input_a_execute.value.integer
                op_b = dut.u_core.alu_input_b_execute.value.integer
                dut._log.info(f"  OpA={op_a}, OpB={op_b}")

            # Check Memory Interface
            mem_we = dut.dmem_we.value
            if mem_we == 1:
                mem_addr = dut.dmem_addr.value.integer
                mem_wdata = dut.dmem_wdata.value.integer
                mem_be = dut.dmem_be.value.integer
                dut._log.info(f"MEM WRITE: Addr={mem_addr:x}, Data={mem_wdata}, BE={mem_be:b}")
                
        except Exception as e:
            # dut._log.warning(f"Debug trace failed: {e}")
            pass

        if pc_ex == 24: # EBREAK instruction address (0x18)
            dut._log.info("EBREAK Executed. Stopping.")
            # Wait for pipeline to flush and writeback
            for _ in range(10):
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
        # Use to_unsigned() or integer (deprecated but works for now)
        # Note: accessing array elements in cocotb can be tricky if not exposed correctly
        # But usually works for Icarus.
        x1 = dut.u_core.u_regfile.registers[1].value.integer
        x2 = dut.u_core.u_regfile.registers[2].value.integer
        x3 = dut.u_core.u_regfile.registers[3].value.integer
        x4 = dut.u_core.u_regfile.registers[4].value.integer
        x5 = dut.u_core.u_regfile.registers[5].value.integer
        
        dut._log.info(f"x1 = {x1}")
        dut._log.info(f"x2 = {x2}")
        dut._log.info(f"x3 = {x3}")
        dut._log.info(f"x4 = {x4}")
        dut._log.info(f"x5 = {x5}")
        
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
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))
from infrastructure import run_test_simple

if __name__ == "__main__":
    run_test_simple(
        module_name="test_chip_top",
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
