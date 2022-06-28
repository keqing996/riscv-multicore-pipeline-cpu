#ifndef COMMON_H
#define COMMON_H

// Memory Map
#define UART_TX_ADDR 0x40000000
#define MTIME_ADDR   0x40004000
#define MTIMECMP_ADDR 0x40004008

// CSR Addresses
#define CSR_MSTATUS 0x300
#define CSR_MIE     0x304
#define CSR_MTVEC   0x305
#define CSR_MEPC    0x341
#define CSR_MCAUSE  0x342

// Types
typedef unsigned int uint32_t;
typedef unsigned long uintptr_t;
typedef unsigned long reg_t;

// Basic I/O
void putchar(char c);
void print(const char* str);
void print_hex(unsigned int val);
void print_int(int val);

// Math Helpers
unsigned int udiv(unsigned int num, unsigned int den);
unsigned int umod(unsigned int num, unsigned int den);

// CSR Helpers
reg_t csr_read(int csr_num);
void csr_write(int csr_num, reg_t val);

#endif // COMMON_H
