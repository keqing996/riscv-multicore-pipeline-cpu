#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Valu_control_unit.h"
#include <sstream>

// ALU Control Codes (must match RTL)
#define ALU_ADD  0b0000
#define ALU_SUB  0b1000
#define ALU_SLL  0b0001
#define ALU_SLT  0b0010
#define ALU_SLTU 0b0011
#define ALU_XOR  0b0100
#define ALU_SRL  0b0101
#define ALU_SRA  0b1101
#define ALU_OR   0b0110
#define ALU_AND  0b0111
#define ALU_LUI  0b1001

/**
 * ALU Control Unit Testbench
 * Generates ALU operation codes based on instruction type and funct fields
 */
class ALUControlTestbench : public TestbenchBase<Valu_control_unit> {
public:
    ALUControlTestbench() : TestbenchBase<Valu_control_unit>(false) {
    }
    
    void check(uint8_t alu_op, uint8_t funct3, uint8_t funct7, uint8_t expected_ctrl, const char* name) {
        dut->alu_operation_code = alu_op;
        dut->function_3 = funct3;
        dut->function_7 = funct7;
        eval();
        
        uint8_t got = dut->alu_control_code;
        if (got != expected_ctrl) {
            std::stringstream ss;
            ss << name << " - Op=" << (int)alu_op << " F3=" << (int)funct3 << " F7=" << (int)funct7;
            CHECK(got, expected_ctrl, ss.str( ==).c_str());
        }
    }
    
    void test_load_store_auipc() {
        check(0b000, 0, 0, ALU_ADD, "LW/SW/AUIPC");
    }
    
    void test_branch_operations() {
        check(0b001, 0b000, 0, ALU_SUB, "BEQ");
        check(0b001, 0b001, 0, ALU_SUB, "BNE");
        check(0b001, 0b100, 0, ALU_SLT, "BLT");
        check(0b001, 0b101, 0, ALU_SLT, "BGE");
        check(0b001, 0b110, 0, ALU_SLTU, "BLTU");
        check(0b001, 0b111, 0, ALU_SLTU, "BGEU");
    }
    
    void test_r_type() {
        check(0b010, 0b000, 0b0000000, ALU_ADD, "ADD");
        check(0b010, 0b000, 0b0100000, ALU_SUB, "SUB");
        check(0b010, 0b001, 0, ALU_SLL, "SLL");
        check(0b010, 0b010, 0, ALU_SLT, "SLT");
        check(0b010, 0b011, 0, ALU_SLTU, "SLTU");
        check(0b010, 0b100, 0, ALU_XOR, "XOR");
        check(0b010, 0b101, 0b0000000, ALU_SRL, "SRL");
        check(0b010, 0b101, 0b0100000, ALU_SRA, "SRA");
        check(0b010, 0b110, 0, ALU_OR, "OR");
        check(0b010, 0b111, 0, ALU_AND, "AND");
    }
    
    void test_i_type() {
        check(0b011, 0b000, 0, ALU_ADD, "ADDI");
        check(0b011, 0b001, 0, ALU_SLL, "SLLI");
        check(0b011, 0b010, 0, ALU_SLT, "SLTI");
        check(0b011, 0b011, 0, ALU_SLTU, "SLTIU");
        check(0b011, 0b100, 0, ALU_XOR, "XORI");
        check(0b011, 0b101, 0b0000000, ALU_SRL, "SRLI");
        check(0b011, 0b101, 0b0100000, ALU_SRA, "SRAI");
        check(0b011, 0b110, 0, ALU_OR, "ORI");
        check(0b011, 0b111, 0, ALU_AND, "ANDI");
    }
    
    void test_lui() {
        check(0b100, 0, 0, ALU_LUI, "LUI");
    }
};

TEST_CASE("Alu Control Unit") {
ALUControlTestbench tb;
        
        tb.test_load_store_auipc();
        tb.test_branch_operations();
        tb.test_r_type();
        tb.test_i_type();
        tb.test_lui();
}
