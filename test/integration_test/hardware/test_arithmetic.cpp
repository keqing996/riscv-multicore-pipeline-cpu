// Test: Arithmetic Operations Integration Test
// Runs arithmetic operations on the full chip

#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include <Vchip_top.h>
#include <Vchip_top___024root.h>

class ChipTopTestbench : public ClockedTestbench<Vchip_top> {
public:
    ChipTopTestbench() : ClockedTestbench<Vchip_top>(100, true, "dump.vcd") {
        dut->rst_n = 0;
    }

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

    uint32_t get_pc_ex() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__id_ex_program_counter;
    }

    void do_reset() {
        dut->rst_n = 0;
        for (int i = 0; i < 20; i++) tick();
        dut->rst_n = 1;
        for (int i = 0; i < 5; i++) tick();
    }
};

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
    tb.do_reset();

    // Run until EBREAK (PC = 0x28 = 40)
    bool ebreak_reached = false;
    for (int cycles = 0; cycles < 1000; cycles++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (pc_ex == 40) { // EBREAK instruction address
            ebreak_reached = true;
            for (int i = 0; i < 10; i++) tb.tick();
            break;
        }
    }

    CHECK(ebreak_reached == true);

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
