#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: Basic Operations Integration Test
// Runs a simple assembly program on the full chip:
// - ADDI x1, x0, 10  (x1 = 10)
// - ADDI x2, x0, 20  (x2 = 20)
// - ADD x3, x1, x2   (x3 = 30)
// - LUI x5, 1        (x5 = 0x1000)
// - SW x3, 0(x5)     (Mem[0x1000] = 30)
// - LW x4, 0(x5)     (x4 = 30)
// - EBREAK           (Stop)



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
    tb.reset();

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
        if (tb.is_halted()) { // EBREAK instruction address
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
