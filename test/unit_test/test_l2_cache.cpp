#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vl2_cache.h"
#include <string>

class L2CacheTestbench : public ClockedTestbench<Vl2_cache> {
public:
    L2CacheTestbench() : ClockedTestbench<Vl2_cache>(100, false) {
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
    }
    
    void test_read_miss() {
        
        // Read request
        dut->s_addr = 0x1000;
        dut->s_we = 0;
        dut->s_en = 1;
        dut->s_be = 0b1111;
        tick();
        
        // Should not be ready (miss)
        CHECK(dut->s_ready == 0);
        CHECK(dut->mem_req == 1);
        
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
        
        CHECK(dut->s_ready == 1);
        CHECK(dut->s_rdata == 0x10000000);
        
        dut->s_en = 0;
        tick();
    }
};

TEST_CASE("L2 Cache") {
L2CacheTestbench tb;
        
        tb.reset();
        tb.test_read_miss();
}
