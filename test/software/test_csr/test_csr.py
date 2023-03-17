import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_software_test
from test.env import get_all_rtl_files

@cocotb.test()
async def csr_test(dut):
    """
    Test CSR Exception Handling (ECALL -> Trap Handler -> MRET)
    """
    # Clock
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    
    trap_handler_hit = False
    ecall_return_hit = False
    
    for i in range(5000):
        await RisingEdge(dut.clk)
        
        try:
            s11 = dut.u_core.u_backend.u_regfile.registers[27].value.to_unsigned() # s11 used in trap handler
            s4 = dut.u_core.u_backend.u_regfile.registers[20].value.to_unsigned()  # s4 used in main
            
            instr = dut.u_core.u_backend.if_id_instruction.value.to_unsigned()
            is_ecall = dut.u_core.u_backend.u_control_unit.is_environment_call.value
            flush_trap = dut.u_core.u_backend.flush_due_to_trap.value
            
            if instr == 0x00000073:
                dut._log.info(f"Cycle {i}: ECALL in IF/ID. is_ecall={is_ecall}, flush_trap={flush_trap}")
            
            if instr == 0x00100073: # EBREAK
                 dut._log.info(f"Cycle {i}: EBREAK detected in IF/ID")

            if s11 == 0xCAFEBABE and not trap_handler_hit:
                dut._log.info(f"Cycle {i}: Trap Handler Hit! (s11=0xCAFEBABE)")
                trap_handler_hit = True
                
                s2 = dut.u_core.u_backend.u_regfile.registers[18].value.to_unsigned()
                
                mcause_reg = dut.u_core.u_backend.u_control_status_register_file.mcause.value.to_unsigned()
                dut._log.info(f"Cycle {i}: s2 (read from mcause) = {s2}, mcause_reg = {mcause_reg}")

                if s2 == 11:
                    dut._log.info(f"Cycle {i}: MCAUSE is correct (11)")

            if trap_handler_hit:
                 s3 = dut.u_core.u_backend.u_regfile.registers[19].value.to_unsigned() # s3 (mepc)
                 mepc_reg = dut.u_core.u_backend.u_control_status_register_file.mepc.value.to_unsigned()
                 
                 csr_read_data = dut.u_core.u_backend.csr_read_data_execute.value.to_unsigned()
                 id_ex_imm = dut.u_core.u_backend.id_ex_immediate.value.to_unsigned()
                 
                 dut._log.info(f"Cycle {i}: Trap State: s3={s3}, mepc_reg={mepc_reg}, csr_read_data={csr_read_data}, id_ex_imm={hex(id_ex_imm)}")

            # Check if we returned from trap (s4 = 0x12345678)
            if s4 == 0x12345678 and trap_handler_hit:
                dut._log.info(f"Cycle {i}: Returned from Trap! (s4=0x12345678)")
                ecall_return_hit = True
                break
                
        except ValueError:
            pass
            
    if not trap_handler_hit:
        raise Exception("Did not enter trap handler")
        
    if not ecall_return_hit:
        raise Exception("Did not return from trap handler")

    dut._log.info("CSR Exception Test Passed!")

def test_csr():
    run_software_test(
        module_name=Path(__file__).stem,
        toplevel="chip_top",
        verilog_sources=get_all_rtl_files(),
        c_sources=[
            "test_csr/main.c",
            "test_csr/start.S"
        ],
        c_includes=[]
    )
