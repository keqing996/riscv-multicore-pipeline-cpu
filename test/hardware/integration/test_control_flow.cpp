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

#include "../common/tb_base.h"
#include <Vchip_top.h>

class ChipTopTestbench : public ClockedTestbench<Vchip_top> {
public:
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }

    void load_program(const std::vector<uint32_t>& program) {
        for (size_t i = 0; i < program.size(); i++) {
            dut->rootp->chip_top__DOT__u_main_memory__DOT__memory[i] = program[i];
        }
    }

    uint32_t read_register(int reg_idx) {
        if (reg_idx < 0 || reg_idx >= 32) return 0;
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_regfile__DOT__registers[reg_idx];
    }

    uint32_t get_pc_ex() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__id_ex_program_counter;
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    ChipTopTestbench tb;
    tb.open_trace("dump.vcd");

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

    tb.reset();
    tb.load_program(program);

    // Run until EBREAK (PC = 0x1C = 28)
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

    TB_ASSERT_EQ(ebreak_reached, true, "EBREAK should be reached");

    // Verify Register Values
    TB_ASSERT_EQ(tb.read_register(1), 10, "x1 should be 10");
    TB_ASSERT_EQ(tb.read_register(2), 10, "x2 should be 10");
    TB_ASSERT_EQ(tb.read_register(3), 0, "x3 should be 0 (skipped)");
    TB_ASSERT_EQ(tb.read_register(4), 5, "x4 should be 5");
    TB_ASSERT_EQ(tb.read_register(5), 0x18, "x5 should be 0x18 (return address)");
    TB_ASSERT_EQ(tb.read_register(6), 0, "x6 should be 0 (skipped)");

    return 0;
}
