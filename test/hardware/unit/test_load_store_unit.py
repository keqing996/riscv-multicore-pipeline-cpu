import cocotb
from cocotb.triggers import Timer
import random
from pathlib import Path
from test.driver import run_hardware_test

@cocotb.test()
async def load_store_unit_test(dut):
    """Test Load Store Unit."""

    # Helper to check Store
    async def check_store(addr, wdata, funct3, exp_wdata, exp_be, exp_we_dmem, exp_we_uart, exp_we_timer, name):
        dut.address.value = addr
        dut.write_data_in.value = wdata
        dut.function_3.value = funct3
        dut.memory_write_enable.value = 1
        dut.memory_read_enable.value = 0
        
        await Timer(1, units="ns")
        
        assert int(dut.bus_write_data.value) == exp_wdata, f"{name} WData Failed"
        assert int(dut.bus_byte_enable.value) == exp_be, f"{name} BE Failed"
        assert int(dut.bus_write_enable.value) == 1, f"{name} WE Failed"
        assert int(dut.bus_address.value) == addr, f"{name} Address Failed"

    # Helper to check Load
    async def check_load(addr, rdata_dmem, rdata_timer, funct3, exp_rdata, name):
        dut.address.value = addr
        if addr >= 0x40000000: # Peripheral range
             dut.bus_read_data.value = rdata_timer
        else:
             dut.bus_read_data.value = rdata_dmem
             
        dut.function_3.value = funct3
        dut.memory_write_enable.value = 0
        dut.memory_read_enable.value = 1
        
        await Timer(1, units="ns")
        
        got = int(dut.memory_read_data_final.value)
        if got >= 0x80000000: got -= 0x100000000 # Signed check
        
        # Handle unsigned expectation
        exp_signed = exp_rdata
        if exp_signed >= 0x80000000: exp_signed -= 0x100000000
        
        assert got == exp_signed, f"{name} Failed: Expected={hex(exp_signed)}, Got={hex(got)}"

    # --- Store Tests ---
    # SW (Aligned)
    await check_store(0x100, 0xAABBCCDD, 0b010, 0xAABBCCDD, 0b1111, 1, 0, 0, "SW Aligned")
    
    # SB (Offset 0)
    await check_store(0x100, 0xDD, 0b000, 0xDDDDDDDD, 0b0001, 1, 0, 0, "SB Offset 0")
    # SB (Offset 1)
    await check_store(0x101, 0xCC, 0b000, 0xCCCCCCCC, 0b0010, 1, 0, 0, "SB Offset 1")
    
    # SH (Offset 0)
    await check_store(0x100, 0xBBAA, 0b001, 0xBBAABBAA, 0b0011, 1, 0, 0, "SH Offset 0")
    # SH (Offset 2)
    await check_store(0x102, 0xDDCC, 0b001, 0xDDCCDDCC, 0b1100, 1, 0, 0, "SH Offset 2")

    # UART Store
    await check_store(0x40000000, 0x41, 0b000, 0x41414141, 0b0001, 0, 1, 0, "UART Store")
    
    # Timer Store
    await check_store(0x40004000, 0x1, 0b010, 0x1, 0b1111, 0, 0, 1, "Timer Store")

    # --- Load Tests ---
    # LW
    await check_load(0x100, 0xAABBCCDD, 0, 0b010, 0xAABBCCDD, "LW")
    
    # LB (Signed)
    await check_load(0x100, 0x000000FF, 0, 0b000, 0xFFFFFFFF, "LB Neg") # 0xFF -> -1
    await check_load(0x100, 0x0000007F, 0, 0b000, 0x7F, "LB Pos")
    
    # LBU (Unsigned)
    await check_load(0x100, 0x000000FF, 0, 0b100, 0xFF, "LBU")
    
    # LH (Signed)
    await check_load(0x100, 0x0000FFFF, 0, 0b001, 0xFFFFFFFF, "LH Neg")
    
    # LHU (Unsigned)
    await check_load(0x100, 0x0000FFFF, 0, 0b101, 0xFFFF, "LHU")

    # Timer Read
    await check_load(0x40004004, 0xDEADBEEF, 0x12345678, 0b010, 0x12345678, "Timer Read")

    dut._log.info("Load Store Unit Test Passed!")

def test_load_store_unit():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="load_store_unit",
        verilog_sources=["core/backend/load_store_unit.v"],
        has_reset=False
    )
