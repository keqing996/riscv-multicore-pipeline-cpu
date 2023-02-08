import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import sys
import os

from backup.infrastructure import run_test_simple

@cocotb.test()
async def csr_file_test(dut):
    """Test CSR File."""

    # Start Clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.csr_address.value = 0
    dut.csr_write_enable.value = 0
    dut.csr_write_data.value = 0
    dut.exception_enable.value = 0
    dut.exception_program_counter.value = 0
    dut.exception_cause.value = 0
    dut.machine_return_enable.value = 0
    dut.timer_interrupt_request.value = 0
    
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await Timer(10, units="ns")

    # Addresses
    CSR_MSTATUS = 0x300
    CSR_MIE     = 0x304
    CSR_MTVEC   = 0x305
    CSR_MEPC    = 0x341
    CSR_MCAUSE  = 0x342
    CSR_MIP     = 0x344

    # 1. Basic Read/Write
    # Write MTVEC
    dut.csr_address.value = CSR_MTVEC
    dut.csr_write_data.value = 0x1000
    dut.csr_write_enable.value = 1
    await RisingEdge(dut.clk)
    dut.csr_write_enable.value = 0
    await Timer(1, units="ns")
    
    # Read MTVEC
    dut.csr_address.value = CSR_MTVEC
    await Timer(1, units="ns")
    assert dut.csr_read_data.value == 0x1000, "MTVEC Write/Read Failed"
    assert dut.mtvec_out.value == 0x1000, "MTVEC Output Failed"

    # 2. Exception Handling
    # Enable Interrupts (MIE bit 3 in MSTATUS)
    dut.csr_address.value = CSR_MSTATUS
    dut.csr_write_data.value = 0b1000 # MIE=1
    dut.csr_write_enable.value = 1
    await RisingEdge(dut.clk)
    dut.csr_write_enable.value = 0
    
    # Trigger Exception
    dut.exception_enable.value = 1
    dut.exception_program_counter.value = 0x500
    dut.exception_cause.value = 0x8
    await RisingEdge(dut.clk)
    dut.exception_enable.value = 0
    await Timer(1, units="ns")
    
    # Check MEPC and MCAUSE
    dut.csr_address.value = CSR_MEPC
    await Timer(1, units="ns")
    assert dut.csr_read_data.value == 0x500, "MEPC Update Failed"
    
    dut.csr_address.value = CSR_MCAUSE
    await Timer(1, units="ns")
    assert dut.csr_read_data.value == 0x8, "MCAUSE Update Failed"
    
    # Check MSTATUS (MIE should be 0, MPIE should be 1)
    dut.csr_address.value = CSR_MSTATUS
    await Timer(1, units="ns")
    mstatus = int(dut.csr_read_data.value)
    assert (mstatus & 0x8) == 0, "MIE not cleared"
    assert (mstatus & 0x80) == 0x80, "MPIE not set"

    # 3. MRET (Return from Exception)
    dut.machine_return_enable.value = 1
    await RisingEdge(dut.clk)
    dut.machine_return_enable.value = 0
    await Timer(1, units="ns")
    
    # Check MSTATUS (MIE restored to 1)
    dut.csr_address.value = CSR_MSTATUS
    await Timer(1, units="ns")
    mstatus = int(dut.csr_read_data.value)
    assert (mstatus & 0x8) == 0x8, "MIE not restored"

    # 4. Timer Interrupt
    # Enable Timer Interrupt (MTIE bit 7 in MIE)
    dut.csr_address.value = CSR_MIE
    dut.csr_write_data.value = 0x80 # MTIE=1
    dut.csr_write_enable.value = 1
    await RisingEdge(dut.clk)
    dut.csr_write_enable.value = 0
    
    # Assert Timer Interrupt Request
    dut.timer_interrupt_request.value = 1
    await Timer(1, units="ns")
    
    # Check MIP (Bit 7 should be 1)
    dut.csr_address.value = CSR_MIP
    await Timer(1, units="ns")
    assert (int(dut.csr_read_data.value) & 0x80) == 0x80, "MIP not reflecting Timer IRQ"
    
    # Check Interrupt Output
    assert dut.interrupt_enable.value == 1, "Interrupt Output not asserted"
    
    # Clock edge to take interrupt
    dut.exception_program_counter.value = 0x600
    await RisingEdge(dut.clk)
    dut.timer_interrupt_request.value = 0 # Clear IRQ (simulated)
    await Timer(1, units="ns")
    
    # Check MEPC and MCAUSE
    dut.csr_address.value = CSR_MEPC
    await Timer(1, units="ns")
    assert dut.csr_read_data.value == 0x600, "MEPC (IRQ) Failed"
    
    dut.csr_address.value = CSR_MCAUSE
    await Timer(1, units="ns")
    assert dut.csr_read_data.value == 0x80000007, "MCAUSE (IRQ) Failed"

    dut._log.info("CSR File Test Passed!")

def test_control_status_register_file():
    run_test_simple(
        module_name="test_control_status_register_file",
        toplevel="control_status_register_file",
        rtl_files=["core/backend/control_status_register_file.v"],
        file_path=__file__
    )
