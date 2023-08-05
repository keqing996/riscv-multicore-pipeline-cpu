#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
// Test: CSR Read/Write Operations
// Tests CSRRW, CSRRS, CSRRC instructions:
// - CSRRW: Write x1 to mtvec, read old value to x2
// - CSRRS: Set bits in mtvec, read old value to x4
// - CSRRC: Clear bits in mtvec, read old value to x5

#include <Vchip_top.h>
#include <Vchip_top___024root.h>

class ChipTopTestbench : public ClockedTestbench<Vchip_top> {
public:
    ChipTopTestbench() : ClockedTestbench<Vchip_top>(100, true, "dump.vcd") {
        dut->rst_n = 0;
    }

public:
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }

    void load_program(const std::vector<uint32_t>& program) {
        for (size_t i = 0; i < program.size(); i++) {
            dut->rootp->chip_top__DOT__u_memory_subsystem__DOT__u_main_memory__DOT__memory[i] = program[i];
        }
    }

    uint32_t read_register(int reg_idx) {
        if (reg_idx < 0 || reg_idx >= 32) return 0;
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_regfile__DOT__registers[reg_idx];
    }

    uint32_t read_csr_mtvec() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mtvec;
    }

    void do_reset() {
        dut->rst_n = 0;
        for (int i = 0; i < 20; i++) tick();
        dut->rst_n = 1;
        for (int i = 0; i < 5; i++) tick();
    }
};

TEST_CASE("Csr Rw") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x0aa00093, // ADDI x1, x0, 0xAA
        0x30509173, // CSRRW x2, mtvec, x1
        0x05500193, // ADDI x3, x0, 0x55
        0x3051a273, // CSRRS x4, mtvec, x3
        0x3051b2f3, // CSRRC x5, mtvec, x3
        0x00000013, // NOP
        0x00000013, // NOP
        0x00000013, // NOP
    };

    tb.load_program(program);
    tb.do_reset();

    // Run for enough cycles
    for (int i = 0; i < 50; i++) {
        tb.tick();
    }

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
