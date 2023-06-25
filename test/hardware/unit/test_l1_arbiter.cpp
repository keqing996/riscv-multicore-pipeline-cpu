#include "tb_base.h"
#include "Vl1_arbiter.h"
#include <string>

class L1ArbiterTestbench : public ClockedTestbench<Vl1_arbiter> {
public:
    L1ArbiterTestbench() : ClockedTestbench<Vl1_arbiter>(100, true, "l1_arbiter_trace.vcd") {
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
        TB_LOG("Reset complete");
    }
    
    void test_icache_request() {
        TB_LOG("Test: I-Cache request");
        
        // I-Cache requests data
        dut->icache_addr = 0x1000;
        dut->icache_req = 1;
        dut->m_rdata = 0xDEADBEEF;
        tick();  // Enter STATE_ICACHE
        
        // Arbiter should forward request
        TB_ASSERT_EQ(dut->m_req, 1, "m_req should be high");
        TB_ASSERT_EQ(dut->m_addr, 0x1000, "Address forwarded");
        
        // Simulate memory ready (stay in STATE_ICACHE until ready)
        dut->m_ready = 1;
        eval();  // Combinational response
        
        // Check response
        TB_ASSERT_EQ(dut->icache_ready, 1, "icache_ready high");
        TB_ASSERT_EQ(dut->icache_rdata, 0xDEADBEEF, "Data forwarded");
        
        // Next cycle goes back to IDLE
        tick();
        
        // Release
        dut->icache_req = 0;
        dut->m_ready = 0;
        tick();
    }
    
    void test_dcache_priority() {
        TB_LOG("Test: D-Cache priority over I-Cache");
        
        // Both request simultaneously
        dut->dcache_addr = 0x2000;
        dut->dcache_req = 1;
        dut->dcache_we = 0;
        dut->icache_addr = 0x3000;
        dut->icache_req = 1;
        tick();  // Enter STATE_DCACHE (priority)
        
        // D-Cache should have priority
        TB_ASSERT_EQ(dut->m_addr, 0x2000, "D-Cache has priority");
        
        // Complete D-Cache request
        dut->m_ready = 1;
        dut->m_rdata = 0x11111111;
        eval();
        TB_ASSERT_EQ(dut->dcache_ready, 1, "dcache_ready");
        tick();  // Back to IDLE
        
        dut->dcache_req = 0;
        dut->m_ready = 0;
        tick();  // Enter STATE_ICACHE now
        
        // Now I-Cache should get access
        TB_ASSERT_EQ(dut->m_addr, 0x3000, "I-Cache gets access");
        
        // Cleanup
        dut->m_ready = 1;
        eval();
        tick();
        dut->icache_req = 0;
        dut->m_ready = 0;
        tick();
    }
    
    void test_dcache_write() {
        TB_LOG("Test: D-Cache write request");
        
        // D-Cache write
        dut->dcache_addr = 0x4000;
        dut->dcache_wdata = 0x12345678;
        dut->dcache_we = 1;
        dut->dcache_be = 0b1111;
        dut->dcache_req = 1;
        tick();  // Enter STATE_DCACHE
        
        // Check forwarding
        TB_ASSERT_EQ(dut->m_req, 1, "m_req for write");
        TB_ASSERT_EQ(dut->m_addr, 0x4000, "Write address");
        TB_ASSERT_EQ(dut->m_wdata, 0x12345678, "Write data");
        TB_ASSERT_EQ(dut->m_we, 1, "Write enable");
        TB_ASSERT_EQ(dut->m_be, 0b1111, "Byte enable");
        
        // Complete write
        dut->m_ready = 1;
        eval();
        TB_ASSERT_EQ(dut->dcache_ready, 1, "dcache_ready");
        
        // Back to IDLE
        tick();
        
        // Cleanup
        dut->dcache_req = 0;
        dut->dcache_we = 0;
        dut->m_ready = 0;
        tick();
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        L1ArbiterTestbench tb;
        
        tb.reset();
        tb.test_icache_request();
        tb.test_dcache_priority();
        tb.test_dcache_write();
        
        TB_LOG("All L1 Arbiter tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
