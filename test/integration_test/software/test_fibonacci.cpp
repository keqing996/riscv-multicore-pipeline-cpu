#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "program_loader.h"
#include <Vchip_top.h>
#include <Vchip_top___024root.h>
#include <cstdio>
#include <cstdlib>
#include <string>

class FibonacciTestbench : public ClockedTestbench<Vchip_top> {
public:
    FibonacciTestbench() : ClockedTestbench<Vchip_top>(100, false, "dump.vcd") {  // Disable tracing
        dut->rst_n = 0;
    }

    void set_clk(uint8_t value) override { 
        dut->clk = value; 
    }
    
    void load_program(const std::string& bin_path) {
        auto program = ProgramLoader::load_binary(bin_path);
        
        for (size_t i = 0; i < program.size(); i++) {
            dut->rootp->chip_top__DOT__u_memory_subsystem__DOT__u_main_memory__DOT__memory[i] = program[i];
        }
        
        printf("Loaded %zu instructions into memory\n", program.size());
    }
    
    uint32_t read_reg(int idx) {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_regfile__DOT__registers[idx];
    }
    
    uint32_t get_pc() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__id_ex_program_counter;
    }
    
    uint32_t get_instruction() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__if_id_instruction;
    }
    
    bool is_ebreak() {
        return (get_instruction() & 0xFFFFFFFF) == 0x00100073;
    }
    
    void do_reset() {
        dut->rst_n = 0;
        for (int i = 0; i < 20; i++) tick();
        dut->rst_n = 1;
        for (int i = 0; i < 5; i++) tick();
    }
};

TEST_CASE("Fibonacci") {
FibonacciTestbench tb;
    
    // Load program binary
    tb.load_program(PROGRAM_BIN_PATH);
    
    // Reset
    tb.do_reset();
    
    // Run until EBREAK (max 200k cycles)
    bool found_ebreak = false;
    int ebreak_count = 0;
    for (int i = 0; i < 200000; i++) {
        tb.tick();
        
        if (tb.is_ebreak()) {
            ebreak_count++;
            if (ebreak_count == 1) {  // First EBREAK
                uint32_t pc = tb.get_pc();
                uint32_t result = tb.read_reg(10); // x10/a0
                
                fprintf(stderr, "\nCycle %d: EBREAK at PC=0x%x, x10=%u\n", i, pc, result);
                
                if (result != 55) {
                    fprintf(stderr, "FAIL: Expected x10=55, got %u\n", result);
                    REQUIRE(result == 55);
                }
                
                fprintf(stderr, "PASS: Fibonacci result = %u\n", result);
                found_ebreak = true;
                break;
            }
        }
    }
    
    if (!found_ebreak) {
        fprintf(stderr, "\n\nFAIL: Timeout waiting for EBREAK\n");
        REQUIRE(found_ebreak == true);
    }
}
