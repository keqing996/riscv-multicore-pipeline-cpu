#define UART_TX_ADDR 0x40000000
#define MTIME_ADDR   0x40004000
#define MTIMECMP_ADDR 0x40004008

// CSR Addresses
#define CSR_MSTATUS 0x300
#define CSR_MIE     0x304
#define CSR_MTVEC   0x305
#define CSR_MEPC    0x341
#define CSR_MCAUSE  0x342

typedef unsigned int uint32_t;
typedef unsigned long uintptr_t;
typedef unsigned long reg_t;

void putchar(char c) {
    volatile char* uart = (volatile char*)UART_TX_ADDR;
    *uart = c;
}

void print(const char* str) {
    while (*str) {
        putchar(*str++);
    }
}

void print_hex(reg_t val) {
    print("0x");
    for (int i = 7; i >= 0; i--) {
        int nibble = (val >> (i * 4)) & 0xF;
        if (nibble < 10) putchar('0' + nibble);
        else putchar('A' + nibble - 10);
    }
}

// Inline assembly to read/write CSRs
reg_t csr_read(int csr_num) {
    reg_t result;
    if (csr_num == CSR_MTVEC) {
        asm volatile ("csrr %0, mtvec" : "=r"(result));
    } else if (csr_num == CSR_MEPC) {
        asm volatile ("csrr %0, mepc" : "=r"(result));
    } else if (csr_num == CSR_MCAUSE) {
        asm volatile ("csrr %0, mcause" : "=r"(result));
    } else if (csr_num == CSR_MSTATUS) {
        asm volatile ("csrr %0, mstatus" : "=r"(result));
    } else if (csr_num == CSR_MIE) {
        asm volatile ("csrr %0, mie" : "=r"(result));
    }
    return result;
}

void csr_write(int csr_num, reg_t val) {
    if (csr_num == CSR_MTVEC) {
        asm volatile ("csrw mtvec, %0" : : "r"(val));
    } else if (csr_num == CSR_MEPC) {
        asm volatile ("csrw mepc, %0" : : "r"(val));
    } else if (csr_num == CSR_MSTATUS) {
        asm volatile ("csrw mstatus, %0" : : "r"(val));
    } else if (csr_num == CSR_MIE) {
        asm volatile ("csrw mie, %0" : : "r"(val));
    }
}

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
