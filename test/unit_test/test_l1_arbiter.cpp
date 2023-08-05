#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vl1_arbiter.h"
#include <string>

class L1ArbiterTestbench : public ClockedTestbench<Vl1_arbiter> {
public:
    L1ArbiterTestbench() : ClockedTestbench<Vl1_arbiter>(100, false) {
        // Initialize inputs
        dut->icache_req = 0;
        dut->icache_addr = 0;
        dut->dcache_req = 0;
        dut->dcache_addr = 0;
        dut->dcache_wdata = 0;
        dut->dcache_we = 0;
        dut->dcache_be = 0;
        dut->m_ready = 0;
        dut->m_rdata = 0;
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
    
    void test_icache_request() {
        
        // I-Cache requests data
        dut->icache_addr = 0x1000;
        dut->icache_req = 1;
        dut->m_rdata = 0xDEADBEEF;
        tick();  // Enter STATE_ICACHE
        
        // Arbiter should forward request
        CHECK(dut->m_req == 1);
        CHECK(dut->m_addr == 0x1000);
        
        // Simulate memory ready (stay in STATE_ICACHE until ready)
        dut->m_ready = 1;
        eval();  // Combinational response
        
        // Check response
        CHECK(dut->icache_ready == 1);
        CHECK(dut->icache_rdata == 0xDEADBEEF);
        
        // Next cycle goes back to IDLE
        tick();
        
        // Release
        dut->icache_req = 0;
        dut->m_ready = 0;
        tick();
    }
    
    void test_dcache_priority() {
        
        // Both request simultaneously
        dut->dcache_addr = 0x2000;
        dut->dcache_req = 1;
        dut->dcache_we = 0;
        dut->icache_addr = 0x3000;
        dut->icache_req = 1;
        tick();  // Enter STATE_DCACHE (priority)
        
        // D-Cache should have priority
        CHECK(dut->m_addr == 0x2000);
        
        // Complete D-Cache request
        dut->m_ready = 1;
        dut->m_rdata = 0x11111111;
        eval();
        CHECK(dut->dcache_ready == 1);
        tick();  // Back to IDLE
        
        dut->dcache_req = 0;
        dut->m_ready = 0;
        tick();  // Enter STATE_ICACHE now
        
        // Now I-Cache should get access
        CHECK(dut->m_addr == 0x3000);
        
        // Cleanup
        dut->m_ready = 1;
        eval();
        tick();
        dut->icache_req = 0;
        dut->m_ready = 0;
        tick();
    }
    
    void test_dcache_write() {
        
        // D-Cache write
        dut->dcache_addr = 0x4000;
        dut->dcache_wdata = 0x12345678;
        dut->dcache_we = 1;
        dut->dcache_be = 0b1111;
        dut->dcache_req = 1;
        tick();  // Enter STATE_DCACHE
        
        // Check forwarding
        CHECK(dut->m_req == 1);
        CHECK(dut->m_addr == 0x4000);
        CHECK(dut->m_wdata == 0x12345678);
        CHECK(dut->m_we == 1);
        CHECK(dut->m_be == 0b1111);
        
        // Complete write
        dut->m_ready = 1;
        eval();
        CHECK(dut->dcache_ready == 1);
        
        // Back to IDLE
        tick();
        
        // Cleanup
        dut->dcache_req = 0;
        dut->dcache_we = 0;
        dut->m_ready = 0;
        tick();
    }
};

TEST_CASE("L1 Arbiter") {
L1ArbiterTestbench tb;
        
        tb.reset();
        tb.test_icache_request();
        tb.test_dcache_priority();
        tb.test_dcache_write();
}
