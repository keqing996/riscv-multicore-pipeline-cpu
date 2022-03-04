int main() {
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
    
    return 0;
}
