#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vl1_inst_cache.h"
#include <string>

class L1InstCacheTestbench : public ClockedTestbench<Vl1_inst_cache> {
public:
    L1InstCacheTestbench() : ClockedTestbench<Vl1_inst_cache>(100, false) {
        // Initialize inputs
        dut->program_counter_address = 0;
        dut->instruction_memory_read_data = 0;
        dut->instruction_memory_ready = 0;
    }
    
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }
    
    void reset() {
        dut->rst_n = 0;
        tick();
        dut->rst_n = 1;
        tick();
    }
    
    void test_cold_miss() {
        
        // Request address (cache line aligned)
        dut->program_counter_address = 0x1000;
        tick();
        
        // Should miss and stall
        CHECK(dut->stall_cpu == 1);
        CHECK(dut->instruction_memory_request == 1);
        
        // Simulate memory responses for 4-word cache line
        for (int i = 0; i < 4; i++) {
            INFO((std::string("Memory addr ") + std::to_string(i)).c_str());
            CHECK(dut->instruction_memory_address == (0x1000 + (i * 4)));
            
            dut->instruction_memory_read_data = 0x00000013 + i;  // NOP variants
            dut->instruction_memory_ready = 1;
            tick();
            dut->instruction_memory_ready = 0;
        }
        
        // Wait for cache to update
        tick();
        
        // Now should hit
        dut->program_counter_address = 0x1000;
        tick();
        
        CHECK(dut->stall_cpu == 0);
        CHECK(dut->instruction == 0x00000013);
    }
    
    void test_sequential_hits() {
        
        // Hit on word 1 (offset 4)
        dut->program_counter_address = 0x1004;
        tick();
        CHECK(dut->stall_cpu == 0);
        CHECK(dut->instruction == 0x00000014);
        
        // Hit on word 2 (offset 8)
        dut->program_counter_address = 0x1008;
        tick();
        CHECK(dut->stall_cpu == 0);
        CHECK(dut->instruction == 0x00000015);
        
        // Hit on word 3 (offset 12)
        dut->program_counter_address = 0x100C;
        tick();
        CHECK(dut->stall_cpu == 0);
        CHECK(dut->instruction == 0x00000016);
    }
    
    void test_different_line() {
        
        // Request different line
        dut->program_counter_address = 0x2000;
        tick();
        
        // Should miss
        CHECK(dut->stall_cpu == 1);
        CHECK(dut->instruction_memory_request == 1);
        
        // Refill
        for (int i = 0; i < 4; i++) {
            dut->instruction_memory_read_data = 0xAAAA0000 + i;
            dut->instruction_memory_ready = 1;
            tick();
            dut->instruction_memory_ready = 0;
        }
        
        tick();
        
        // Hit
        dut->program_counter_address = 0x2000;
        tick();
        CHECK(dut->stall_cpu == 0);
        CHECK(dut->instruction == 0xAAAA0000);
    }
};

TEST_CASE("L1 Inst Cache") {
L1InstCacheTestbench tb;
        
        tb.reset();
        tb.test_cold_miss();
        tb.test_sequential_hits();
        tb.test_different_line();
}
