#include "tb_base.h"
#include "Vmain_memory.h"
#include <string>

class MainMemoryTestbench : public ClockedTestbench<Vmain_memory> {
public:
    MainMemoryTestbench() : ClockedTestbench<Vmain_memory>(100, true, "main_memory_trace.vcd") {
        // Initialize inputs
        dut->address_a = 0;
        dut->address_b = 0;
        dut->write_data_b = 0;
        dut->write_enable_b = 0;
        dut->byte_enable_b = 0;
    }
    
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }
    
    void write_word(uint32_t addr, uint32_t data) {
        dut->address_b = addr;
        dut->write_data_b = data;
        dut->write_enable_b = 1;
        dut->byte_enable_b = 0b1111;
        eval();  // Setup before clock edge
        tick();  // Clock edge writes the data
        dut->write_enable_b = 0;
        eval();  // Propagate write_enable_b = 0
    }
    
    void write_byte(uint32_t addr, uint8_t byte_sel, uint32_t data) {
        dut->address_b = addr;
        dut->write_data_b = data;
        dut->write_enable_b = 1;
        dut->byte_enable_b = byte_sel;
        tick();
        dut->write_enable_b = 0;
    }
    
    uint32_t read_port_a(uint32_t addr) {
        dut->address_a = addr;
        eval();  // Asynchronous read
        return dut->read_data_a;
    }
    
    uint32_t read_port_b(uint32_t addr) {
        dut->address_b = addr;
        eval();  // Asynchronous read
        return dut->read_data_b;
    }
    
    void test_word_readwrite() {
        TB_LOG("Test: Word read/write");
        
        uint32_t addr = 0x100;
        uint32_t data = 0xDEADBEEF;
        
        // Write via port B
        write_word(addr, data);
        
        // Small delay to ensure write completes
        eval();
        
        // Read via port B
        uint32_t read_b = read_port_b(addr);
        printf("[DEBUG] After write: addr=0x%x, read_b=0x%x, expected=0x%x\n", addr, read_b, data);
        TB_ASSERT_EQ(read_b, data, "Port B read");
        
        // Read via port A
        TB_ASSERT_EQ(read_port_a(addr), data, "Port A read");
    }
    
    void test_byte_writes() {
        TB_LOG("Test: Byte-granular writes");
        
        uint32_t addr = 0x200;
        
        // Write individual bytes
        write_byte(addr, 0b0001, 0x000000AA);  // Byte 0
        write_byte(addr, 0b0010, 0x0000BB00);  // Byte 1
        write_byte(addr, 0b0100, 0x00CC0000);  // Byte 2
        write_byte(addr, 0b1000, 0xDD000000);  // Byte 3
        
        // Read full word
        uint32_t result = read_port_b(addr);
        TB_ASSERT_EQ(result, 0xDDCCBBAA, "Byte write composition");
    }
    
    void test_dual_port() {
        TB_LOG("Test: Dual port simultaneous access");
        
        uint32_t addr1 = 0x300;
        uint32_t addr2 = 0x400;
        uint32_t data1 = 0x11111111;
        uint32_t data2 = 0x22222222;
        
        // Write to both addresses
        write_word(addr1, data1);
        write_word(addr2, data2);
        
        // Read from both ports simultaneously (asynchronous)
        dut->address_a = addr1;
        dut->address_b = addr2;
        eval();
        
        TB_ASSERT_EQ(dut->read_data_a, data1, "Dual port: A reads addr1");
        TB_ASSERT_EQ(dut->read_data_b, data2, "Dual port: B reads addr2");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        MainMemoryTestbench tb;
        
        tb.test_word_readwrite();
        tb.test_byte_writes();
        tb.test_dual_port();
        
        TB_LOG("All Main Memory tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
