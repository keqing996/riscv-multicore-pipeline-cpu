#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
// Test: Memory Operations Integration Test
// Tests byte/halfword/word load and store operations:
// - LUI x1, 1          (x1 = 0x1000)
// - ADDI x2, x0, 0xAB  (x2 = 0xAB)
// - SB x2, 0(x1)       (Mem[0x1000] = 0xAB)
// - ADDI x3, x0, 0xCD
// - SB x3, 1(x1)       (Mem[0x1001] = 0xCD)
// - ADDI x4, x0, 0xEF
// - SB x4, 2(x1)       (Mem[0x1002] = 0xEF)
// - ADDI x5, x0, 0x12
// - SB x5, 3(x1)       (Mem[0x1003] = 0x12)
// - LW x6, 0(x1)       (x6 = 0x12EFCDAB)
// - LB x7, 0(x1)       (x7 = 0xFFFFFFAB)
// - LBU x8, 0(x1)      (x8 = 0x000000AB)
// - EBREAK

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

TEST_CASE("Memory Ops") {
ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x000010b7, // LUI x1, 1
        0x0ab00113, // ADDI x2, x0, 0xAB
        0x00208023, // SB x2, 0(x1)
        0x0cd00193, // ADDI x3, x0, 0xCD
        0x003080a3, // SB x3, 1(x1)
        0x0ef00213, // ADDI x4, x0, 0xEF
        0x00408123, // SB x4, 2(x1)
        0x01200293, // ADDI x5, x0, 0x12
        0x005081a3, // SB x5, 3(x1)
        0x0000a303, // LW x6, 0(x1)
        0x00008383, // LB x7, 0(x1)
        0x0000c403, // LBU x8, 0(x1)
        0x00100073, // EBREAK
        0x00000013, // NOP
        0x00000013, // NOP
    };

    tb.load_program(program);
    tb.do_reset();

    // Run until EBREAK (PC = 0x30 = 48)
    bool ebreak_reached = false;
    for (int cycles = 0; cycles < 1000; cycles++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (pc_ex == 48) { // EBREAK instruction address
            ebreak_reached = true;
            for (int i = 0; i < 10; i++) tb.tick();
            break;
        }
    }

    CHECK(ebreak_reached == true);

    // Verify Register Values
    uint32_t x6 = tb.read_register(6);
    uint32_t x7 = tb.read_register(7);
    uint32_t x8 = tb.read_register(8);

    CHECK(x6 == 0x12EFCDAB);
    CHECK(x7 == 0xFFFFFFAB);
    CHECK(x8 == 0x000000AB);
}
