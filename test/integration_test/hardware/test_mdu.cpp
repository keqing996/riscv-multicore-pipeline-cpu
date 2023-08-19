#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
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
    tb.do_reset();

    // Run until EBREAK (PC = 0x1C = 28)
    // MDU operations take ~32 cycles each. 3 MDU ops = ~100 cycles.
    bool ebreak_reached = false;
    for (int cycles = 0; cycles < 1000; cycles++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (pc_ex == 28) { // EBREAK instruction address
            ebreak_reached = true;
            for (int i = 0; i < 10; i++) tb.tick();
            break;
        }
    }

    CHECK(ebreak_reached == true);

    // Verify Register Values
    CHECK(tb.read_register(3) == 50);
    CHECK(tb.read_register(5) == 20);
    CHECK(tb.read_register(7) == 2);
}
