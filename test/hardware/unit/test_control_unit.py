import cocotb
from cocotb.triggers import Timer
from pathlib import Path
from test.driver import run_hardware_test

@cocotb.test()
async def control_unit_test(dut):
    """Test Control Unit."""

    # Helper to check output
    async def check(opcode, funct3, rs1, expected_signals, name):
        dut.opcode.value = opcode
        dut.function_3.value = funct3
        dut.rs1_index.value = rs1
        await Timer(1, units="ns")
        
        # expected_signals is a dict of signal_name -> value
        for sig, val in expected_signals.items():
            got = int(getattr(dut, sig).value)
            assert got == val, f"{name} Failed: Signal {sig}, Expected={val}, Got={got}"

    # 1. R-Type (0110011)
    await check(0b0110011, 0, 0, {
        "register_write_enable": 1,
        "alu_operation_code": 0b010,
        "alu_source_select": 0,
        "memory_write_enable": 0,
        "branch": 0,
        "jump": 0
    }, "R-Type")

    # 2. I-Type (0010011)
    await check(0b0010011, 0, 0, {
        "register_write_enable": 1,
        "alu_operation_code": 0b011,
        "alu_source_select": 1,
        "memory_write_enable": 0
    }, "I-Type")

    # 3. Load (0000011)
    await check(0b0000011, 0, 0, {
        "register_write_enable": 1,
        "memory_read_enable": 1,
        "memory_to_register_select": 1,
        "alu_source_select": 1,
        "alu_operation_code": 0b000
    }, "Load")

    # 4. Store (0100011)
    await check(0b0100011, 0, 0, {
        "memory_write_enable": 1,
        "alu_source_select": 1,
        "register_write_enable": 0,
        "alu_operation_code": 0b000
    }, "Store")

    # 5. Branch (1100011)
    await check(0b1100011, 0, 0, {
        "branch": 1,
        "alu_operation_code": 0b001,
        "register_write_enable": 0
    }, "Branch")

    # 6. JAL (1101111)
    await check(0b1101111, 0, 0, {
        "jump": 1,
        "register_write_enable": 1,
        "alu_source_select": 0 # JAL uses PC+4 logic usually, but here check RTL
    }, "JAL")

    # 7. JALR (1100111)
    await check(0b1100111, 0, 0, {
        "jump": 1,
        "register_write_enable": 1,
        "alu_source_select": 1,
        "alu_operation_code": 0b000
    }, "JALR")

    # 8. LUI (0110111)
    await check(0b0110111, 0, 0, {
        "register_write_enable": 1,
        "alu_source_select": 1,
        "alu_operation_code": 0b100
    }, "LUI")

    # 9. AUIPC (0010111)
    await check(0b0010111, 0, 0, {
        "register_write_enable": 1,
        "alu_source_select": 1,
        "alu_source_a_select": 1,
        "alu_operation_code": 0b000
    }, "AUIPC")

    # 10. CSRRW (1110011, f3=001)
    await check(0b1110011, 0b001, 0, {
        "register_write_enable": 1,
        "csr_write_enable": 1,
        "csr_to_register_select": 1
    }, "CSRRW")

    dut._log.info("Control Unit Test Passed!")

def test_control_unit():
    run_hardware_test(
        module_name=Path(__file__).stem,
        toplevel="control_unit",
        verilog_sources=["core/backend/control_unit.v"],
        has_reset=False
    )
