#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
// Test: Basic Operations Integration Test
// Runs a simple assembly program on the full chip:
// - ADDI x1, x0, 10  (x1 = 10)
// - ADDI x2, x0, 20  (x2 = 20)
// - ADD x3, x1, x2   (x3 = 30)
// - LUI x5, 1        (x5 = 0x1000)
// - SW x3, 0(x5)     (Mem[0x1000] = 30)
// - LW x4, 0(x5)     (x4 = 30)
// - EBREAK           (Stop)

#include <Vchip_top.h>
#include <Vchip_top___024root.h>  // For internal signals

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

    uint32_t get_pc_if() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__program_counter_current;
    }

    uint8_t get_icache_state() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_icache__DOT__state;
    }

    bool get_icache_stall() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__icache_stall;
    }

    bool get_instruction_grant() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__instruction_grant_reg;
    }
    
    uint32_t get_pc_id() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__if_id_program_counter;
    }
    
    uint32_t get_instruction_id() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__if_id_instruction;
    }
    
    bool get_stall_backend() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__stall_pipeline;
    }
    
    bool get_flush_branch() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__flush_due_to_branch;
    }
    
    bool get_flush_jump() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__flush_due_to_jump;
    }
    
    bool get_flush_trap() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__flush_due_to_trap;
    }
    
    uint32_t get_icache_instruction() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__instruction;
    }
    
    bool get_stall_global() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__stall_global;
    }

    void do_reset() {
        dut->rst_n = 0;
        for (int i = 0; i < 20; i++) tick();  // More reset cycles
        dut->rst_n = 1;
        for (int i = 0; i < 5; i++) tick();   // Wait a bit after reset release
    }
};

TEST_CASE("Basic Ops") {
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
    tb.load_program(program);  // Load before reset
    tb.do_reset();

    // Run until EBREAK (PC = 0x18 = 24)
    int cycles = 0;
    bool ebreak_reached = false;
    for (cycles = 0; cycles < 5000; cycles++) {  // Increased from 500
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        uint32_t pc_if = tb.get_pc_if();
        uint32_t pc_id = tb.get_pc_id();
        uint32_t inst_id = tb.get_instruction_id();
        uint8_t icache_state = tb.get_icache_state();
        bool icache_stall = tb.get_icache_stall();
        bool inst_grant = tb.get_instruction_grant();
        bool stall_back = tb.get_stall_backend();
        bool flush_br = tb.get_flush_branch();
        bool flush_jp = tb.get_flush_jump();
        bool flush_tr = tb.get_flush_trap();
        uint32_t icache_inst = tb.get_icache_instruction();
        bool stall_glob = tb.get_stall_global();
        
        if (cycles < 30 || cycles % 100 == 0) {  // More debug output
            printf("[DEBUG] Cycle %d: PC_IF=0x%x PC_ID=0x%x(0x%x) PC_EX=0x%x grant=%d stall_g=%d icache_inst=0x%x\n", 
                   cycles, pc_if, pc_id, inst_id, pc_ex, inst_grant, stall_glob, icache_inst);
        }
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

    CHECK(ebreak_reached == true);

    // Verify Register Values
    uint32_t x1 = tb.read_register(1);
    uint32_t x2 = tb.read_register(2);
    uint32_t x3 = tb.read_register(3);
    uint32_t x4 = tb.read_register(4);
    uint32_t x5 = tb.read_register(5);

    printf("[TB] x1=%u, x2=%u, x3=%u, x4=%u, x5=0x%x\n", x1, x2, x3, x4, x5);

    CHECK(x1 == 10);
    CHECK(x2 == 20);
    CHECK(x3 == 30);
    CHECK(x4 == 30);
    CHECK(x5 == 0x1000);

    // Verify Memory Content
    uint32_t mem_val = tb.read_memory_word(0x1000);
    printf("[TB] Memory[0x1000] = %u\n", mem_val);
    CHECK(mem_val == 30);
}
