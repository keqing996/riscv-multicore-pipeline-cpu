#include "tb_base.h"
#include "Vmemory_subsystem.h"
#include <string>

class MemorySubsystemTestbench : public ClockedTestbench<Vmemory_subsystem> {
public:
    MemorySubsystemTestbench() : ClockedTestbench<Vmemory_subsystem>(200, true, "memory_subsystem_trace.vcd") {
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
        TB_LOG("Reset complete");
    }
    
    void test_icache_read() {
        TB_LOG("Test: I-Cache read");
        
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
        
        TB_ASSERT_EQ(ready, true, "I-Cache read should complete");
        printf("[DEBUG] I-Cache read: addr=0x0, data=0x%08x\n", dut->icache_mem_rdata);
        
        dut->icache_mem_req = 0;
        tick();
    }
    
    void test_dcache_write() {
        TB_LOG("Test: D-Cache write");
        
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
        
        TB_ASSERT_EQ(ready, true, "D-Cache write should complete");
        
        dut->dcache_mem_req = 0;
        dut->dcache_mem_we = 0;
        tick();
    }
    
    void test_dcache_read() {
        TB_LOG("Test: D-Cache read back");
        
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
        
        TB_ASSERT_EQ(ready, true, "D-Cache read should complete");
        TB_ASSERT_EQ(dut->dcache_mem_rdata, 0xDEADBEEF, "Read data matches write");
        
        dut->dcache_mem_req = 0;
        tick();
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        MemorySubsystemTestbench tb;
        
        tb.reset();
        tb.test_icache_read();
        tb.test_dcache_write();
        tb.test_dcache_read();
        
        TB_LOG("All Memory Subsystem tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
