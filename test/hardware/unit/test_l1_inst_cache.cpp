#include "tb_base.h"
#include "Vl1_inst_cache.h"
#include <string>

class L1InstCacheTestbench : public ClockedTestbench<Vl1_inst_cache> {
public:
    L1InstCacheTestbench() : ClockedTestbench<Vl1_inst_cache>(100, true, "l1_inst_cache_trace.vcd") {
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
        TB_LOG("Reset complete");
    }
    
    void test_cold_miss() {
        TB_LOG("Test: Cold miss and refill");
        
        // Request address (cache line aligned)
        dut->program_counter_address = 0x1000;
        tick();
        
        // Should miss and stall
        TB_ASSERT_EQ(dut->stall_cpu, 1, "Should stall on miss");
        TB_ASSERT_EQ(dut->instruction_memory_request, 1, "Should request memory");
        
        // Simulate memory responses for 4-word cache line
        for (int i = 0; i < 4; i++) {
            TB_ASSERT_EQ(dut->instruction_memory_address, 0x1000 + (i * 4), 
                        (std::string("Memory addr ") + std::to_string(i)).c_str());
            
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
        
        TB_ASSERT_EQ(dut->stall_cpu, 0, "Should not stall on hit");
        TB_ASSERT_EQ(dut->instruction, 0x00000013, "Should return cached instruction");
    }
    
    void test_sequential_hits() {
        TB_LOG("Test: Sequential hits within same cache line");
        
        // Hit on word 1 (offset 4)
        dut->program_counter_address = 0x1004;
        tick();
        TB_ASSERT_EQ(dut->stall_cpu, 0, "Hit: no stall");
        TB_ASSERT_EQ(dut->instruction, 0x00000014, "Word 1");
        
        // Hit on word 2 (offset 8)
        dut->program_counter_address = 0x1008;
        tick();
        TB_ASSERT_EQ(dut->stall_cpu, 0, "Hit: no stall");
        TB_ASSERT_EQ(dut->instruction, 0x00000015, "Word 2");
        
        // Hit on word 3 (offset 12)
        dut->program_counter_address = 0x100C;
        tick();
        TB_ASSERT_EQ(dut->stall_cpu, 0, "Hit: no stall");
        TB_ASSERT_EQ(dut->instruction, 0x00000016, "Word 3");
    }
    
    void test_different_line() {
        TB_LOG("Test: Different cache line (miss)");
        
        // Request different line
        dut->program_counter_address = 0x2000;
        tick();
        
        // Should miss
        TB_ASSERT_EQ(dut->stall_cpu, 1, "Should stall on miss");
        TB_ASSERT_EQ(dut->instruction_memory_request, 1, "Should request");
        
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
        TB_ASSERT_EQ(dut->stall_cpu, 0, "Hit after refill");
        TB_ASSERT_EQ(dut->instruction, 0xAAAA0000, "New line data");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        L1InstCacheTestbench tb;
        
        tb.reset();
        tb.test_cold_miss();
        tb.test_sequential_hits();
        tb.test_different_line();
        
        TB_LOG("All L1 Inst Cache tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
