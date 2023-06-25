// Test: CSR Exception Handling
// Tests exception handling with ECALL:
// - Setup mtvec to point to handler
// - Execute ECALL (causes exception)
// - Handler reads mcause and mepc
// Program Layout:
// 0x00: ADDI x1, x0, 0x20
// 0x04: CSRRW x0, mtvec, x1  (Set handler to 0x20)
// 0x08: ECALL                (Trigger exception)
// ...
// 0x20: CSRRS x2, mcause, x0 (Read mcause=11)
// 0x24: CSRRS x3, mepc, x0   (Read mepc=0x8)
// 0x28: EBREAK

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
        0x02000093, // 0x00: ADDI x1, x0, 0x20
        0x30509073, // 0x04: CSRRW x0, mtvec, x1
        0x00000073, // 0x08: ECALL
        0x00000013, // 0x0C: NOP
        0x00000013, // 0x10: NOP
        0x00000013, // 0x14: NOP
        0x00000013, // 0x18: NOP
        0x00000013, // 0x1C: NOP
        0x34202173, // 0x20: CSRRS x2, mcause, x0 (Handler)
        0x341021f3, // 0x24: CSRRS x3, mepc, x0
        0x00100073, // 0x28: EBREAK
    };

    tb.reset();
    tb.load_program(program);

    // Run until EBREAK
    bool ebreak_reached = false;
    for (int i = 0; i < 100; i++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (pc_ex == 0x28) { // EBREAK
            ebreak_reached = true;
            // Wait for writeback
            tb.tick();
            tb.tick();
            break;
        }
    }

    TB_ASSERT_EQ(ebreak_reached, true, "EBREAK should be reached");

    // Verify Results
    uint32_t x2 = tb.read_register(2);
    uint32_t x3 = tb.read_register(3);

    TB_ASSERT_EQ(x2, 11, "mcause should be 11 (ECALL from M-mode)");
    TB_ASSERT_EQ(x3, 0x8, "mepc should be 0x8 (ECALL instruction address)");

    return 0;
}
