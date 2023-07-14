#include "tb_base.h"
#include "Vcontrol_status_register_file.h"

// CSR Addresses
#define CSR_MSTATUS  0x300
#define CSR_MIE      0x304
#define CSR_MTVEC    0x305
#define CSR_MEPC     0x341
#define CSR_MCAUSE   0x342
#define CSR_MIP      0x344
#define CSR_MHARTID  0xF14

/**
 * CSR File Testbench
 * Tests Control and Status Registers with exception/interrupt handling
 */
class CSRTestbench : public ClockedTestbench<Vcontrol_status_register_file> {
public:
    CSRTestbench() : ClockedTestbench<Vcontrol_status_register_file>(100, true, "csr_trace.vcd") {
        dut->rst_n = 0;
        dut->csr_address = 0;
        dut->csr_write_enable = 0;
        dut->csr_write_data = 0;
        dut->exception_enable = 0;
        dut->exception_program_counter = 0;
        dut->exception_cause = 0;
        dut->machine_return_enable = 0;
        dut->timer_interrupt_request = 0;
        dut->hart_id = 0;
        TB_LOG("CSR File Testbench initialized");
    }
    
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }
    
    void reset() {
        dut->rst_n = 0;
        tick();
        tick();
        dut->rst_n = 1;
        tick();
        TB_LOG("Reset complete");
    }
    
    void write_csr(uint16_t addr, uint32_t data) {
        dut->csr_address = addr;
        dut->csr_write_data = data;
        dut->csr_write_enable = 1;
        tick();
        dut->csr_write_enable = 0;
    }
    
    uint32_t read_csr(uint16_t addr) {
        dut->csr_address = addr;
        eval();
        return dut->csr_read_data;
    }
    
    void test_basic_read_write() {
        TB_LOG("Test: Basic CSR read/write");
        
        // Write MTVEC
        write_csr(CSR_MTVEC, 0x1000);
        TB_ASSERT_EQ(read_csr(CSR_MTVEC), 0x1000, "MTVEC write/read");
        TB_ASSERT_EQ(dut->mtvec_out, 0x1000, "MTVEC output");
        
        // Write MIE
        write_csr(CSR_MIE, 0x888);
        TB_ASSERT_EQ(read_csr(CSR_MIE), 0x888, "MIE write/read");
    }
    
    void test_mhartid() {
        TB_LOG("Test: MHARTID register");
        
        dut->hart_id = 0;
        eval();
        TB_ASSERT_EQ(read_csr(CSR_MHARTID), 0, "MHARTID = 0");
        
        dut->hart_id = 1;
        eval();
        TB_ASSERT_EQ(read_csr(CSR_MHARTID), 1, "MHARTID = 1");
        
        dut->hart_id = 0; // Restore
    }
    
    void test_exception_handling() {
        TB_LOG("Test: Exception handling");
        
        // Enable interrupts in MSTATUS
        write_csr(CSR_MSTATUS, 0b1000); // MIE=1
        
        // Set MTVEC
        write_csr(CSR_MTVEC, 0x2000);
        
        // Trigger exception
        dut->exception_enable = 1;
        dut->exception_program_counter = 0x500;
        dut->exception_cause = 0x8;
        tick();
        dut->exception_enable = 0;
        eval();
        
        // Check MEPC and MCAUSE were updated
        TB_ASSERT_EQ(read_csr(CSR_MEPC), 0x500, "MEPC after exception");
        TB_ASSERT_EQ(read_csr(CSR_MCAUSE), 0x8, "MCAUSE after exception");
    }
    
    void test_interrupt_pending() {
        TB_LOG("Test: Interrupt pending (MIP)");
        
        dut->timer_interrupt_request = 0;
        eval();
        uint32_t mip = read_csr(CSR_MIP);
        TB_ASSERT_EQ(mip & (1 << 7), 0, "MIP timer bit clear");
        
        dut->timer_interrupt_request = 1;
        eval();
        mip = read_csr(CSR_MIP);
        TB_ASSERT_EQ((mip >> 7) & 1, 1, "MIP timer bit set");
        
        dut->timer_interrupt_request = 0;
    }
    
    void test_mret() {
        TB_LOG("Test: MRET (Machine Return)");
        
        // Set MEPC to return address
        write_csr(CSR_MEPC, 0x1234);
        
        // Execute MRET
        dut->machine_return_enable = 1;
        tick();
        dut->machine_return_enable = 0;
        
        // MEPC output should be available
        TB_ASSERT_EQ(dut->mepc_out, 0x1234, "MEPC output after MRET");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        CSRTestbench tb;
        
        tb.reset();
        tb.test_basic_read_write();
        tb.test_mhartid();
        tb.test_exception_handling();
        tb.test_interrupt_pending();
        tb.test_mret();
        
        TB_LOG("All CSR File tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
