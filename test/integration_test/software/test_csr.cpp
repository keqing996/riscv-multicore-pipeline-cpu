#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
#include <cstdio>
#include <cstdlib>
#include <string>


TEST_CASE("Csr") {
ChipTopTestbench tb;
    
    // Load program binary
    tb.load_binary(PROGRAM_BIN_PATH);
    
    // Reset
    tb.reset();
    
    bool trap_handler_hit = false;
    bool ecall_return_hit = false;
    bool mcause_seen_correct = false;
    
    // Run for max 5000 cycles
    for (int i = 0; i < 5000; i++) {
        tb.tick();
        
        uint32_t s11 = tb.read_reg(27); // s11 used as trap handler marker
        uint32_t s4 = tb.read_reg(20);  // s4 used in main after return
        
        // Check if we entered trap handler
        if (s11 == 0xCAFEBABE && !trap_handler_hit) {
            printf("Cycle %d: Trap Handler Hit! (s11=0xCAFEBABE)\n", i);
            trap_handler_hit = true;
        }

        uint32_t s2 = tb.read_reg(18); // s2 (read from mcause)
        if (trap_handler_hit && s2 == 11 && !mcause_seen_correct) {
            uint32_t mcause = tb.get_mcause();
            printf("Cycle %d: MCAUSE is correct (s2=%u, mcause_reg=%u)\n", i, s2, mcause);
            mcause_seen_correct = true;
        }
        
        // Check if we returned from trap (s4 = 0x12345678)
        if (s4 == 0x12345678 && trap_handler_hit) {
            printf("Cycle %d: Returned from Trap! (s4=0x12345678)\n", i);
            ecall_return_hit = true;
            break;
        }
    }
    
    if (!trap_handler_hit) {
        fprintf(stderr, "FAIL: Did not enter trap handler\n");
        REQUIRE(trap_handler_hit == true);
    }
    
    if (!ecall_return_hit) {
        fprintf(stderr, "FAIL: Did not return from trap handler\n");
        REQUIRE(ecall_return_hit == true);
    }

    if (!mcause_seen_correct) {
        uint32_t s2 = tb.read_reg(18);
        uint32_t mcause = tb.get_mcause();
        fprintf(stderr, "FAIL: MCAUSE incorrect. Expected 11, got s2=%u, mcause_reg=%u\n", s2, mcause);
        REQUIRE(s2 == 11);
    }
    
    printf("PASS: CSR Exception Test Passed!\n");
}
