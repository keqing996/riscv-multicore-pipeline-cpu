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

// Simple division/modulus for printing (very slow, but works without libgcc)
// We define these with the names the linker expects, just in case.
unsigned int __udivsi3(unsigned int num, unsigned int den) {
    unsigned int quot = 0;
    while (num >= den) {
        num -= den;
        quot++;
    }
    return quot;
}

unsigned int __umodsi3(unsigned int num, unsigned int den) {
    while (num >= den) {
        num -= den;
    }
    return num;
}

// Wrapper for our code to use
unsigned int udiv(unsigned int num, unsigned int den) {
    return __udivsi3(num, den);
}

unsigned int umod(unsigned int num, unsigned int den) {
    return __umodsi3(num, den);
}

void print_int(int val) {
    char buffer[12];
    int i = 0;
    if (val == 0) {
        print("0");
        return;
    }
    
    if (val < 0) {
        putchar('-');
        val = -val;
    }
    
    unsigned int uval = (unsigned int)val;
    while (uval > 0) {
        buffer[i++] = umod(uval, 10) + '0';
        uval = udiv(uval, 10);
    }
    
    while (i > 0) {
        putchar(buffer[--i]);
    }
}

int main() {
    print("Fibonacci Test\n");
    
    int n = 10;
    int a = 0, b = 1, next;
    
    print("Fib Series: ");
    
    for (int i = 0; i < n; i++) {
        print_int(a);
        if (i < n - 1) print(", ");
        next = a + b;
        a = b;
        b = next;
    }
    print("\nDone.\n");
    
    return 0;
}
