#include "tb_base.h"
#include "Vbranch_unit.h"
#include <iostream>

// Branch function codes
const uint8_t FUNCT3_BEQ  = 0b000;
const uint8_t FUNCT3_BNE  = 0b001;
const uint8_t FUNCT3_BLT  = 0b100;
const uint8_t FUNCT3_BGE  = 0b101;
const uint8_t FUNCT3_BLTU = 0b110;
const uint8_t FUNCT3_BGEU = 0b111;

class BranchUnitTestbench : public TestbenchBase<Vbranch_unit> {
public:
    BranchUnitTestbench() : TestbenchBase<Vbranch_unit>(true, "branch_unit_trace.vcd") {
        TB_LOG("Branch Unit Testbench initialized");
    }
    
    void test_branch(uint8_t funct3, uint32_t a, uint32_t b, bool expected, const char* name) {
        dut->function_3 = funct3;
        dut->operand_a = a;
        dut->operand_b = b;
        eval();
        
        bool actual = dut->branch_condition_met;
        if (actual != expected) {
            std::cerr << "FAIL: " << name << "(0x" << std::hex << a << ", 0x" << b 
                      << ") = " << actual << ", expected " << expected << std::dec << std::endl;
            throw std::runtime_error("Branch test failed");
        }
    }
    
    void run_all_tests() {
        TB_LOG("Running Branch Unit tests...");
        
        // BEQ tests
        test_branch(FUNCT3_BEQ, 10, 10, true, "BEQ");
        test_branch(FUNCT3_BEQ, 10, 20, false, "BEQ");
        
        // BNE tests
        test_branch(FUNCT3_BNE, 10, 20, true, "BNE");
        test_branch(FUNCT3_BNE, 10, 10, false, "BNE");
        
        // BLT tests (signed)
        test_branch(FUNCT3_BLT, 5, 10, true, "BLT");
        test_branch(FUNCT3_BLT, 10, 5, false, "BLT");
        test_branch(FUNCT3_BLT, 0xFFFFFFFF, 1, true, "BLT");  // -1 < 1
        
        // BGE tests (signed)
        test_branch(FUNCT3_BGE, 10, 5, true, "BGE");
        test_branch(FUNCT3_BGE, 5, 10, false, "BGE");
        test_branch(FUNCT3_BGE, 10, 10, true, "BGE");
        
        // BLTU tests (unsigned)
        test_branch(FUNCT3_BLTU, 5, 10, true, "BLTU");
        test_branch(FUNCT3_BLTU, 0xFFFFFFFF, 1, false, "BLTU");  // 0xFFFFFFFF > 1
        
        // BGEU tests (unsigned)
        test_branch(FUNCT3_BGEU, 10, 5, true, "BGEU");
        test_branch(FUNCT3_BGEU, 0xFFFFFFFF, 1, true, "BGEU");
        
        TB_LOG("All Branch Unit tests PASSED");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        BranchUnitTestbench tb;
        tb.run_all_tests();
        
        TB_LOG("==================================" );
        TB_LOG("All Branch Unit tests PASSED!");
        TB_LOG("==================================");
        return 0;
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
