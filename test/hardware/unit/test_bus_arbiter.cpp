#include "tb_base.h"
#include "Vbus_arbiter.h"
#include <string>

class BusArbiterTestbench : public ClockedTestbench<Vbus_arbiter> {
public:
    BusArbiterTestbench() : ClockedTestbench<Vbus_arbiter>(100, true, "bus_arbiter_trace.vcd") {
        // Initialize inputs
        dut->m0_enable = 0;
        dut->m1_enable = 0;
        dut->bus_ready = 0;
        dut->m0_addr = 0;
        dut->m0_wdata = 0;
        dut->m0_write = 0;
        dut->m1_addr = 0;
        dut->m1_wdata = 0;
        dut->m1_write = 0;
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
    
    void test_m0_request() {
        TB_LOG("Test: M0 single request");
        
        // M0 requests write
        dut->m0_enable = 1;
        dut->m0_addr = 0x1000;
        dut->m0_wdata = 0xAAAA;
        dut->m0_write = 1;
        eval();
        
        TB_ASSERT_EQ(dut->bus_enable, 1, "M0 req: bus_enable");
        TB_ASSERT_EQ(dut->bus_addr, 0x1000, "M0 req: bus_addr");
        TB_ASSERT_EQ(dut->m0_ready, 0, "M0 req: m0_ready (bus not ready)");
        
        // Bus responds
        dut->bus_ready = 1;
        eval();
        TB_ASSERT_EQ(dut->m0_ready, 1, "M0 req: m0_ready (bus ready)");
        
        // Complete transaction
        tick();
        dut->m0_enable = 0;
        dut->bus_ready = 0;
        tick();
    }
    
    void test_m1_request() {
        TB_LOG("Test: M1 single request");
        
        // M1 requests read
        dut->m1_enable = 1;
        dut->m1_addr = 0x2000;
        dut->m1_write = 0;
        eval();
        
        TB_ASSERT_EQ(dut->bus_enable, 1, "M1 req: bus_enable");
        TB_ASSERT_EQ(dut->bus_addr, 0x2000, "M1 req: bus_addr");
        
        // Bus responds with data
        dut->bus_ready = 1;
        dut->bus_rdata = 0x5555;
        eval();
        TB_ASSERT_EQ(dut->m1_ready, 1, "M1 req: m1_ready");
        TB_ASSERT_EQ(dut->m1_rdata, 0x5555, "M1 req: m1_rdata");
        
        // Complete transaction
        tick();
        dut->m1_enable = 0;
        dut->bus_ready = 0;
        tick();
    }
    
    void test_concurrent_requests() {
        TB_LOG("Test: Concurrent requests (round-robin)");
        
        // Both M0 and M1 request simultaneously
        // After M1 access, priority should switch to M0
        dut->m0_enable = 1;
        dut->m0_addr = 0x3000;
        dut->m1_enable = 1;
        dut->m1_addr = 0x4000;
        eval();
        
        // M0 should be granted (priority after M1)
        TB_ASSERT_EQ(dut->bus_addr, 0x3000, "Concurrent: M0 granted first");
        
        // Complete M0 transaction
        dut->bus_ready = 1;
        tick();
        
        // M0 changes address, M1 still requesting
        dut->m0_addr = 0x3004;
        eval();
        
        // M1 should be granted now (round-robin)
        TB_ASSERT_EQ(dut->bus_addr, 0x4000, "Concurrent: M1 granted second");
        
        // Complete M1 transaction
        tick();
        eval();
        
        // M0 should be granted again
        TB_ASSERT_EQ(dut->bus_addr, 0x3004, "Concurrent: M0 granted third");
        
        // Cleanup
        dut->m0_enable = 0;
        dut->m1_enable = 0;
        dut->bus_ready = 0;
        tick();
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        BusArbiterTestbench tb;
        
        tb.reset();
        tb.test_m0_request();
        tb.test_m1_request();
        tb.test_concurrent_requests();
        
        TB_LOG("All Bus Arbiter tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
