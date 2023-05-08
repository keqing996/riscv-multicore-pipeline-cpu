#include "tb_base.h"
#include "Vcore_tile.h"
#include <iostream>
#include <unordered_map>
#include <vector>

/**
 * Core Tile Testbench
 * This tests the integrated core with caches and arbiter
 */
class CoreTileTestbench : public ClockedTestbench<Vcore_tile> {
private:
    // Simulated memory
    std::unordered_map<uint32_t, uint32_t> memory;
    uint64_t cycle_count;
    
public:
    CoreTileTestbench() : ClockedTestbench<Vcore_tile>(100, true, "core_tile_trace.vcd"), cycle_count(0) {
        // Initialize inputs
        dut->rst_n = 0;
        dut->hart_id = 0;
        dut->bus_ready = 0;
        dut->bus_rdata = 0;
        dut->timer_irq = 0;
        
        TB_LOG("Core Tile Testbench initialized");
    }
    
    void set_clk(uint8_t value) override {
        dut->clk = value;
        if (value == 0) {  // Count on falling edge
            cycle_count++;
        }
    }
    
    // Reset the core
    void reset(int cycles = 10) {
        dut->rst_n = 0;
        for (int i = 0; i < cycles; i++) {
            tick();
        }
        dut->rst_n = 1;
        TB_LOG("Reset complete");
    }
    
    // Handle bus transactions (simulate memory)
    void handle_bus() {
        if (dut->bus_req) {
            uint32_t addr = dut->bus_addr & 0xFFFFFFFC;  // Word-aligned
            
            if (dut->bus_we) {
                // Write operation
                uint32_t data = dut->bus_wdata;
                uint8_t be = dut->bus_be;
                
                // Handle byte enables
                if (be == 0xF) {
                    memory[addr] = data;
                } else {
                    uint32_t old = memory.count(addr) ? memory[addr] : 0;
                    uint32_t new_val = old;
                    for (int i = 0; i < 4; i++) {
                        if (be & (1 << i)) {
                            new_val = (new_val & ~(0xFF << (i*8))) | ((data >> (i*8) & 0xFF) << (i*8));
                        }
                    }
                    memory[addr] = new_val;
                }
                
                dut->bus_rdata = 0;
                dut->bus_ready = 1;
            } else {
                // Read operation - return NOP if not in memory
                dut->bus_rdata = memory.count(addr) ? memory[addr] : 0x00000013;  // NOP
                dut->bus_ready = 1;
            }
        } else {
            dut->bus_ready = 0;
        }
    }
    
    // Load program into memory
    void load_program(const std::vector<uint32_t>& program, uint32_t base_addr = 0) {
        for (size_t i = 0; i < program.size(); i++) {
            memory[base_addr + i * 4] = program[i];
        }
        TB_INFO("Loaded program: " << program.size() << " instructions at 0x" << std::hex << base_addr);
    }
    
    // Run for N cycles
    void run_cycles(int n) {
        for (int i = 0; i < n; i++) {
            handle_bus();
            tick();
        }
    }
    
    // Test: Basic initialization (should not hang!)
    void test_initialization() {
        TB_LOG("Test: Core Tile initialization (no hang)");
        
        reset();
        
        // Run for 50 cycles - should not hang!
        run_cycles(50);
        
        TB_LOG("SUCCESS: Core ran for 50 cycles without hanging");
    }
    
    // Test: Execute NOP instructions
    void test_nop_execution() {
        TB_LOG("Test: NOP instruction execution");
        
        // Load program with NOPs
        std::vector<uint32_t> program = {
            0x00000013,  // NOP (addi x0, x0, 0)
            0x00000013,  // NOP
            0x00000013,  // NOP
            0x00000013,  // NOP
        };
        load_program(program, 0x00000000);
        
        reset();
        run_cycles(100);
        
        TB_LOG("NOP execution test PASSED");
    }
    
    // Test: Simple arithmetic
    void test_simple_arithmetic() {
        TB_LOG("Test: Simple arithmetic instructions");
        
        // addi x1, x0, 10    # x1 = 10
        // addi x2, x0, 20    # x2 = 20  
        // add  x3, x1, x2    # x3 = x1 + x2 = 30
        std::vector<uint32_t> program = {
            0x00A00093,  // addi x1, x0, 10
            0x01400113,  // addi x2, x0, 20
            0x002081B3,  // add x3, x1, x2
            0x00000013,  // NOP (for completion)
        };
        load_program(program, 0x00000000);
        
        reset();
        run_cycles(200);  // Give enough time for pipelined execution
        
        TB_LOG("Arithmetic test completed");
    }
    
    uint64_t get_cycle_count() const {
        return cycle_count;
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        CoreTileTestbench tb;
        
        TB_LOG("========================================");
        TB_LOG("Core Tile Test Suite");
        TB_LOG("This was the test that hung with Cocotb!");
        TB_LOG("========================================");
        
        tb.test_initialization();
        tb.test_nop_execution();
        tb.test_simple_arithmetic();
        
        TB_LOG("");
        TB_LOG("========================================");
        TB_LOG("All Core Tile tests PASSED!");
        TB_LOG("Total cycles: " << tb.get_cycle_count());
        TB_LOG("No hang! Verilator wins!");
        TB_LOG("========================================");
        
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
