import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from pathlib import Path
from test.driver import run_hardware_test
from test.env import get_all_rtl_files

PROGRAM = [
    "02000093", # 0x00: ADDI x1, x0, 0x20
    "30509073", # 0x04: CSRRW x0, mtvec, x1
    "00000073", # 0x08: ECALL
    "00000013", # 0x0C: NOP
    "00000013", # 0x10: NOP
    "00000013", # 0x14: NOP
    "00000013", # 0x18: NOP
    "00000013", # 0x1C: NOP
    "34202173", # 0x20: CSRRS x2, mcause, x0 (Handler)
    "341021f3", # 0x24: CSRRS x3, mepc, x0
    "00100073", # 0x28: EBREAK
]

def create_hex_file(filename="program.hex"):
    with open(filename, "w") as f:
        for instr in PROGRAM:
            f.write(f"{instr}\n")

@cocotb.test()
async def test_csr_exception_program(dut):
    create_hex_file("program.hex")
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    
    for i in range(100):
        await RisingEdge(dut.clk)
        try:
            pc = dut.u_core.u_backend.id_ex_program_counter.value.integer
            mcause_val = dut.u_core.u_backend.u_control_status_register_file.mcause.value
            csr_addr = dut.u_core.u_backend.u_control_status_register_file.csr_address.value
            csr_rdata = dut.u_core.u_backend.u_control_status_register_file.csr_read_data.value
            wb_we = dut.u_core.u_backend.mem_wb_register_write_enable.value
            wb_rd = dut.u_core.u_backend.mem_wb_rd_index.value
            wb_data = dut.u_core.u_backend.write_data_writeback.value
            dut._log.info(f"Cycle {i}: PC={hex(pc)}, mcause={mcause_val}, csr_addr={csr_addr}, csr_rdata={csr_rdata}, wb_we={wb_we}, wb_rd={wb_rd}, wb_data={wb_data}")
            if pc == 0x28: # EBREAK
                break
        except:
            pass
    
    await RisingEdge(dut.clk) # Wait for x2 WB
    await RisingEdge(dut.clk) # Wait for x3 WB

    x2 = dut.u_core.u_backend.u_regfile.registers[2].value.integer
    x3 = dut.u_core.u_backend.u_regfile.registers[3].value.integer
    
    assert x2 == 11, f"mcause should be 11, got {x2}"
    assert x3 == 0x8, f"mepc should be 0x8, got {x3}"

def test_csr_exception():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="chip_top",
        verilog_sources=get_all_rtl_files()
    )
