#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: CSR Exception Handling
// Tests exception handling with ECALL:
// - Setup mtvec to point to handler
// - Execute ECALL (causes exception)
// - Handler reads mcause and mepc
// Program Layout:
// 0x00: ADDI x1, x0, 0x20
// 0x04: CSRRW x0, mtvec, x1  (Set handler to 0x20)
// 0x08: ECALL                (Trigger exception)
// ...
// 0x20: CSRRS x2, mcause, x0 (Read mcause=11)
// 0x24: CSRRS x3, mepc, x0   (Read mepc=0x8)
// 0x28: ADDI x4, x2, 1  (Use mcause immediately)
// 0x2C: ADDI x5, x3, 4  (Use mepc immediately)
// 0x30: EBREAK



TEST_CASE("Csr Exception") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x02000093, // 0x00: ADDI x1, x0, 0x20
        0x30509073, // 0x04: CSRRW x0, mtvec, x1
        0x00000073, // 0x08: ECALL
        0x00000013, // 0x0C: NOP
        0x00000013, // 0x10: NOP
        0x00000013, // 0x14: NOP
        0x00000013, // 0x18: NOP
        0x00000013, // 0x1C: NOP
        0x34202173, // 0x20: CSRRS x2, mcause, x0 (Handler)
        0x341021f3, // 0x24: CSRRS x3, mepc, x0
        0x00110213, // 0x28: ADDI x4, x2, 1
        0x00418293, // 0x2C: ADDI x5, x3, 4
        0x00100073, // 0x30: EBREAK
    };

    tb.load_program(program);
    tb.reset();

    CHECK(tb.run_until_halted(200));

    // Verify Results
    uint32_t x2 = tb.read_register(2);
    uint32_t x3 = tb.read_register(3);
    uint32_t x4 = tb.read_register(4);
    uint32_t x5 = tb.read_register(5);

    CHECK(x2 == 11);
    CHECK(x3 == 0x8);
    CHECK(x4 == 12);
    CHECK(x5 == 0xC);
}
