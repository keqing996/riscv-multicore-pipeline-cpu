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

    tb.reset();
    tb.load_program(program);

    // Run until EBREAK (PC = 0x24 = 36)
    bool ebreak_reached = false;
    for (int cycles = 0; cycles < 1000; cycles++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (pc_ex == 36) { // EBREAK instruction address
            ebreak_reached = true;
            for (int i = 0; i < 10; i++) tb.tick();
            break;
        }
    }

    TB_ASSERT_EQ(ebreak_reached, true, "EBREAK should be reached");

    // Verify Register Values
    TB_ASSERT_EQ(tb.read_register(3), 30, "x3 should be 30");
    TB_ASSERT_EQ(tb.read_register(4), 40, "x4 should be 40 (RAW hazard handled)");
    TB_ASSERT_EQ(tb.read_register(5), 70, "x5 should be 70 (RAW hazards handled)");
    TB_ASSERT_EQ(tb.read_register(7), 70, "x7 should be 70 (load result)");
    TB_ASSERT_EQ(tb.read_register(8), 80, "x8 should be 80 (load-use hazard handled)");

    return 0;
}
