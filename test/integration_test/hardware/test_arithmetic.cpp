// Test: Arithmetic Operations Integration Test
// Runs arithmetic operations on the full chip

#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"


TEST_CASE("Arithmetic Operations Integration Test") {
    ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x00a00093, // ADDI x1, x0, 10
        0x00500113, // ADDI x2, x0, 5
        0x002081b3, // ADD x3, x1, x2
        0x40208233, // SUB x4, x1, x2
        0x0020f2b3, // AND x5, x1, x2
        0x0020e333, // OR x6, x1, x2
        0x0020c3b3, // XOR x7, x1, x2
        0x00209433, // SLL x8, x1, x2
        0x002054b3, // SRL x9, x1, x2
        0x00112533, // SLT x10, x2, x1
        0x00100073, // EBREAK
        0x00000013, // NOP
        0x00000013, // NOP
    };

    tb.load_program(program);
    tb.reset();

    CHECK(tb.run_until_halted(300));

    // Verify Register Values
    CHECK(tb.read_register(1) == 10);
    CHECK(tb.read_register(2) == 5);
    CHECK(tb.read_register(3) == 15);
    CHECK(tb.read_register(4) == 5);
    CHECK(tb.read_register(5) == 0);
    CHECK(tb.read_register(6) == 15);
    CHECK(tb.read_register(7) == 15);
    CHECK(tb.read_register(8) == 320);
    CHECK(tb.read_register(9) == 0);
    CHECK(tb.read_register(10) == 1);
}
