#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "program_loader.h"
#include <Vchip_top.h>
#include <Vchip_top___024root.h>
#include <cstdio>
#include <cstdlib>
#include <string>

class CsrTestbench : public ClockedTestbench<Vchip_top> {
public:
    CsrTestbench() : ClockedTestbench<Vchip_top>(100, true, "dump.vcd") {
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
    
    uint32_t get_mcause() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mcause;
    }
    
    uint32_t get_mepc() {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mepc;
    }
    
    bool is_ecall() {
        return (get_instruction() & 0xFFFFFFFF) == 0x00000073;
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

TEST_CASE("Csr") {
CsrTestbench tb;
    
    // Load program binary
    tb.load_program(PROGRAM_BIN_PATH);
    
    // Reset
    tb.do_reset();
    
    bool trap_handler_hit = false;
    bool ecall_return_hit = false;
    
    // Run for max 5000 cycles
    for (int i = 0; i < 5000; i++) {
        tb.tick();
        
        uint32_t s11 = tb.read_reg(27); // s11 used as trap handler marker
        uint32_t s4 = tb.read_reg(20);  // s4 used in main after return
        
        // Check if we entered trap handler
        if (s11 == 0xCAFEBABE && !trap_handler_hit) {
            printf("Cycle %d: Trap Handler Hit! (s11=0xCAFEBABE)
", i);
            trap_handler_hit = true;
            
            uint32_t s2 = tb.read_reg(18); // s2 (read from mcause)
            uint32_t mcause = tb.get_mcause();
            
            printf("Cycle %d: s2 (from mcause) = %u, mcause_reg = %u
", i, s2, mcause);
            
            if (s2 == 11) {
                printf("Cycle %d: MCAUSE is correct (11 = ECALL)
", i);
            } else {
                fprintf(stderr, "FAIL: MCAUSE incorrect. Expected 11, got %u
", s2);
                return 1;
            }
        }
        
        // Check if we returned from trap (s4 = 0x12345678)
        if (s4 == 0x12345678 && trap_handler_hit) {
            printf("Cycle %d: Returned from Trap! (s4=0x12345678)
", i);
            ecall_return_hit = true;
            break;
        }
    }
    
    if (!trap_handler_hit) {
        fprintf(stderr, "FAIL: Did not enter trap handler
");
        return 1;
    }
    
    if (!ecall_return_hit) {
        fprintf(stderr, "FAIL: Did not return from trap handler
");
        return 1;
    }
    
    printf("PASS: CSR Exception Test Passed!
");
}
