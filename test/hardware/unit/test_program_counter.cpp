#include "tb_base.h"
#include "Vprogram_counter.h"
#include <random>

/**
 * Program Counter Testbench
 * Simple register that holds the current PC value
 */
class PCTestbench : public ClockedTestbench<Vprogram_counter> {
private:
    std::mt19937 rng;
    
public:
    PCTestbench() : ClockedTestbench<Vprogram_counter>(100, true, "pc_trace.vcd"), rng(12345) {
        dut->rst_n = 0;
        dut->data_in = 0;
        TB_LOG("Program Counter Testbench initialized");
    }
    
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }
    
    void reset() {
        dut->rst_n = 0;
        dut->data_in = 0;
        tick();
        dut->rst_n = 1;
        tick();
        
        TB_ASSERT_EQ(dut->data_out, 0, "Reset value");
    }
    
    void test_random_updates() {
        TB_LOG("Test: Random PC updates");
        
        std::uniform_int_distribution<uint32_t> dist(0, 0xFFFFFFFF);
        
        for (int i = 0; i < 20; i++) {
            uint32_t val = dist(rng);
            dut->data_in = val;
            tick();
            
            TB_ASSERT_EQ(dut->data_out, val, "PC update");
        }
    }
    
    void test_sequential() {
        TB_LOG("Test: Sequential PC increments");
        
        uint32_t pc = 0;
        for (int i = 0; i < 10; i++) {
            dut->data_in = pc;
            tick();
            TB_ASSERT_EQ(dut->data_out, pc, "Sequential PC");
            pc += 4;
        }
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        PCTestbench tb;
        
        tb.reset();
        tb.test_random_updates();
        tb.test_sequential();
        
        TB_LOG("All Program Counter tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
