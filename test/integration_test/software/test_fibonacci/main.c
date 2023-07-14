int fib(int n) {
    if (n <= 1) return n;
    return fib(n-1) + fib(n-2);
}

int main() {
    // Calculate 10th fibonacci number: 55 (0x37)
    int result = fib(10);
    return result;
}
