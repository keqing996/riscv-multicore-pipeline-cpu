#include "common.h"

int main() {
    print("ALU Test Start\n");

    volatile int v1 = 5;
    volatile int v2 = 8;
    volatile int res;

    // 1. ADD Test (5 + 8 = 13)
    res = v1 + v2;
    print("5 + 8 = ");
    print_hex(res);
    if (res == 13) print(" [PASS]\n");
    else print(" [FAIL] Expected 0xD\n");

    // 2. SUB Test (13 - 5 = 8)
    volatile int v3 = 13;
    res = v3 - v1;
    print("13 - 5 = ");
    print_hex(res);
    if (res == 8) print(" [PASS]\n");
    else print(" [FAIL] Expected 0x8\n");

    // 3. AND Test (0xF0 & 0x3C = 0x30)
    // 11110000 & 00111100 = 00110000
    volatile int v4 = 0xF0;
    volatile int v5 = 0x3C;
    res = v4 & v5;
    print("0xF0 & 0x3C = ");
    print_hex(res);
    if (res == 0x30) print(" [PASS]\n");
    else print(" [FAIL] Expected 0x30\n");

    // 4. OR Test (0xF0 | 0x3C = 0xFC)
    // 11110000 | 00111100 = 11111100
    res = v4 | v5;
    print("0xF0 | 0x3C = ");
    print_hex(res);
    if (res == 0xFC) print(" [PASS]\n");
    else print(" [FAIL] Expected 0xFC\n");

    // 5. XOR Test (0xF0 ^ 0x3C = 0xCC)
    // 11110000 ^ 00111100 = 11001100
    res = v4 ^ v5;
    print("0xF0 ^ 0x3C = ");
    print_hex(res);
    if (res == 0xCC) print(" [PASS]\n");
    else print(" [FAIL] Expected 0xCC\n");

    // 6. SLL Test (1 << 3 = 8)
    volatile int v6 = 1;
    res = v6 << 3;
    print("1 << 3 = ");
    print_hex(res);
    if (res == 8) print(" [PASS]\n");
    else print(" [FAIL] Expected 0x8\n");

    // 7. SRL Test (16 >> 2 = 4)
    volatile int v7 = 16;
    res = v7 >> 2; // Logical shift for unsigned, but here int is signed. 
                   // Positive numbers behave same for arithmetic/logical usually.
    print("16 >> 2 = ");
    print_hex(res);
    if (res == 4) print(" [PASS]\n");
    else print(" [FAIL] Expected 0x4\n");

    // 8. SLT Test (5 < 8 = 1)
    res = (v1 < v2) ? 1 : 0;
    print("5 < 8 = ");
    print_hex(res);
    if (res == 1) print(" [PASS]\n");
    else print(" [FAIL] Expected 0x1\n");

    // 9. Fibonacci Loop Test
    print("Fib Loop Test (Hex):\n");
    int f0 = 0;
    int f1 = 1;
    int fn;
    
    for (int i = 0; i < 6; i++) {
        fn = f0 + f1;
        f0 = f1;
        f1 = fn;
        print_hex(f0); print(" + "); print_hex(f1); print(" = "); print_hex(fn); print("\n");
    }
    
    print("Fib(7) = ");
    print_hex(f1);
    if (f1 == 13) print(" [PASS]\n");
    else print(" [FAIL] Expected 0xD\n");

    // 10. Fibonacci Series Test (Decimal)
    print("Fib Series (Decimal): ");
    int n = 10;
    int a = 0, b = 1, next;
    
    for (int i = 0; i < n; i++) {
        print_int(a);
        if (i < n - 1) print(", ");
        next = a + b;
        a = b;
        b = next;
    }
    print("\n");

    print("ALU Test Done\n");
    return 0;
}
