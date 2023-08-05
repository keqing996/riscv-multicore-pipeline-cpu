#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vbus_arbiter.h"
#include <string>

class BusArbiterTestbench : public ClockedTestbench<Vbus_arbiter> {
public:
    BusArbiterTestbench() : ClockedTestbench<Vbus_arbiter>(100, false) {
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
    }
    
    void test_m0_request() {
        
        // M0 requests write
        dut->m0_enable = 1;
        dut->m0_addr = 0x1000;
        dut->m0_wdata = 0xAAAA;
        dut->m0_write = 1;
        eval();
        
        CHECK(dut->bus_enable == 1);
        CHECK(dut->bus_addr == 0x1000);
        CHECK(dut->m0_ready == 0);
        
        // Bus responds
        dut->bus_ready = 1;
        eval();
        CHECK(dut->m0_ready == 1);
        
        // Complete transaction
        tick();
        dut->m0_enable = 0;
        dut->bus_ready = 0;
        tick();
    }
    
    void test_m1_request() {
        
        // M1 requests read
        dut->m1_enable = 1;
        dut->m1_addr = 0x2000;
        dut->m1_write = 0;
        eval();
        
        CHECK(dut->bus_enable == 1);
        CHECK(dut->bus_addr == 0x2000);
        
        // Bus responds with data
        dut->bus_ready = 1;
        dut->bus_rdata = 0x5555;
        eval();
        CHECK(dut->m1_ready == 1);
        CHECK(dut->m1_rdata == 0x5555);
        
        // Complete transaction
        tick();
        dut->m1_enable = 0;
        dut->bus_ready = 0;
        tick();
    }
    
    void test_concurrent_requests() {
        
        // Both M0 and M1 request simultaneously
        // After M1 access, priority should switch to M0
        dut->m0_enable = 1;
        dut->m0_addr = 0x3000;
        dut->m1_enable = 1;
        dut->m1_addr = 0x4000;
        eval();
        
        // M0 should be granted (priority after M1)
        CHECK(dut->bus_addr == 0x3000);
        
        // Complete M0 transaction
        dut->bus_ready = 1;
        tick();
        
        // M0 changes address, M1 still requesting
        dut->m0_addr = 0x3004;
        eval();
        
        // M1 should be granted now (round-robin)
        CHECK(dut->bus_addr == 0x4000);
        
        // Complete M1 transaction
        tick();
        eval();
        
        // M0 should be granted again
        CHECK(dut->bus_addr == 0x3004);
        
        // Cleanup
        dut->m0_enable = 0;
        dut->m1_enable = 0;
        dut->bus_ready = 0;
        tick();
    }
};

TEST_CASE("Bus Arbiter") {
BusArbiterTestbench tb;
        
        tb.reset();
        tb.test_m0_request();
        tb.test_m1_request();
        tb.test_concurrent_requests();
}
