#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vl1_data_cache.h"
#include <string>

class L1DataCacheTestbench : public ClockedTestbench<Vl1_data_cache> {
public:
    L1DataCacheTestbench() : ClockedTestbench<Vl1_data_cache>(100, false) {
        // Initialize inputs
        dut->cpu_read_enable = 0;
        dut->cpu_write_enable = 0;
        dut->cpu_address = 0;
        dut->cpu_write_data = 0;
        dut->cpu_byte_enable = 0;
        dut->mem_ready = 0;
        dut->mem_read_data = 0;
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
        
        // Read from address
        dut->cpu_address = 0x2000;
        dut->cpu_read_enable = 1;
        tick();
        
        // Should stall and request memory
        CHECK(dut->stall_cpu == 1);
        CHECK(dut->mem_request == 1);
        
        // Simulate memory responses for 4-word cache line
        for (int i = 0; i < 4; i++) {
            dut->mem_read_data = 0xAABBCC00 + i;
            dut->mem_ready = 1;
            tick();
            dut->mem_ready = 0;
        }
        
        // Wait for update and access done
        tick();
        tick();
        
        // Read hit now
        dut->cpu_address = 0x2000;
        dut->cpu_read_enable = 1;
        tick();
        
        CHECK(dut->stall_cpu == 0);
        CHECK(dut->cpu_read_data == 0xAABBCC00);
        
        dut->cpu_read_enable = 0;
        tick();
    }
    
    void test_write_through() {
        
        // Write to cache
        dut->cpu_address = 0x2004;
        dut->cpu_write_data = 0x12345678;
        dut->cpu_byte_enable = 0b1111;
        dut->cpu_write_enable = 1;
        tick();
        
        // Should stall and write to memory
        CHECK(dut->stall_cpu == 1);
        CHECK(dut->mem_request == 1);
        CHECK(dut->mem_write_enable == 1);
        
        // Complete write
        dut->mem_ready = 1;
        tick();
        dut->mem_ready = 0;
        dut->cpu_write_enable = 0;
        tick();
    }
};

TEST_CASE("L1 Data Cache") {
L1DataCacheTestbench tb;
        
        tb.reset();
        tb.test_read_miss();
        tb.test_write_through();
}
