// Test: Basic Operations Integration Test
// Runs a simple assembly program on the full chip:
// - ADDI x1, x0, 10  (x1 = 10)
// - ADDI x2, x0, 20  (x2 = 20)
// - ADD x3, x1, x2   (x3 = 30)
// - LUI x5, 1        (x5 = 0x1000)
// - SW x3, 0(x5)     (Mem[0x1000] = 30)
// - LW x4, 0(x5)     (x4 = 30)
// - EBREAK           (Stop)

#include "../common/tb_base.h"
#include <Vchip_top.h>
#include <Vchip_top___024root.h>  // For internal signals
#include <fstream>

class ChipTopTestbench : public ClockedTestbench<Vchip_top> {
public:
    ChipTopTestbench() : ClockedTestbench<Vchip_top>(100, true, "dump.vcd") {
        // Initialize inputs
        dut->rst_n = 0;
    }

    void set_clk(uint8_t value) override {
        dut->clk = value;
    }

    void load_program(const std::vector<uint32_t>& program) {
        // Write program to instruction memory via backdoor
        for (size_t i = 0; i < program.size(); i++) {
            uint32_t instr = program[i];
            // Access via rootp (internal structure access enabled by --public flag)
            dut->rootp->chip_top__DOT__u_memory_subsystem__DOT__u_main_memory__DOT__memory[i] = instr;
        }
    }

    uint32_t read_register(int reg_idx) {
        if (reg_idx < 0 || reg_idx >= 32) return 0;
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_regfile__DOT__registers[reg_idx];
    }

    uint32_t read_memory_word(uint32_t byte_addr) {
        uint32_t word_idx = byte_addr / 4;
        return dut->rootp->chip_top__DOT__u_memory_subsystem__DOT__u_main_memory__DOT__memory[word_idx];
    }

    uint32_t get_pc_ex() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__id_ex_program_counter;
    }

    void do_reset() {
        dut->rst_n = 0;
        for (int i = 0; i < 10; i++) tick();
        dut->rst_n = 1;
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    ChipTopTestbench tb;

    // Machine Code Program
    std::vector<uint32_t> program = {
        0x00a00093, // ADDI x1, x0, 10
        0x01400113, // ADDI x2, x0, 20
        0x002081b3, // ADD x3, x1, x2
        0x000012b7, // LUI x5, 1
        0x0032a023, // SW x3, 0(x5)
        0x0002a203, // LW x4, 0(x5)
        0x00100073, // EBREAK
        0x00000013, // NOP
        0x00000013, // NOP
        0x00000013, // NOP
    };

    // Reset and load program
    tb.do_reset();
    tb.load_program(program);

    // Run until EBREAK (PC = 0x18 = 24)
    int cycles = 0;
    bool ebreak_reached = false;
    for (cycles = 0; cycles < 500; cycles++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (pc_ex == 24) { // EBREAK instruction address
            printf("[TB] EBREAK Executed at cycle %d\n", cycles);
            ebreak_reached = true;
            // Wait for pipeline to flush
            for (int i = 0; i < 10; i++) {
                tb.tick();
            }
            break;
        }
    }

    TB_ASSERT_EQ(ebreak_reached, true, "EBREAK should be reached");

    // Verify Register Values
    uint32_t x1 = tb.read_register(1);
    uint32_t x2 = tb.read_register(2);
    uint32_t x3 = tb.read_register(3);
    uint32_t x4 = tb.read_register(4);
    uint32_t x5 = tb.read_register(5);

    printf("[TB] x1=%u, x2=%u, x3=%u, x4=%u, x5=0x%x\n", x1, x2, x3, x4, x5);

    TB_ASSERT_EQ(x1, 10, "x1 should be 10");
    TB_ASSERT_EQ(x2, 20, "x2 should be 20");
    TB_ASSERT_EQ(x3, 30, "x3 should be 30");
    TB_ASSERT_EQ(x4, 30, "x4 should be 30");
    TB_ASSERT_EQ(x5, 0x1000, "x5 should be 0x1000");

    // Verify Memory Content
    uint32_t mem_val = tb.read_memory_word(0x1000);
    printf("[TB] Memory[0x1000] = %u\n", mem_val);
    TB_ASSERT_EQ(mem_val, 30, "Memory[0x1000] should be 30");

    TB_LOG("Test PASSED");
    return 0;
}
