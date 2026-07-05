#pragma once

#include <verilated.h>
#if VM_TRACE
#include <verilated_vcd_c.h>
#endif
#include <memory>
#include <string>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <iomanip>

/**
 * Base class for all Verilator testbenches
 * Provides common utilities for clock, reset, tracing, etc.
 */
template<typename DUT>
class TestbenchBase {
protected:
    std::unique_ptr<DUT> dut;
#if VM_TRACE
    std::unique_ptr<VerilatedVcdC> trace;
#endif
    uint64_t sim_time;
    bool trace_enabled;
    
public:
    TestbenchBase(bool enable_trace = false, const std::string& trace_filename = "trace.vcd")
        : sim_time(0), trace_enabled(enable_trace) {
        
        dut = std::make_unique<DUT>();
        
        if (trace_enabled) {
#if VM_TRACE
            Verilated::traceEverOn(true);
            trace = std::make_unique<VerilatedVcdC>();
            dut->trace(trace.get(), 99);  // Trace 99 levels deep
            trace->open(trace_filename.c_str());
            std::cout << "Trace file: " << trace_filename << std::endl;
#else
            trace_enabled = false;
            std::cerr << "Trace requested, but this target was built without ENABLE_TRACE." << std::endl;
#endif
        }
    }
    
    virtual ~TestbenchBase() {
#if VM_TRACE
        if (trace) {
            trace->close();
        }
#endif
        dut->final();
    }
    
    // Evaluate the DUT
    void eval() {
        dut->eval();
#if VM_TRACE
        if (trace) {
            trace->dump(sim_time);
        }
#endif
        sim_time++;
    }
    
    // Get current simulation time
    uint64_t get_sim_time() const {
        return sim_time;
    }
    
    // Get DUT instance
    DUT* get_dut() {
        return dut.get();
    }
    
    // Flush trace (useful for debugging crashes)
    void flush_trace() {
#if VM_TRACE
        if (trace) {
            trace->flush();
        }
#endif
    }
};

/**
 * Testbench with clock generation
 */
template<typename DUT>
class ClockedTestbench : public TestbenchBase<DUT> {
protected:
    uint32_t clk_period_ps;  // Clock period in picoseconds
    
public:
    ClockedTestbench(uint32_t clk_freq_mhz = 100, 
                     bool enable_trace = false,
                     const std::string& trace_filename = "trace.vcd")
        : TestbenchBase<DUT>(enable_trace, trace_filename) {
        
        // Calculate clock period in picoseconds
        clk_period_ps = 1000000 / clk_freq_mhz;
    }
    
    // Single clock tick (full cycle: 0->1->0)
    virtual void tick() {
        // Rising edge
        set_clk(1);
        this->eval();
        
        // Falling edge
        set_clk(0);
        this->eval();
    }
    
    // Multiple clock ticks
    void tick(int n) {
        for (int i = 0; i < n; i++) {
            tick();
        }
    }
    
    // Set clock signal (override in derived class if clock signal name differs)
    virtual void set_clk(uint8_t value) = 0;
};

// Utility functions
namespace tb_util {
    // Random number generation
    uint32_t random_seed();
    uint32_t random_uint32();
    uint32_t random_range(uint32_t min, uint32_t max);
    void init_random();
    
    // Convert nanoseconds to clock cycles
    inline uint64_t ns_to_cycles(uint64_t ns, uint32_t clk_period_ns) {
        return (ns + clk_period_ns - 1) / clk_period_ns;
    }
    
    // Print hex value
    inline void print_hex(const char* name, uint32_t value) {
        std::cout << name << " = 0x" << std::hex << std::setw(8) 
                  << std::setfill('0') << value << std::dec << std::endl;
    }
}
