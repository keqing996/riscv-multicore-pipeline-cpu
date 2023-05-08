#include "tb_base.h"
#include "Vinstruction_decoder.h"
#include <random>
#include <string>

/**
 * Instruction Decoder Testbench
 * Tests decoding of RISC-V instruction formats
 */
class DecoderTestbench : public TestbenchBase<Vinstruction_decoder> {
private:
    std::mt19937 rng;
    
public:
    DecoderTestbench() : TestbenchBase<Vinstruction_decoder>(true, "decoder_trace.vcd"), rng(12345) {
        TB_LOG("Instruction Decoder Testbench initialized");
    }
    
    void check_decode(uint32_t inst, uint8_t exp_opcode, uint8_t exp_rd, uint8_t exp_funct3,
                      uint8_t exp_rs1, uint8_t exp_rs2, uint8_t exp_funct7, const char* name) {
        dut->instruction = inst;
        eval();
        
        std::string prefix(name);
        TB_ASSERT_EQ(dut->opcode, exp_opcode, (prefix + " opcode").c_str());
        TB_ASSERT_EQ(dut->rd, exp_rd, (prefix + " rd").c_str());
        TB_ASSERT_EQ(dut->function_3, exp_funct3, (prefix + " funct3").c_str());
        TB_ASSERT_EQ(dut->rs1, exp_rs1, (prefix + " rs1").c_str());
        TB_ASSERT_EQ(dut->rs2, exp_rs2, (prefix + " rs2").c_str());
        TB_ASSERT_EQ(dut->function_7, exp_funct7, (prefix + " funct7").c_str());
    }
    
    void test_r_type() {
        TB_LOG("Test: R-Type instruction decoding");
        
        // ADD x3, x1, x2 -> 0x002081B3
        // funct7=0000000, rs2=x2, rs1=x1, funct3=000, rd=x3, opcode=0110011
        uint32_t inst = 0x002081B3;
        check_decode(inst, 0b0110011, 3, 0b000, 1, 2, 0b0000000, "ADD");
        
        // SUB x5, x6, x7 -> 0x407302B3
        inst = 0x407302B3;
        check_decode(inst, 0b0110011, 5, 0b000, 6, 7, 0b0100000, "SUB");
        
        // XOR x10, x11, x12 -> 0x00C5C533
        inst = 0x00C5C533;
        check_decode(inst, 0b0110011, 10, 0b100, 11, 12, 0b0000000, "XOR");
    }
    
    void test_i_type() {
        TB_LOG("Test: I-Type instruction decoding");
        
        // ADDI x1, x0, 10 -> 0x00A00093
        uint32_t inst = 0x00A00093;
        check_decode(inst, 0b0010011, 1, 0b000, 0, 0, 0, "ADDI");
        
        // LW x5, 4(x2) -> 0x00412283
        inst = 0x00412283;
        check_decode(inst, 0b0000011, 5, 0b010, 2, 0, 0, "LW");
    }
    
    void test_s_type() {
        TB_LOG("Test: S-Type instruction decoding");
        
        // SW x5, 4(x2) -> 0x00512223
        uint32_t inst = 0x00512223;
        check_decode(inst, 0b0100011, 4, 0b010, 2, 5, 0, "SW");
    }
    
    void test_b_type() {
        TB_LOG("Test: B-Type instruction decoding");
        
        // BEQ x1, x2, offset -> rs1=x1, rs2=x2, funct3=000, opcode=1100011
        uint32_t inst = 0x00208063;
        check_decode(inst, 0b1100011, 0, 0b000, 1, 2, 0, "BEQ");
    }
    
    void test_u_type() {
        TB_LOG("Test: U-Type instruction decoding");
        
        // LUI x5, 0x12345 -> 0x123452B7
        uint32_t inst = 0x123452B7;
        check_decode(inst, 0b0110111, 5, 0, 0, 0, 0, "LUI");
    }
    
    void test_j_type() {
        TB_LOG("Test: J-Type instruction decoding");
        
        // JAL x1, offset -> rd=x1, opcode=1101111
        uint32_t inst = 0x000000EF;
        check_decode(inst, 0b1101111, 1, 0, 0, 0, 0, "JAL");
    }
    
    void test_random_fields() {
        TB_LOG("Test: Random field extraction");
        
        for (int i = 0; i < 50; i++) {
            uint8_t opcode = rng() % 128;
            uint8_t rd = rng() % 32;
            uint8_t funct3 = rng() % 8;
            uint8_t rs1 = rng() % 32;
            uint8_t rs2 = rng() % 32;
            uint8_t funct7 = rng() % 128;
            
            uint32_t inst = (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | 
                           (funct3 << 12) | (rd << 7) | opcode;
            
            check_decode(inst, opcode, rd, funct3, rs1, rs2, funct7, "Random");
        }
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        DecoderTestbench tb;
        
        tb.test_r_type();
        tb.test_i_type();
        tb.test_s_type();
        tb.test_b_type();
        tb.test_u_type();
        tb.test_j_type();
        tb.test_random_fields();
        
        TB_LOG("All Instruction Decoder tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
