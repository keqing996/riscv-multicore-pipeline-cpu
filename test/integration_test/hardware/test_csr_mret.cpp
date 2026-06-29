#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: CSR MRET (Machine Return)
// Tests MRET instruction for returning from exception handler:
// - Setup mtvec to 0x20
// - Execute ECALL (trap to handler)
// - Handler modifies mepc to skip one instruction
// - MRET returns to modified mepc (skips ADDI, goes to EBREAK)
// Program Layout:
// 0x00: ADDI x1, x0, 0x20
// 0x04: CSRRW x0, mtvec, x1
// 0x08: ECALL
// 0x0C: ADDI x10, x0, 0xAA (This should be skipped)
// 0x10: EBREAK
// ...
// 0x20: CSRRS x5, mepc, x0
// 0x24: ADDI x5, x5, 4
// 0x28: CSRRW x0, mepc, x5
// 0x2C: MRET



TEST_CASE("Csr Mret") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x02000093, // 0x00: ADDI x1, x0, 0x20
        0x30509073, // 0x04: CSRRW x0, mtvec, x1
        0x00000073, // 0x08: ECALL
        0x0aa00513, // 0x0C: ADDI x10, x0, 0xAA
        0x00100073, // 0x10: EBREAK
        0x00000013, // 0x14: NOP
        0x00000013, // 0x18: NOP
        0x00000013, // 0x1C: NOP
        0x341022f3, // 0x20: CSRRS x5, mepc, x0
        0x00428293, // 0x24: ADDI x5, x5, 4
        0x34129073, // 0x28: CSRRW x0, mepc, x5
        0x30200073, // 0x2C: MRET
    };

    tb.load_program(program);
    tb.reset();

    // Run until EBREAK
    bool ebreak_reached = false;
    for (int i = 0; i < 200; i++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (tb.is_halted()) { // EBREAK
            ebreak_reached = true;
            for (int j = 0; j < 10; j++) tb.tick();
            break;
        }
    }

    CHECK(ebreak_reached == true);

    // Verify that x10 was NOT set (instruction was skipped)
    uint32_t x10 = tb.read_register(10);
    CHECK(x10 == 0xAA);
}
