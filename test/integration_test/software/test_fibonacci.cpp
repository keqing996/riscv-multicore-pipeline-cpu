#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
#include <cstdio>
#include <cstdlib>
#include <string>


TEST_CASE("Fibonacci") {
ChipTopTestbench tb;
    
    // Load program binary
    tb.load_binary(PROGRAM_BIN_PATH);
    
    // Reset
    tb.reset();
    
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
