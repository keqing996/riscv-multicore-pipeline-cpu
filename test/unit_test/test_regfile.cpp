#include "tb_base.h"
#include "Vregfile.h"
#include <iostream>

/**
 * Register File Testbench
 */
class RegfileTestbench : public ClockedTestbench<Vregfile> {
public:
    RegfileTestbench() : ClockedTestbench<Vregfile>(100, true, "regfile_trace.vcd") {
        // Initialize inputs
        dut->write_enable = 0;
        dut->rs1_index = 0;
        dut->rs2_index = 0;
        dut->rd_index = 0;
        dut->write_data = 0;
        
        TB_LOG("Regfile Testbench initialized");
    }
    
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }
    
    // Write to register
    void write_reg(uint8_t rd, uint32_t data) {
        dut->rd_index = rd;
        dut->write_data = data;
        dut->write_enable = 1;
        tick();
        dut->write_enable = 0;
    }
    
    // Read from register (rs1)
    uint32_t read_rs1(uint8_t rs) {
        dut->rs1_index = rs;
        eval();
        return dut->rs1_read_data;
    }
    
    // Read from register (rs2)
    uint32_t read_rs2(uint8_t rs) {
        dut->rs2_index = rs;
        eval();
        return dut->rs2_read_data;
    }
    
    // Test basic read/write
    void test_basic_rw() {
        TB_LOG("Test: Basic read/write");
        
        // Write to x1
        write_reg(1, 0x12345678);
        uint32_t val = read_rs1(1);
        TB_ASSERT_EQ(val, 0x12345678, "x1 write/read failed");
        
        // Write to x31
        write_reg(31, 0xDEADBEEF);
        val = read_rs2(31);
        TB_ASSERT_EQ(val, 0xDEADBEEF, "x31 write/read failed");
        
        TB_LOG("Basic read/write PASSED");
    }
    
    // Test x0 is always zero
    void test_x0_zero() {
        TB_LOG("Test: x0 hardwired to zero");
        
        // Try to write to x0 (should be ignored)
        write_reg(0, 0xFFFFFFFF);
        uint32_t val = read_rs1(0);
        TB_ASSERT_EQ(val, 0, "x0 should always be 0");
        
        TB_LOG("x0 zero test PASSED");
    }
    
    // Test all registers
    void test_all_registers() {
        TB_LOG("Test: All 32 registers");
        
        // Write unique pattern to each register (except x0)
        for (int i = 1; i < 32; i++) {
            uint32_t pattern = 0xA0000000 | (i << 16) | i;
            write_reg(i, pattern);
        }
        
        // Read back and verify
        for (int i = 1; i < 32; i++) {
            uint32_t expected = 0xA0000000 | (i << 16) | i;
            uint32_t val = read_rs1(i);
            
            if (val != expected) {
                std::cerr << "Register x" << i << " mismatch: got 0x" 
                          << std::hex << val << ", expected 0x" << expected 
                          << std::dec << std::endl;
                throw std::runtime_error("Register test failed");
            }
        }
        
        TB_LOG("All registers test PASSED");
    }
    
    // Test simultaneous read from two ports
    void test_dual_read() {
        TB_LOG("Test: Dual port read");
        
        write_reg(5, 0x11111111);
        write_reg(10, 0x22222222);
        
        dut->rs1_index = 5;
        dut->rs2_index = 10;
        eval();
        
        TB_ASSERT_EQ(dut->rs1_read_data, 0x11111111, "rs1 read failed");
        TB_ASSERT_EQ(dut->rs2_read_data, 0x22222222, "rs2 read failed");
        
        TB_LOG("Dual port read PASSED");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        RegfileTestbench tb;
        
        // Give some initial clocks for initialization
        tb.tick(5);
        
        tb.test_x0_zero();
        tb.test_basic_rw();
        tb.test_dual_read();
        tb.test_all_registers();
        
        TB_LOG("==================================");
        TB_LOG("All Regfile tests PASSED!");
        TB_LOG("==================================");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
