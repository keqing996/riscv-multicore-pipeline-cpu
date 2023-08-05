#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vmemory_subsystem.h"
#include <string>

class MemorySubsystemTestbench : public ClockedTestbench<Vmemory_subsystem> {
public:
    MemorySubsystemTestbench() : ClockedTestbench<Vmemory_subsystem>(100, false) {
        // Initialize inputs
        dut->icache_mem_req = 0;
        dut->icache_mem_addr = 0;
        dut->dcache_mem_req = 0;
        dut->dcache_mem_addr = 0;
        dut->dcache_mem_wdata = 0;
        dut->dcache_mem_be = 0;
        dut->dcache_mem_we = 0;
    }
    
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }
    
    void reset() {
        dut->rst_n = 0;
        tick();
        dut->rst_n = 1;
        
        // Wait for memory initialization
        for (int i = 0; i < 10; i++) {
            tick();
        }
    }
    
    void test_icache_read() {
        
        dut->icache_mem_addr = 0x0;
        dut->icache_mem_req = 1;
        
        // Wait for ready signal
        bool ready = false;
        for (int i = 0; i < 50; i++) {
            tick();
            if (dut->icache_mem_ready == 1) {
                ready = true;
                break;
            }
        }
        
        CHECK(ready == true);
        printf("[DEBUG] I-Cache read: addr=0x0, data=0x%08x\n", dut->icache_mem_rdata);
        
        dut->icache_mem_req = 0;
        tick();
    }
    
    void test_dcache_write() {
        
        dut->dcache_mem_addr = 0x1000;
        dut->dcache_mem_wdata = 0xDEADBEEF;
        dut->dcache_mem_be = 0b1111;
        dut->dcache_mem_we = 1;
        dut->dcache_mem_req = 1;
        
        // Wait for ready
        bool ready = false;
        for (int i = 0; i < 50; i++) {
            tick();
            if (dut->dcache_mem_ready == 1) {
                ready = true;
                break;
            }
        }
        
        CHECK(ready == true);
        
        dut->dcache_mem_req = 0;
        dut->dcache_mem_we = 0;
        tick();
    }
    
    void test_dcache_read() {
        
        dut->dcache_mem_addr = 0x1000;
        dut->dcache_mem_req = 1;
        dut->dcache_mem_we = 0;
        
        // Wait for ready
        bool ready = false;
        for (int i = 0; i < 50; i++) {
            tick();
            if (dut->dcache_mem_ready == 1) {
                ready = true;
                break;
            }
        }
        
        CHECK(ready == true);
        CHECK(dut->dcache_mem_rdata == 0xDEADBEEF);
        
        dut->dcache_mem_req = 0;
        tick();
    }
};

TEST_CASE("Memory Subsystem") {
MemorySubsystemTestbench tb;
        
        tb.reset();
        tb.test_icache_read();
        tb.test_dcache_write();
        tb.test_dcache_read();
}
