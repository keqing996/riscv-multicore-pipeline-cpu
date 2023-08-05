#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Valu.h"
#include <iostream>
#include <cstdlib>
#include <ctime>

// ALU Control Codes (must match RTL)
const uint8_t ALU_ADD  = 0b0000;
const uint8_t ALU_SUB  = 0b1000;
const uint8_t ALU_SLL  = 0b0001;
const uint8_t ALU_SLT  = 0b0010;
const uint8_t ALU_SLTU = 0b0011;
const uint8_t ALU_XOR  = 0b0100;
const uint8_t ALU_SRL  = 0b0101;
const uint8_t ALU_SRA  = 0b1101;
const uint8_t ALU_OR   = 0b0110;
const uint8_t ALU_AND  = 0b0111;
const uint8_t ALU_LUI  = 0b1001;

/**
 * ALU Testbench
 */
class ALUTestbench : public TestbenchBase<Valu> {
public:
    ALUTestbench() : TestbenchBase<Valu>(false) {}  // Disable tracing for tests
    
    // Model of ALU for verification
    uint32_t model_alu(uint32_t a, uint32_t b, uint8_t op) {
        switch(op) {
            case ALU_ADD:
                return a + b;
            
            case ALU_SUB:
                return a - b;
            
            case ALU_SLL: {
                uint32_t shift = b & 0x1F;
                return a << shift;
            }
            
            case ALU_SLT: {
                // Signed comparison
                int32_t a_signed = (int32_t)a;
                int32_t b_signed = (int32_t)b;
                return (a_signed < b_signed) ? 1 : 0;
            }
            
            case ALU_SLTU:
                // Unsigned comparison
                return (a < b) ? 1 : 0;
            
            case ALU_XOR:
                return a ^ b;
            
            case ALU_SRL: {
                uint32_t shift = b & 0x1F;
                return a >> shift;
            }
            
            case ALU_SRA: {
                uint32_t shift = b & 0x1F;
                int32_t a_signed = (int32_t)a;
                return (uint32_t)(a_signed >> shift);
            }
            
            case ALU_OR:
                return a | b;
            
            case ALU_AND:
                return a & b;
            
            case ALU_LUI:
                return b;
            
            default:
                return 0;
        }
    }
    
    // Test single ALU operation
    uint32_t test_operation(uint32_t a, uint32_t b, uint8_t op) {
        dut->a = a;
        dut->b = b;
        dut->alu_control_code = op;
        eval();
        return dut->result;
    }
};

TEST_CASE("ALU - ADD operations") {
    ALUTestbench tb;
    
    SUBCASE("Basic ADD") {
        CHECK(tb.test_operation(10, 20, ALU_ADD) == 30);
    }
    
    SUBCASE("ADD with overflow") {
        CHECK(tb.test_operation(0xFFFFFFFF, 1, ALU_ADD) == 0);
    }
    
    SUBCASE("ADD complex") {
        CHECK(tb.test_operation(0x12345678, 0x87654321, ALU_ADD) == 0x99999999);
    }
}

TEST_CASE("ALU - SUB operations") {
    ALUTestbench tb;
    
    SUBCASE("Basic SUB") {
        CHECK(tb.test_operation(20, 10, ALU_SUB) == 10);
    }
    
    SUBCASE("SUB negative result") {
        CHECK(tb.test_operation(10, 20, ALU_SUB) == 0xFFFFFFF6);
    }
    
    SUBCASE("SUB underflow") {
        CHECK(tb.test_operation(0, 1, ALU_SUB) == 0xFFFFFFFF);
    }
}

TEST_CASE("ALU - SLL operations") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(1, 0, ALU_SLL) == 1);
    CHECK(tb.test_operation(1, 1, ALU_SLL) == 2);
    CHECK(tb.test_operation(0xFFFFFFFF, 16, ALU_SLL) == 0xFFFF0000);
}

TEST_CASE("ALU - SLT operations (signed)") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(5, 10, ALU_SLT) == 1);
    CHECK(tb.test_operation(10, 5, ALU_SLT) == 0);
    CHECK(tb.test_operation(0xFFFFFFFF, 1, ALU_SLT) == 1);  // -1 < 1
    CHECK(tb.test_operation(1, 0xFFFFFFFF, ALU_SLT) == 0);  // 1 > -1
}

TEST_CASE("ALU - SLTU operations (unsigned)") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(5, 10, ALU_SLTU) == 1);
    CHECK(tb.test_operation(10, 5, ALU_SLTU) == 0);
    CHECK(tb.test_operation(0xFFFFFFFF, 1, ALU_SLTU) == 0);  // large > small
}

TEST_CASE("ALU - XOR operations") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(0xAAAAAAAA, 0x55555555, ALU_XOR) == 0xFFFFFFFF);
    CHECK(tb.test_operation(0xFF00FF00, 0xF0F0F0F0, ALU_XOR) == 0x0FF00FF0);
}

TEST_CASE("ALU - SRL operations") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(0xFFFFFFFF, 1, ALU_SRL) == 0x7FFFFFFF);
    CHECK(tb.test_operation(0x80000000, 16, ALU_SRL) == 0x00008000);
}

TEST_CASE("ALU - SRA operations (arithmetic shift)") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(0xFFFFFFFF, 1, ALU_SRA) == 0xFFFFFFFF);
    CHECK(tb.test_operation(0x80000000, 16, ALU_SRA) == 0xFFFF8000);
    CHECK(tb.test_operation(0x7FFFFFFF, 16, ALU_SRA) == 0x00007FFF);
}

TEST_CASE("ALU - OR operations") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(0xFF00FF00, 0x00FF00FF, ALU_OR) == 0xFFFFFFFF);
    CHECK(tb.test_operation(0xAAAAAAAA, 0x55555555, ALU_OR) == 0xFFFFFFFF);
}

TEST_CASE("ALU - AND operations") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(0xFF00FF00, 0xF0F0F0F0, ALU_AND) == 0xF000F000);
    CHECK(tb.test_operation(0xAAAAAAAA, 0x55555555, ALU_AND) == 0x00000000);
}

TEST_CASE("ALU - LUI operations") {
    ALUTestbench tb;
    
    CHECK(tb.test_operation(0, 0x12345000, ALU_LUI) == 0x12345000);
}

TEST_CASE("ALU - Random operations") {
    ALUTestbench tb;
    srand(time(nullptr));
    
    const uint8_t ops[] = {
        ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
        ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND
    };
    
    for (int i = 0; i < 100; i++) {
        uint32_t a = tb_util::random_uint32();
        uint32_t b = tb_util::random_uint32();
        uint8_t op = ops[rand() % (sizeof(ops) / sizeof(ops[0]))];
        
        uint32_t expected = tb.model_alu(a, b, op);
        uint32_t actual = tb.test_operation(a, b, op);
        CHECK(actual == expected);
    }
}
