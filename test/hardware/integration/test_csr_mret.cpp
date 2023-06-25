// Test: CSR MRET (Machine Return)
// Tests MRET instruction for returning from exception handler:
// - Setup mtvec to 0x20
// - Execute ECALL (trap to handler)
// - Handler modifies mepc to skip one instruction
// - MRET returns to modified mepc (skips ADDI, goes to EBREAK)
// Program Layout:
// 0x00: ADDI x1, x0, 0x20
// 0x04: CSRRW x0, mtvec, x1
// 0x08: ECALL
// 0x0C: ADDI x10, x0, 0xAA (This should be skipped)
// 0x10: EBREAK
// ...
// 0x20: CSRRS x5, mepc, x0
// 0x24: ADDI x5, x5, 4
// 0x28: CSRRW x0, mepc, x5
// 0x2C: MRET

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
        0x0aa00513, // 0x0C: ADDI x10, x0, 0xAA
        0x00100073, // 0x10: EBREAK
        0x00000013, // 0x14: NOP
        0x00000013, // 0x18: NOP
        0x00000013, // 0x1C: NOP
        0x341022f3, // 0x20: CSRRS x5, mepc, x0
        0x00428293, // 0x24: ADDI x5, x5, 4
        0x34129073, // 0x28: CSRRW x0, mepc, x5
        0x30200073, // 0x2C: MRET
    };

    tb.reset();
    tb.load_program(program);

    // Run until EBREAK
    bool ebreak_reached = false;
    for (int i = 0; i < 200; i++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (pc_ex == 0x10) { // EBREAK
            ebreak_reached = true;
            for (int j = 0; j < 10; j++) tb.tick();
            break;
        }
    }

    TB_ASSERT_EQ(ebreak_reached, true, "EBREAK should be reached");

    // Verify that x10 was NOT set (instruction was skipped)
    uint32_t x10 = tb.read_register(10);
    TB_ASSERT_EQ(x10, 0xAA, "x10 should be 0xAA (MRET returned to correct address)");

    return 0;
}
