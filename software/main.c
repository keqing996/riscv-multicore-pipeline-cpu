#define UART_TX_ADDR 0x40000000

void putchar(char c) {
    volatile char* uart = (volatile char*)UART_TX_ADDR;
    *uart = c;
}

void print(const char* str) {
    while (*str) {
        putchar(*str++);
    }
}

int main() {
    print("Hello RISC-V World!\n");
    print("This is printed via MMIO UART.\n");
    
    // Simple test: Calculate Fibonacci
    // Write results to memory starting at 0x100 (256)
    
    volatile int* output = (volatile int*)0x100;
    
    int a = 0;
    int b = 1;
    int c;
    
    output[0] = a;
    output[1] = b;
    
    for (int i = 2; i < 10; i++) {
        c = a + b;
        output[i] = c;
        a = b;
        b = c;
    }
    
    print("Fibonacci calculation done.\n");
    
    return 0;
}
