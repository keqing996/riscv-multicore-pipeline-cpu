#include "tb_base.h"
#include "Vtimer.h"
#include <string>

class TimerTestbench : public ClockedTestbench<Vtimer> {
public:
    static constexpr uint32_t MTIME_L    = 0x40004000;
    static constexpr uint32_t MTIME_H    = 0x40004004;
    static constexpr uint32_t MTIMECMP_L = 0x40004008;
    static constexpr uint32_t MTIMECMP_H = 0x4000400C;
    
    TimerTestbench() : ClockedTestbench<Vtimer>(100, true, "timer_trace.vcd") {
        // Initialize inputs
        dut->write_enable = 0;
        dut->address = 0;
        dut->write_data = 0;
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
    
    uint32_t read_reg(uint32_t addr) {
        dut->address = addr;
        eval();
        return dut->read_data;
    }
    
    void write_reg(uint32_t addr, uint32_t data) {
        dut->address = addr;
        dut->write_data = data;
        dut->write_enable = 1;
        tick();
        dut->write_enable = 0;
    }
    
    void test_initial_state() {
        TB_LOG("Test: Initial state");
        
        // mtime should be small (recently reset)
        uint32_t mtime_l = read_reg(MTIME_L);
        if (mtime_l >= 100) {
            std::string msg = "mtime should start near 0, got " + std::to_string(mtime_l);
            throw std::runtime_error(msg);
        }
        
        // mtimecmp should be max
        TB_ASSERT_EQ(read_reg(MTIMECMP_L), 0xFFFFFFFF, "mtimecmp_l init");
        TB_ASSERT_EQ(read_reg(MTIMECMP_H), 0xFFFFFFFF, "mtimecmp_h init");
        
        // Interrupt should be low
        TB_ASSERT_EQ(dut->interrupt_request, 0, "Initial interrupt");
    }
    
    void test_interrupt_trigger() {
        TB_LOG("Test: Interrupt trigger");
        
        // Read current time
        uint32_t current_time = read_reg(MTIME_L);
        uint32_t target_time = current_time + 40;
        
        // Set mtimecmp
        write_reg(MTIMECMP_L, target_time);
        write_reg(MTIMECMP_H, 0);
        
        // Wait for interrupt to fire
        bool interrupt_fired = false;
        for (int i = 0; i < 100; i++) {
            tick();
            if (dut->interrupt_request == 1) {
                interrupt_fired = true;
                TB_LOG("Interrupt fired after waiting");
                break;
            }
        }
        
        if (!interrupt_fired) {
            std::string msg = "Interrupt did not fire. Target=" + std::to_string(target_time);
            throw std::runtime_error(msg);
        }
    }
    
    void test_interrupt_clear() {
        TB_LOG("Test: Clear interrupt");
        
        // Interrupt should still be asserted from previous test
        TB_ASSERT_EQ(dut->interrupt_request, 1, "Interrupt before clear");
        
        // Clear by setting mtimecmp to max
        write_reg(MTIMECMP_L, 0xFFFFFFFF);
        eval();
        
        TB_ASSERT_EQ(dut->interrupt_request, 0, "Interrupt after clear");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        TimerTestbench tb;
        
        tb.reset();
        tb.test_initial_state();
        tb.test_interrupt_trigger();
        tb.test_interrupt_clear();
        
        TB_LOG("All Timer tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
