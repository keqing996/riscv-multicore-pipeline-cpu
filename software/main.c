#define UART_TX_ADDR 0x40000000

// CSR Addresses
#define CSR_MSTATUS 0x300
#define CSR_MTVEC   0x305
#define CSR_MEPC    0x341
#define CSR_MCAUSE  0x342

void putchar(char c) {
    volatile char* uart = (volatile char*)UART_TX_ADDR;
    *uart = c;
}

void print(const char* str) {
    while (*str) {
        putchar(*str++);
    }
}

// Inline assembly to read/write CSRs
unsigned int csr_read(int csr_num) {
    unsigned int result;
    // We use a switch because csr instruction requires immediate
    // But for testing, we can just hardcode specific ones or use a macro
    // Let's just test MTVEC for now
    if (csr_num == CSR_MTVEC) {
        asm volatile ("csrr %0, mtvec" : "=r"(result));
    } else if (csr_num == CSR_MEPC) {
        asm volatile ("csrr %0, mepc" : "=r"(result));
    } else if (csr_num == CSR_MCAUSE) {
        asm volatile ("csrr %0, mcause" : "=r"(result));
    }
    return result;
}

void csr_write(int csr_num, unsigned int val) {
    if (csr_num == CSR_MTVEC) {
        asm volatile ("csrw mtvec, %0" : : "r"(val));
    } else if (csr_num == CSR_MEPC) {
        asm volatile ("csrw mepc, %0" : : "r"(val));
    }
}

// Trap Handler
void trap_handler() {
    print("\n!!! TRAP HANDLER !!!\n");
    print("MCAUSE: ");
    // Print hex (simplified)
    unsigned int cause = csr_read(CSR_MCAUSE);
    // ... (hex print logic omitted for brevity)
    
    print("Returning from trap...\n");
    
    // Increment MEPC to skip the ECALL instruction (otherwise infinite loop)
    unsigned int epc = csr_read(CSR_MEPC);
    csr_write(CSR_MEPC, epc + 4);
    
    // MRET
    asm volatile ("mret");
}

int main() {
    print("Hello RISC-V World!\n");
    
    // 1. Setup Trap Vector
    print("Setting up MTVEC...\n");
    csr_write(CSR_MTVEC, (unsigned int)trap_handler);
    
    // 2. Trigger Exception (ECALL)
    print("Triggering ECALL...\n");
    asm volatile ("ecall");
    
    print("Back in main!\n");
    
    return 0;
}
