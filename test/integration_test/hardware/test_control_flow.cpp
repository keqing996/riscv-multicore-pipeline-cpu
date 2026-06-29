#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: Control Flow Integration Test
// Tests branch and jump instructions:
// - ADDI x1, x0, 10  (x1 = 10)
// - ADDI x2, x0, 10  (x2 = 10)
// - BEQ x1, x2, 8    (Jump to PC+8)
// - ADDI x3, x0, 1   (Skipped)
// - ADDI x4, x0, 5   (x4 = 5)
// - JAL x5, 8        (Jump to PC+8, x5 = return address)
// - ADDI x6, x0, 1   (Skipped)
// - EBREAK           (Stop)



TEST_CASE("Control Flow") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x00a00093, // ADDI x1, x0, 10
        0x00a00113, // ADDI x2, x0, 10
        0x00208463, // BEQ x1, x2, 8
        0x00100193, // ADDI x3, x0, 1
        0x00500213, // ADDI x4, x0, 5
        0x008002ef, // JAL x5, 8
        0x00100313, // ADDI x6, x0, 1
        0x00100073, // EBREAK
        0x00000013, // NOP
        0x00000013, // NOP
    };

    tb.load_program(program);
    tb.reset();

    CHECK(tb.run_until_halted(1000));

    // Verify Register Values
    CHECK(tb.read_register(1) == 10);
    CHECK(tb.read_register(2) == 10);
    CHECK(tb.read_register(3) == 0);
    CHECK(tb.read_register(4) == 5);
    CHECK(tb.read_register(5) == 0x18);
    CHECK(tb.read_register(6) == 0);
}
