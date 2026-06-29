#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: CSR Read/Write Operations
// Tests CSRRW, CSRRS, CSRRC instructions:
// - CSRRW: Write x1 to mtvec, read old value to x2
// - CSRRS: Set bits in mtvec, read old value to x4
// - CSRRC: Clear bits in mtvec, read old value to x5



TEST_CASE("Csr Rw") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x0aa00093, // ADDI x1, x0, 0xAA
        0x30509173, // CSRRW x2, mtvec, x1
        0x05500193, // ADDI x3, x0, 0x55
        0x3051a273, // CSRRS x4, mtvec, x3
        0x3051b2f3, // CSRRC x5, mtvec, x3
        0x00100073, // EBREAK
    };

    tb.load_program(program);
    tb.reset();

    for (int i = 0; i < 500; i++) {
        tb.tick();
        if (tb.is_halted()) {
            break;
        }
    }

    CHECK(tb.is_halted());

    // Verify Results
    // x2 should be old mtvec (0)
    // x4 should be 0xAA
    // x5 should be 0xFF
    // Final mtvec should be 0xAA
    uint32_t x2 = tb.read_register(2);
    uint32_t x4 = tb.read_register(4);
    uint32_t x5 = tb.read_register(5);
    uint32_t mtvec = tb.read_csr_mtvec();

    CHECK(x2 == 0);
    CHECK(x4 == 0xAA);
    CHECK(x5 == 0xFF);
    CHECK(mtvec == 0xAA);
}
