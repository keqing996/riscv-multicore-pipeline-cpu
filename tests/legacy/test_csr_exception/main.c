#include "common.h"

// Timer Helpers
void set_timer(uint32_t delta) {
    volatile uint32_t* mtime = (volatile uint32_t*)MTIME_ADDR;
    volatile uint32_t* mtimecmp = (volatile uint32_t*)MTIMECMP_ADDR;
    
    // Read current time (Low 32 bits only for simplicity)
    uint32_t now = *mtime;
    *mtimecmp = now + delta;
    
    // Set High bits to 0 for simplicity (assuming short test)
    *(mtime + 1) = 0;
    *(mtimecmp + 1) = 0;
}

// Trap Handler (called from assembly wrapper)
void c_trap_handler() {
    reg_t cause = csr_read(CSR_MCAUSE);
    reg_t epc = csr_read(CSR_MEPC);

    if (cause & 0x80000000) {
        // Interrupt
        reg_t irq_code = cause & 0x7FFFFFFF;
        if (irq_code == 7) {
            print("\n[IRQ] Timer Interrupt!\n");
            // Disable Timer Interrupt to stop loop
            reg_t mie = csr_read(CSR_MIE);
            csr_write(CSR_MIE, mie & ~(1 << 7)); // Clear MTIE
        } else {
            print("\n[IRQ] Unknown Interrupt: ");
            print_hex(cause);
            print("\n");
        }
        // For interrupts, return to EPC (re-execute or continue)
    } else {
        // Exception
        print("\n[EXC] Exception Cause: ");
        print_hex(cause);
        print("\n");
        
        if (cause == 11) { // ECALL
            print("Handling ECALL...\n");
            // Increment EPC to skip ECALL
            csr_write(CSR_MEPC, epc + 4);
        } else {
            print("Unknown Exception!\n");
            while(1);
        }
    }
}

extern void trap_entry();

int main() {
    print("RISC-V CSR & Interrupt Test\n");
    
    // 1. Setup Trap Vector
    csr_write(CSR_MTVEC, (reg_t)trap_entry);
    
    // 2. Trigger Exception (ECALL)
    print("1. Testing ECALL...\n");
    asm volatile ("ecall");
    print("Returned from ECALL.\n");
    
    // 3. Test Timer Interrupt
    print("2. Testing Timer Interrupt...\n");
    
    // Enable Global Interrupts (MIE bit 3 in mstatus)
    reg_t mstatus = csr_read(CSR_MSTATUS);
    csr_write(CSR_MSTATUS, mstatus | (1 << 3));
    
    // Enable Timer Interrupt (MTIE bit 7 in mie)
    csr_write(CSR_MIE, (1 << 7));
    
    // Set Timer to fire in 100 ticks
    set_timer(100);
    
    print("Waiting for interrupt...\n");
    
    // Wait loop
    volatile int i = 0;
    while(i < 100000) {
        i++;
        // Check if interrupt disabled (handler disables it)
        if ((csr_read(CSR_MIE) & (1 << 7)) == 0) {
            break;
        }
    }
    
    if (i < 100000) {
        print("Timer Interrupt Received! [PASS]\n");
    } else {
        print("Timeout waiting for interrupt! [FAIL]\n");
    }
    
    return 0;
}
