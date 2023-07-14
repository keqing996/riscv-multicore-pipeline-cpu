#include "tb_base.h"
#include "Vforwarding_unit.h"
#include <string>

/**
 * Forwarding Unit Testbench
 * Tests data forwarding from MEM and WB stages to EX stage
 */
class ForwardingTestbench : public TestbenchBase<Vforwarding_unit> {
public:
    ForwardingTestbench() : TestbenchBase<Vforwarding_unit>(true, "forwarding_trace.vcd") {
        TB_LOG("Forwarding Unit Testbench initialized");
    }
    
    void check(uint8_t rs1_ex, uint8_t rs2_ex, uint8_t rd_mem, uint8_t we_mem,
               uint8_t rd_wb, uint8_t we_wb, uint8_t exp_a, uint8_t exp_b, const char* name) {
        dut->rs1_index_execute = rs1_ex;
        dut->rs2_index_execute = rs2_ex;
        dut->rd_index_memory = rd_mem;
        dut->register_write_enable_memory = we_mem;
        dut->rd_index_writeback = rd_wb;
        dut->register_write_enable_writeback = we_wb;
        eval();
        
        std::string prefix(name);
        TB_ASSERT_EQ(dut->forward_a_select, exp_a, (prefix + " forward_a").c_str());
        TB_ASSERT_EQ(dut->forward_b_select, exp_b, (prefix + " forward_b").c_str());
    }
    
    void test_no_forwarding() {
        TB_LOG("Test: No forwarding needed");
        check(1, 2, 3, 0, 4, 0, 0b00, 0b00, "No Forwarding");
    }
    
    void test_ex_hazard() {
        TB_LOG("Test: EX hazards (forward from MEM stage)");
        check(1, 2, 1, 1, 4, 0, 0b10, 0b00, "EX Hazard A");
        check(1, 2, 2, 1, 4, 0, 0b00, 0b10, "EX Hazard B");
        check(1, 1, 1, 1, 4, 0, 0b10, 0b10, "EX Hazard Both");
    }
    
    void test_mem_hazard() {
        TB_LOG("Test: MEM hazards (forward from WB stage)");
        check(1, 2, 3, 0, 1, 1, 0b01, 0b00, "MEM Hazard A");
        check(1, 2, 3, 0, 2, 1, 0b00, 0b01, "MEM Hazard B");
    }
    
    void test_priority() {
        TB_LOG("Test: EX hazard priority over MEM hazard");
        check(1, 2, 1, 1, 1, 1, 0b10, 0b00, "Priority A");
    }
    
    void test_x0_never_forward() {
        TB_LOG("Test: Never forward x0");
        check(0, 2, 0, 1, 4, 0, 0b00, 0b00, "x0 Forwarding A");
        check(1, 0, 0, 1, 4, 0, 0b00, 0b00, "x0 Forwarding B");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        ForwardingTestbench tb;
        
        tb.test_no_forwarding();
        tb.test_ex_hazard();
        tb.test_mem_hazard();
        tb.test_priority();
        tb.test_x0_never_forward();
        
        TB_LOG("All Forwarding Unit tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
