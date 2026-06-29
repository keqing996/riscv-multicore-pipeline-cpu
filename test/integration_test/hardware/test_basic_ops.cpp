#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: Basic Operations Integration Test
// Runs a simple assembly program on the full chip:
// - ADDI x1, x0, 10  (x1 = 10)
// - ADDI x2, x0, 20  (x2 = 20)
// - ADD x3, x1, x2   (x3 = 30)
// - LUI x5, 1        (x5 = 0x1000)
// - SW x3, 0(x5)     (Mem[0x1000] = 30)
// - LW x4, 0(x5)     (x4 = 30)
// - EBREAK           (Stop)



TEST_CASE("Basic Ops") {
ChipTopTestbench tb;

    // Machine Code Program
    std::vector<uint32_t> program = {
        0x00a00093, // ADDI x1, x0, 10
        0x01400113, // ADDI x2, x0, 20
        0x002081b3, // ADD x3, x1, x2
        0x000012b7, // LUI x5, 1
        0x0032a023, // SW x3, 0(x5)
        0x0002a203, // LW x4, 0(x5)
        0x00100073, // EBREAK
        0x00000013, // NOP
        0x00000013, // NOP
        0x00000013, // NOP
    };

    // Reset and load program
    tb.load_program(program);  // Load before reset
    tb.reset();

    CHECK(tb.run_until_halted(5000));

    // Verify Register Values
    uint32_t x1 = tb.read_register(1);
    uint32_t x2 = tb.read_register(2);
    uint32_t x3 = tb.read_register(3);
    uint32_t x4 = tb.read_register(4);
    uint32_t x5 = tb.read_register(5);

    CHECK(x1 == 10);
    CHECK(x2 == 20);
    CHECK(x3 == 30);
    CHECK(x4 == 30);
    CHECK(x5 == 0x1000);

    // Verify Memory Content
    uint32_t mem_val = tb.read_memory_word(0x1000);
    CHECK(mem_val == 30);
}
