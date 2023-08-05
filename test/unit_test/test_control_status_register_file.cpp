#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
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
    CSRTestbench() : ClockedTestbench<Vcontrol_status_register_file>(100, false) {
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
        
        // Write MTVEC
        write_csr(CSR_MTVEC, 0x1000);
        CHECK(read_csr(CSR_MTVEC) == 0x1000);
        CHECK(dut->mtvec_out == 0x1000);
        
        // Write MIE
        write_csr(CSR_MIE, 0x888);
        CHECK(read_csr(CSR_MIE) == 0x888);
    }
    
    void test_mhartid() {
        
        dut->hart_id = 0;
        eval();
        CHECK(read_csr(CSR_MHARTID) == 0);
        
        dut->hart_id = 1;
        eval();
        CHECK(read_csr(CSR_MHARTID) == 1);
        
        dut->hart_id = 0; // Restore
    }
    
    void test_exception_handling() {
        
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
        CHECK(read_csr(CSR_MEPC) == 0x500);
        CHECK(read_csr(CSR_MCAUSE) == 0x8);
    }
    
    void test_interrupt_pending() {
        
        dut->timer_interrupt_request = 0;
        eval();
        uint32_t mip = read_csr(CSR_MIP);
        CHECK(mip & (1 << 7) == 0);
        
        dut->timer_interrupt_request = 1;
        eval();
        mip = read_csr(CSR_MIP);
        CHECK((mip >> 7) & 1 == 1);
        
        dut->timer_interrupt_request = 0;
    }
    
    void test_mret() {
        
        // Set MEPC to return address
        write_csr(CSR_MEPC, 0x1234);
        
        // Execute MRET
        dut->machine_return_enable = 1;
        tick();
        dut->machine_return_enable = 0;
        
        // MEPC output should be available
        CHECK(dut->mepc_out == 0x1234);
    }
};

TEST_CASE("Control Status Register File") {
CSRTestbench tb;
        
        tb.reset();
        tb.test_basic_read_write();
        tb.test_mhartid();
        tb.test_exception_handling();
        tb.test_interrupt_pending();
        tb.test_mret();
}
