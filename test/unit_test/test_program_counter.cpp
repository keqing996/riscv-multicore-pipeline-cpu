#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
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
    PCTestbench() : ClockedTestbench<Vprogram_counter>(100, false), rng(12345) {
        dut->rst_n = 0;
        dut->data_in = 0;
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
        
        CHECK(dut->data_out == 0);
    }
    
    void test_random_updates() {
        
        std::uniform_int_distribution<uint32_t> dist(0, 0xFFFFFFFF);
        
        for (int i = 0; i < 20; i++) {
            uint32_t val = dist(rng);
            dut->data_in = val;
            tick();
            
            CHECK(dut->data_out == val);
        }
    }
    
    void test_sequential() {
        
        uint32_t pc = 0;
        for (int i = 0; i < 10; i++) {
            dut->data_in = pc;
            tick();
            CHECK(dut->data_out == pc);
            pc += 4;
        }
    }
};

TEST_CASE("Program Counter") {
PCTestbench tb;
        
        tb.reset();
        tb.test_random_updates();
        tb.test_sequential();
}
