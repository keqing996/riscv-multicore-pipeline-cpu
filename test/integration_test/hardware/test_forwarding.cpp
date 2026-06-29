#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "chip_top_tb.h"
// Test: Forwarding Integration Test
// Tests both GPR and CSR forwarding paths:
// - GPR Forwarding (EX->EX): ADDI x1=10, ADD x2=x1+x1 (x2=20)
// - CSR Forwarding: ECALL -> mtvec handler -> MRET -> mepc target
// Program Layout:
// 0x00: ADDI x1, x0, 10      (x1 = 10)
// 0x04: ADD  x2, x1, x1      (x2 = 20) -> Tests GPR Forwarding
// 0x08: ADDI x3, x0, 0x40    (x3 = 0x40)
// 0x0C: CSRRW x0, mtvec, x3  (mtvec = 0x40)
// 0x10: ECALL                (Trap to 0x40)
// ...
// 0x40: ADDI x4, x0, 0x80    (x4 = 0x80)
// 0x44: CSRRW x0, mepc, x4   (mepc = 0x80)
// 0x48: MRET                 (Return to 0x80)
// ...
// 0x80: ADDI x10, x0, 1      (Success marker)
// 0x84: EBREAK



TEST_CASE("Forwarding") {
ChipTopTestbench tb;

    // Initialize program with NOPs
    std::vector<uint32_t> program(256, 0x00000013); // 256 NOPs

    // Main instructions
    program[0] = 0x00a00093;  // 0x00: ADDI x1, x0, 10
    program[1] = 0x00108133;  // 0x04: ADD x2, x1, x1
    program[2] = 0x04000193;  // 0x08: ADDI x3, x0, 0x40
    program[3] = 0x30519073;  // 0x0C: CSRRW x0, mtvec, x3
    program[4] = 0x00000073;  // 0x10: ECALL

    // Handler at 0x40 (Index 16)
    program[16] = 0x08000213; // 0x40: ADDI x4, x0, 0x80
    program[17] = 0x34121073; // 0x44: CSRRW x0, mepc, x4
    program[18] = 0x30200073; // 0x48: MRET

    // Target at 0x80 (Index 32)
    program[32] = 0x00100513; // 0x80: ADDI x10, x0, 1
    program[33] = 0x00100073; // 0x84: EBREAK

    tb.load_program(program);
    tb.reset();

    // Run until EBREAK
    bool ebreak_reached = false;
    for (int cycles = 0; cycles < 200; cycles++) {
        tb.tick();
        
        uint32_t pc_ex = tb.get_pc_ex();
        if (tb.is_halted()) { // EBREAK instruction address
            ebreak_reached = true;
            for (int i = 0; i < 5; i++) tb.tick();
            break;
        }
    }

    CHECK(ebreak_reached == true);

    // Check GPR Forwarding Result
    uint32_t x2 = tb.read_register(2);
    CHECK(x2 == 20);

    // Check CSR Forwarding Result (Reached end of program)
    uint32_t x10 = tb.read_register(10);
    CHECK(x10 == 1);
}
