#include "common.h"

void putchar(char c) {
    volatile char* uart = (volatile char*)UART_TX_ADDR;
    *uart = c;
}

void print(const char* str) {
    while (*str) {
        putchar(*str++);
    }
}

void print_hex(unsigned int val) {
    print("0x");
    for (int i = 7; i >= 0; i--) {
        int nibble = (val >> (i * 4)) & 0xF;
        if (nibble < 10) putchar('0' + nibble);
        else putchar('A' + nibble - 10);
    }
}

// Simple division/modulus for printing (very slow, but works without libgcc)
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

// Inline assembly to read/write CSRs
reg_t csr_read(int csr_num) {
    reg_t result = 0;
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
