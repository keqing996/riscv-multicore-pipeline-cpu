#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vregfile.h"
#include <iostream>

/**
 * Register File Testbench
 */
class RegfileTestbench : public ClockedTestbench<Vregfile> {
public:
    RegfileTestbench() : ClockedTestbench<Vregfile>(100, false) {
        // Initialize inputs
        dut->write_enable = 0;
        dut->rs1_index = 0;
        dut->rs2_index = 0;
        dut->rd_index = 0;
        dut->write_data = 0;
        
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
        
        // Write to x1
        write_reg(1, 0x12345678);
        uint32_t val = read_rs1(1);
        CHECK(val == 0x12345678);
        
        // Write to x31
        write_reg(31, 0xDEADBEEF);
        val = read_rs2(31);
        CHECK(val == 0xDEADBEEF);
        
    }
    
    // Test x0 is always zero
    void test_x0_zero() {
        
        // Try to write to x0 (should be ignored)
        write_reg(0, 0xFFFFFFFF);
        uint32_t val = read_rs1(0);
        CHECK(val == 0);
        
    }
    
    // Test all registers
    void test_all_registers() {
        
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
        
    }
    
    // Test simultaneous read from two ports
    void test_dual_read() {
        
        write_reg(5, 0x11111111);
        write_reg(10, 0x22222222);
        
        dut->rs1_index = 5;
        dut->rs2_index = 10;
        eval();
        
        CHECK(dut->rs1_read_data == 0x11111111);
        CHECK(dut->rs2_read_data == 0x22222222);
        
    }
};

TEST_CASE("Regfile") {
RegfileTestbench tb;
        
        // Give some initial clocks for initialization
        tb.tick(5);
        
        tb.test_x0_zero();
        tb.test_basic_rw();
        tb.test_dual_read();
        tb.test_all_registers();
}
