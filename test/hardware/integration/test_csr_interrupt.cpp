// Test: CSR Timer Interrupt
// Tests timer interrupt handling:
// - Setup mtvec, enable interrupts (MIE bit in mstatus)
// - Configure mtimecmp to trigger at 100 cycles
// - Wait in infinite loop until interrupt fires
// - Handler sets x10=1 and executes EBREAK

#include "../common/tb_base.h"
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

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    ChipTopTestbench tb;

    std::vector<uint32_t> program = {
        0x04000093, // 0x00: ADDI x1, x0, 0x40
        0x30509073, // 0x04: CSRRW x0, mtvec, x1
        0x00800093, // 0x08: ADDI x1, x0, 0x8
        0x3000a073, // 0x0C: CSRRS x0, mstatus, x1
        0x08000093, // 0x10: ADDI x1, x0, 0x80
        0x3040a073, // 0x14: CSRRS x0, mie, x1
        0x400040b7, // 0x18: LUI x1, 0x40004
        0x00c08293, // 0x1C: ADDI x5, x1, 12 (0x4000400C - mtimecmp high)
        0x0002a023, // 0x20: SW x0, 0(x5) (Write 0 to mtimecmp high)
        0x00808093, // 0x24: ADDI x1, x1, 8 (0x40004008 - mtimecmp low)
        0x06400113, // 0x28: ADDI x2, x0, 100
        0x0020a023, // 0x2C: SW x2, 0(x1)
        0x0000006f, // 0x30: J 0x30 (Infinite loop)
        0x00000013, // 0x34: NOP
        0x00000013, // 0x38: NOP
        0x00000013, // 0x3C: NOP (Padding)
        0x00100513, // 0x40: ADDI x10, x0, 1
        0x00100073, // 0x44: EBREAK
    };

    tb.load_program(program);
    tb.do_reset();

    // Run until EBREAK (interrupt should fire)
    bool ebreak_reached = false;
    for (int i = 0; i < 500; i++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (pc_ex == 0x44) { // EBREAK
            ebreak_reached = true;
            for (int j = 0; j < 10; j++) tb.tick();
            break;
        }
    }

    TB_ASSERT_EQ(ebreak_reached, true, "EBREAK should be reached");

    // Verify that interrupt handler executed
    uint32_t x10 = tb.read_register(10);
    TB_ASSERT_EQ(x10, 1, "x10 should be 1 (Interrupt Handler Executed)");

    return 0;
}
