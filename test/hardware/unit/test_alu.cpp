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
    ALUTestbench() : TestbenchBase<Valu>(true, "alu_trace.vcd") {
        TB_LOG("ALU Testbench initialized");
    }
    
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
    void test_operation(uint32_t a, uint32_t b, uint8_t op, const char* op_name) {
        // Set inputs
        dut->a = a;
        dut->b = b;
        dut->alu_control_code = op;
        
        // Evaluate
        eval();
        
        // Get expected result from model
        uint32_t expected = model_alu(a, b, op);
        uint32_t actual = dut->result;
        
        // Check result
        if (actual != expected) {
            std::cerr << "FAIL: " << op_name << "(0x" << std::hex << a 
                      << ", 0x" << b << ") = 0x" << actual 
                      << ", expected 0x" << expected << std::dec << std::endl;
            throw std::runtime_error("ALU test failed");
        }
    }
    
    // Run all basic tests
    void run_basic_tests() {
        TB_LOG("Running basic ALU tests...");
        
        // ADD tests
        test_operation(10, 20, ALU_ADD, "ADD");
        test_operation(0xFFFFFFFF, 1, ALU_ADD, "ADD");
        test_operation(0x12345678, 0x87654321, ALU_ADD, "ADD");
        
        // SUB tests
        test_operation(20, 10, ALU_SUB, "SUB");
        test_operation(10, 20, ALU_SUB, "SUB");
        test_operation(0, 1, ALU_SUB, "SUB");
        
        // SLL tests
        test_operation(1, 0, ALU_SLL, "SLL");
        test_operation(1, 1, ALU_SLL, "SLL");
        test_operation(0xFFFFFFFF, 16, ALU_SLL, "SLL");
        
        // SLT tests (signed)
        test_operation(5, 10, ALU_SLT, "SLT");
        test_operation(10, 5, ALU_SLT, "SLT");
        test_operation(0xFFFFFFFF, 1, ALU_SLT, "SLT"); // -1 < 1
        test_operation(1, 0xFFFFFFFF, ALU_SLT, "SLT"); // 1 > -1
        
        // SLTU tests (unsigned)
        test_operation(5, 10, ALU_SLTU, "SLTU");
        test_operation(10, 5, ALU_SLTU, "SLTU");
        test_operation(0xFFFFFFFF, 1, ALU_SLTU, "SLTU"); // large > small
        
        // XOR tests
        test_operation(0xAAAAAAAA, 0x55555555, ALU_XOR, "XOR");
        test_operation(0xFF00FF00, 0xF0F0F0F0, ALU_XOR, "XOR");
        
        // SRL tests
        test_operation(0xFFFFFFFF, 1, ALU_SRL, "SRL");
        test_operation(0x80000000, 16, ALU_SRL, "SRL");
        
        // SRA tests (arithmetic shift)
        test_operation(0xFFFFFFFF, 1, ALU_SRA, "SRA");
        test_operation(0x80000000, 16, ALU_SRA, "SRA");
        test_operation(0x7FFFFFFF, 16, ALU_SRA, "SRA");
        
        // OR tests
        test_operation(0xFF00FF00, 0x00FF00FF, ALU_OR, "OR");
        test_operation(0xAAAAAAAA, 0x55555555, ALU_OR, "OR");
        
        // AND tests
        test_operation(0xFF00FF00, 0xF0F0F0F0, ALU_AND, "AND");
        test_operation(0xAAAAAAAA, 0x55555555, ALU_AND, "AND");
        
        // LUI test
        test_operation(0, 0x12345000, ALU_LUI, "LUI");
        
        TB_LOG("Basic tests PASSED");
    }
    
    // Run random tests
    void run_random_tests(int count = 100) {
        TB_LOG("Running random ALU tests...");
        
        srand(time(nullptr));
        
        const uint8_t ops[] = {
            ALU_ADD, ALU_SUB, ALU_SLL, ALU_SLT, ALU_SLTU,
            ALU_XOR, ALU_SRL, ALU_SRA, ALU_OR, ALU_AND
        };
        
        for (int i = 0; i < count; i++) {
            uint32_t a = tb_util::random_uint32();
            uint32_t b = tb_util::random_uint32();
            uint8_t op = ops[rand() % (sizeof(ops) / sizeof(ops[0]))];
            
            test_operation(a, b, op, "RANDOM");
        }
        
        TB_LOG("Random tests PASSED");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        ALUTestbench tb;
        tb.run_basic_tests();
        tb.run_random_tests(100);
        
        TB_LOG("==================================");
        TB_LOG("All ALU tests PASSED!");
        TB_LOG("==================================");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
