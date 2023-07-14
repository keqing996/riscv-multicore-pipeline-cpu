#include "tb_base.h"
#include "Vimmediate_generator.h"
#include <random>

// Opcodes
#define OP_I_ARITH  0b0010011
#define OP_S_STORE  0b0100011
#define OP_B_BRANCH 0b1100011
#define OP_U_LUI    0b0110111
#define OP_J_JAL    0b1101111

/**
 * Immediate Generator Testbench
 * Tests extraction of immediate values from different instruction formats
 */
class ImmGenTestbench : public TestbenchBase<Vimmediate_generator> {
private:
    std::mt19937 rng;
    
public:
    ImmGenTestbench() : TestbenchBase<Vimmediate_generator>(true, "imm_gen_trace.vcd"), rng(12345) {
        TB_LOG("Immediate Generator Testbench initialized");
    }
    
    int32_t get_signed_immediate() {
        uint32_t val = dut->immediate;
        if (val & 0x80000000) {
            return static_cast<int32_t>(val);
        }
        return static_cast<int32_t>(val);
    }
    
    void test_i_type() {
        TB_LOG("Test: I-Type immediate extraction");
        std::uniform_int_distribution<int32_t> dist(-2048, 2047);
        
        for (int i = 0; i < 20; i++) {
            int32_t imm_val = dist(rng);
            uint32_t imm_bits = imm_val & 0xFFF;
            
            // Build instruction: imm[11:0] in bits [31:20]
            uint32_t inst = (imm_bits << 20) | (rng() % 32 << 15) | (rng() % 32 << 7) | OP_I_ARITH;
            
            dut->instruction = inst;
            eval();
            
            int32_t got = get_signed_immediate();
            TB_ASSERT_EQ(got, imm_val, "I-Type immediate");
        }
    }
    
    void test_s_type() {
        TB_LOG("Test: S-Type immediate extraction");
        std::uniform_int_distribution<int32_t> dist(-2048, 2047);
        
        for (int i = 0; i < 20; i++) {
            int32_t imm_val = dist(rng);
            uint32_t imm_bits = imm_val & 0xFFF;
            uint32_t imm_11_5 = (imm_bits >> 5) & 0x7F;
            uint32_t imm_4_0 = imm_bits & 0x1F;
            
            // Build instruction: imm[11:5] in [31:25], imm[4:0] in [11:7]
            uint32_t inst = (imm_11_5 << 25) | (rng() % 32 << 20) | (rng() % 32 << 15) | (imm_4_0 << 7) | OP_S_STORE;
            
            dut->instruction = inst;
            eval();
            
            int32_t got = get_signed_immediate();
            TB_ASSERT_EQ(got, imm_val, "S-Type immediate");
        }
    }
    
    void test_b_type() {
        TB_LOG("Test: B-Type immediate extraction");
        std::uniform_int_distribution<int32_t> dist(-4096, 4094);
        
        for (int i = 0; i < 20; i++) {
            int32_t val = dist(rng);
            val &= ~1; // Make even (bit 0 always 0)
            
            uint32_t imm_bits = val & 0x1FFF;
            uint32_t bit_12 = (imm_bits >> 12) & 1;
            uint32_t bit_11 = (imm_bits >> 11) & 1;
            uint32_t bits_10_5 = (imm_bits >> 5) & 0x3F;
            uint32_t bits_4_1 = (imm_bits >> 1) & 0xF;
            
            // Build instruction: [31]=bit12, [30:25]=bits10-5, [11:8]=bits4-1, [7]=bit11
            uint32_t inst = (bit_12 << 31) | (bits_10_5 << 25) | (rng() % 32 << 20) | 
                           (rng() % 32 << 15) | (bits_4_1 << 8) | (bit_11 << 7) | OP_B_BRANCH;
            
            dut->instruction = inst;
            eval();
            
            int32_t got = get_signed_immediate();
            TB_ASSERT_EQ(got, val, "B-Type immediate");
        }
    }
    
    void test_u_type() {
        TB_LOG("Test: U-Type immediate extraction");
        std::uniform_int_distribution<uint32_t> dist(0, 0xFFFFF);
        
        for (int i = 0; i < 20; i++) {
            uint32_t imm_20 = dist(rng);
            int32_t expected = static_cast<int32_t>(imm_20 << 12);
            
            // Build instruction: imm[31:12] in bits [31:12]
            uint32_t inst = (imm_20 << 12) | (rng() % 32 << 7) | OP_U_LUI;
            
            dut->instruction = inst;
            eval();
            
            int32_t got = get_signed_immediate();
            TB_ASSERT_EQ(got, expected, "U-Type immediate");
        }
    }
    
    void test_j_type() {
        TB_LOG("Test: J-Type immediate extraction");
        std::uniform_int_distribution<int32_t> dist(-524288, 524286);
        
        for (int i = 0; i < 20; i++) {
            int32_t val = dist(rng);
            val &= ~1; // Make even
            
            uint32_t imm_bits = val & 0x1FFFFF;
            uint32_t bit_20 = (imm_bits >> 20) & 1;
            uint32_t bits_10_1 = (imm_bits >> 1) & 0x3FF;
            uint32_t bit_11 = (imm_bits >> 11) & 1;
            uint32_t bits_19_12 = (imm_bits >> 12) & 0xFF;
            
            // Build instruction: [31]=bit20, [30:21]=bits10-1, [20]=bit11, [19:12]=bits19-12
            uint32_t inst = (bit_20 << 31) | (bits_19_12 << 12) | (bit_11 << 20) | 
                           (bits_10_1 << 21) | (rng() % 32 << 7) | OP_J_JAL;
            
            dut->instruction = inst;
            eval();
            
            int32_t got = get_signed_immediate();
            TB_ASSERT_EQ(got, val, "J-Type immediate");
        }
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        ImmGenTestbench tb;
        
        tb.test_i_type();
        tb.test_s_type();
        tb.test_b_type();
        tb.test_u_type();
        tb.test_j_type();
        
        TB_LOG("All Immediate Generator tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
