#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: Hazard Handling Integration Test
// Tests RAW hazards and load-use hazards:
// - ADDI x1, x0, 10
// - ADDI x2, x0, 20
// - ADD x3, x1, x2     (x3 = 30)
// - ADD x4, x3, x1     (x4 = 40) (RAW Hazard on x3)
// - ADD x5, x3, x4     (x5 = 70) (RAW Hazard on x3 and x4)
// - LUI x6, 1          (x6 = 0x1000)
// - SW x5, 0(x6)       (Mem[0x1000] = 70)
// - LW x7, 0(x6)       (x7 = 70)
// - ADD x8, x7, x1     (x8 = 80) (Load-Use Hazard on x7)
// - EBREAK



TEST_CASE("Hazards") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x00a00093, // ADDI x1, x0, 10
        0x01400113, // ADDI x2, x0, 20
        0x002081b3, // ADD x3, x1, x2
        0x00118233, // ADD x4, x3, x1
        0x004182b3, // ADD x5, x3, x4
        0x00001337, // LUI x6, 1
        0x00532023, // SW x5, 0(x6)
        0x00032383, // LW x7, 0(x6)
        0x00138433, // ADD x8, x7, x1
        0x00100073, // EBREAK
        0x00000013, // NOP
        0x00000013, // NOP
    };

    tb.load_program(program);
    tb.reset();

    CHECK(tb.run_until_halted(1000));

    // Verify Register Values
    CHECK(tb.read_register(3) == 30);
    CHECK(tb.read_register(4) == 40);
    CHECK(tb.read_register(5) == 70);
    CHECK(tb.read_register(7) == 70);
    CHECK(tb.read_register(8) == 80);
}
