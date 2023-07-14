int main() {
    // Trigger Environment Call (Exception Cause 11)
    asm volatile("ecall");
    
    asm volatile("li s4, 0x12345678");
    
    return 0;
}
