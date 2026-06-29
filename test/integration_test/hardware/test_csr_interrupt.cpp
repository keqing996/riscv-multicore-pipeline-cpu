#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: CSR Timer Interrupt
// Tests timer interrupt handling:
// - Setup mtvec, enable interrupts (MIE bit in mstatus)
// - Configure mtimecmp to trigger at 100 cycles
// - Wait in infinite loop until interrupt fires
// - Handler sets x10=1 and executes EBREAK



TEST_CASE("Csr Interrupt") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x04000093, // 0x00: ADDI x1, x0, 0x40
        0x30509073, // 0x04: CSRRW x0, mtvec, x1
        0x00800093, // 0x08: ADDI x1, x0, 0x8
        0x3000a073, // 0x0C: CSRRS x0, mstatus, x1
        0x08000093, // 0x10: ADDI x1, x0, 0x80
        0x3040a073, // 0x14: CSRRS x0, mie, x1
        0x400040b7, // 0x18: LUI x1, 0x40004
        0x00c08293, // 0x1C: ADDI x5, x1, 12 (0x4000400C - mtimecmp high)
        0x0002a023, // 0x20: SW x0, 0(x5) (Write 0 to mtimecmp high)
        0x00808093, // 0x24: ADDI x1, x1, 8 (0x40004008 - mtimecmp low)
        0x06400113, // 0x28: ADDI x2, x0, 100
        0x0020a023, // 0x2C: SW x2, 0(x1)
        0x0000006f, // 0x30: J 0x30 (Infinite loop)
        0x00000013, // 0x34: NOP
        0x00000013, // 0x38: NOP
        0x00000013, // 0x3C: NOP (Padding)
        0x00100513, // 0x40: ADDI x10, x0, 1
        0x00100073, // 0x44: EBREAK
    };

    tb.load_program(program);
    tb.reset();

    CHECK(tb.run_until_halted(500));

    // Verify that interrupt handler executed
    uint32_t x10 = tb.read_register(10);
    CHECK(x10 == 1);
}
