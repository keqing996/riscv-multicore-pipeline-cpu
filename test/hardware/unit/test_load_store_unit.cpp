#include "tb_base.h"
#include "Vload_store_unit.h"
#include <string>

/**
 * Load Store Unit Testbench
 * Tests byte/halfword/word load/store operations with proper alignment
 */
class LoadStoreTestbench : public TestbenchBase<Vload_store_unit> {
public:
    LoadStoreTestbench() : TestbenchBase<Vload_store_unit>(true, "load_store_trace.vcd") {
        dut->memory_write_enable = 0;
        dut->memory_read_enable = 0;
        TB_LOG("Load Store Unit Testbench initialized");
    }
    
    void check_store(uint32_t addr, uint32_t wdata, uint8_t funct3, 
                     uint32_t exp_wdata, uint8_t exp_be, const char* name) {
        dut->address = addr;
        dut->write_data_in = wdata;
        dut->function_3 = funct3;
        dut->memory_write_enable = 1;
        dut->memory_read_enable = 0;
        eval();
        
        std::string prefix(name);
        TB_ASSERT_EQ(dut->bus_write_data, exp_wdata, (prefix + " bus_write_data").c_str());
        TB_ASSERT_EQ(dut->bus_byte_enable, exp_be, (prefix + " bus_byte_enable").c_str());
        TB_ASSERT_EQ(dut->bus_write_enable, 1, (prefix + " bus_write_enable").c_str());
        TB_ASSERT_EQ(dut->bus_address, addr, (prefix + " bus_address").c_str());
    }
    
    void check_load(uint32_t addr, uint32_t rdata, uint8_t funct3, 
                    int32_t exp_rdata, const char* name) {
        dut->address = addr;
        dut->bus_read_data = rdata;
        dut->function_3 = funct3;
        dut->memory_write_enable = 0;
        dut->memory_read_enable = 1;
        eval();
        
        int32_t got = static_cast<int32_t>(dut->memory_read_data_final);
        TB_ASSERT_EQ(got, exp_rdata, name);
    }
    
    void test_store_word() {
        TB_LOG("Test: Store Word (SW)");
        check_store(0x100, 0xAABBCCDD, 0b010, 0xAABBCCDD, 0b1111, "SW Aligned");
    }
    
    void test_store_byte() {
        TB_LOG("Test: Store Byte (SB)");
        check_store(0x100, 0xDD, 0b000, 0xDDDDDDDD, 0b0001, "SB Offset 0");
        check_store(0x101, 0xCC, 0b000, 0xCCCCCCCC, 0b0010, "SB Offset 1");
        check_store(0x102, 0xBB, 0b000, 0xBBBBBBBB, 0b0100, "SB Offset 2");
        check_store(0x103, 0xAA, 0b000, 0xAAAAAAAA, 0b1000, "SB Offset 3");
    }
    
    void test_store_halfword() {
        TB_LOG("Test: Store Halfword (SH)");
        check_store(0x100, 0xBBAA, 0b001, 0xBBAABBAA, 0b0011, "SH Offset 0");
        check_store(0x102, 0xDDCC, 0b001, 0xDDCCDDCC, 0b1100, "SH Offset 2");
    }
    
    void test_load_word() {
        TB_LOG("Test: Load Word (LW)");
        check_load(0x100, 0xAABBCCDD, 0b010, 0xAABBCCDD, "LW");
        check_load(0x200, 0x80000000, 0b010, static_cast<int32_t>(0x80000000), "LW Negative");
    }
    
    void test_load_byte_signed() {
        TB_LOG("Test: Load Byte Signed (LB)");
        check_load(0x100, 0x000000FF, 0b000, -1, "LB Negative");
        check_load(0x100, 0x0000007F, 0b000, 0x7F, "LB Positive");
        check_load(0x101, 0x0000FF00, 0b000, -1, "LB Offset 1");
    }
    
    void test_load_byte_unsigned() {
        TB_LOG("Test: Load Byte Unsigned (LBU)");
        check_load(0x100, 0x000000FF, 0b100, 0xFF, "LBU");
        check_load(0x101, 0x0000AA00, 0b100, 0xAA, "LBU Offset 1");
    }
    
    void test_load_halfword_signed() {
        TB_LOG("Test: Load Halfword Signed (LH)");
        check_load(0x100, 0x0000FFFF, 0b001, -1, "LH Negative");
        check_load(0x100, 0x00007FFF, 0b001, 0x7FFF, "LH Positive");
        check_load(0x102, 0xFFFF0000, 0b001, -1, "LH Offset 2");
    }
    
    void test_load_halfword_unsigned() {
        TB_LOG("Test: Load Halfword Unsigned (LHU)");
        check_load(0x100, 0x0000FFFF, 0b101, 0xFFFF, "LHU");
        check_load(0x102, 0xAAAA0000, 0b101, 0xAAAA, "LHU Offset 2");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        LoadStoreTestbench tb;
        
        tb.test_store_word();
        tb.test_store_byte();
        tb.test_store_halfword();
        tb.test_load_word();
        tb.test_load_byte_signed();
        tb.test_load_byte_unsigned();
        tb.test_load_halfword_signed();
        tb.test_load_halfword_unsigned();
        
        TB_LOG("All Load Store Unit tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
