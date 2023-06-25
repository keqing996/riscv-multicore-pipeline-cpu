#include "tb_base.h"
#include "Vl2_cache.h"
#include <string>

class L2CacheTestbench : public ClockedTestbench<Vl2_cache> {
public:
    L2CacheTestbench() : ClockedTestbench<Vl2_cache>(200, true, "l2_cache_trace.vcd") {
        // Initialize inputs
        dut->s_en = 0;
        dut->s_we = 0;
        dut->s_addr = 0;
        dut->s_wdata = 0;
        dut->s_be = 0;
        dut->mem_ready = 0;
        dut->mem_rdata = 0;
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
    
    void test_read_miss() {
        TB_LOG("Test: L2 read miss and refill");
        
        // Read request
        dut->s_addr = 0x1000;
        dut->s_we = 0;
        dut->s_en = 1;
        dut->s_be = 0b1111;
        tick();
        
        // Should not be ready (miss)
        TB_ASSERT_EQ(dut->s_ready, 0, "Should not be ready on miss");
        TB_ASSERT_EQ(dut->mem_req, 1, "Should request memory");
        
        // Simulate memory responses for cache line fill
        for (int i = 0; i < 4; i++) {
            dut->mem_rdata = 0x10000000 + (i << 8);
            dut->mem_ready = 1;
            tick();
            dut->mem_ready = 0;
        }
        
        // Wait for update
        tick();
        
        // Read hit now
        dut->s_addr = 0x1000;
        dut->s_en = 1;
        dut->s_we = 0;
        tick();
        
        TB_ASSERT_EQ(dut->s_ready, 1, "Should be ready on hit");
        TB_ASSERT_EQ(dut->s_rdata, 0x10000000, "Cached data");
        
        dut->s_en = 0;
        tick();
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        L2CacheTestbench tb;
        
        tb.reset();
        tb.test_read_miss();
        
        TB_LOG("All L2 Cache tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
