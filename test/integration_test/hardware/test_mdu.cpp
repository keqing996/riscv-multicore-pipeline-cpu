#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: MDU Operations Integration Test
// Tests multiply, divide, and remainder operations:
// - ADDI x1, x0, 10   (x1 = 10)
// - ADDI x2, x0, 5    (x2 = 5)
// - MUL x3, x1, x2    (x3 = 50)
// - ADDI x4, x0, 100  (x4 = 100)
// - DIV x5, x4, x2    (x5 = 20)
// - ADDI x6, x0, 7    (x6 = 7)
// - REM x7, x4, x6    (x7 = 2)
// - EBREAK
// Note: MDU operations take ~32 cycles each



TEST_CASE("Mdu") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x00a00093, // ADDI x1, x0, 10
        0x00500113, // ADDI x2, x0, 5
        0x022081b3, // MUL x3, x1, x2
        0x06400213, // ADDI x4, x0, 100
        0x022242b3, // DIV x5, x4, x2
        0x00700313, // ADDI x6, x0, 7
        0x026263b3, // REM x7, x4, x6
        0x00100073, // EBREAK
        0x00000013, // NOP
        0x00000013, // NOP
    };

    tb.load_program(program);
    tb.reset();

    CHECK(tb.run_until_halted(1000));

    // Verify Register Values
    CHECK(tb.read_register(3) == 50);
    CHECK(tb.read_register(5) == 20);
    CHECK(tb.read_register(7) == 2);
}
