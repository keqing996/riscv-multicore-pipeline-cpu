#include "common.h"

int main() {
    print("Branch Prediction Test Start\n");

    // 1. Simple Loop (Taken many times, then Not Taken)
    // This trains the predictor to predict TAKEN.
    print("Test 1: Simple Loop\n");
    volatile int sum = 0;
    for (int i = 0; i < 10; i++) {
        sum += i;
    }
    // Sum should be 0+1+..+9 = 45
    print("Sum = "); print_int(sum);
    if (sum == 45) print(" [PASS]\n");
    else print(" [FAIL]\n");

    // 2. Pattern Test (Taken, Not Taken, Taken, Not Taken...)
    print("Test 2: Alternating Branch\n");
    volatile int even_count = 0;
    for (int i = 0; i < 20; i++) {
        if ((i & 1) == 0) { // Even
            even_count++;
        }
    }
    print("Even Count = "); print_int(even_count);
    if (even_count == 10) print(" [PASS]\n");
    else print(" [FAIL]\n");

    // 3. Nested Loop
    print("Test 3: Nested Loop\n");
    volatile int total_iters = 0;
    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            total_iters++;
        }
    }
    print("Total Iters = "); print_int(total_iters);
    if (total_iters == 25) print(" [PASS]\n");
    else print(" [FAIL]\n");

    print("Branch Prediction Test Done\n");
    return 0;
}
