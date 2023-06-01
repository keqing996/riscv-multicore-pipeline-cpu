#include "tb_base.h"
#include "Vmdu.h"

// MDU Operations
#define OP_MUL    0b000
#define OP_MULH   0b001
#define OP_MULHSU 0b010
#define OP_MULHU  0b011
#define OP_DIV    0b100
#define OP_DIVU   0b101
#define OP_REM    0b110
#define OP_REMU   0b111

/**
 * MDU (Multiply-Divide Unit) Testbench
 * Tests multiply and divide operations including signed/unsigned variants
 */
class MDUTestbench : public ClockedTestbench<Vmdu> {
public:
    MDUTestbench() : ClockedTestbench<Vmdu>(100, true, "mdu_trace.vcd") {
        dut->rst_n = 0;
        dut->start = 0;
        dut->operation = 0;
        dut->operand_a = 0;
        dut->operand_b = 0;
        TB_LOG("MDU Testbench initialized");
    }
    
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }
    
    void reset() {
        dut->rst_n = 0;
        tick();
        tick();
        dut->rst_n = 1;
        tick();
        TB_LOG("Reset complete");
    }
    
    uint32_t run_operation(uint8_t op, uint32_t a, uint32_t b) {
        dut->operation = op;
        dut->operand_a = a;
        dut->operand_b = b;
        dut->start = 1;
        tick();
        dut->start = 0;
        
        // Wait for ready
        int timeout = 100;
        while (!dut->ready && timeout-- > 0) {
            tick();
        }
        
        if (timeout <= 0) {
            throw std::runtime_error("MDU operation timeout");
        }
        
        return dut->result;
    }
    
    void test_multiply() {
        TB_LOG("Test: Multiply operations");
        
        // MUL 10 * 5 = 50
        uint32_t res = run_operation(OP_MUL, 10, 5);
        TB_ASSERT_EQ(res, 50, "MUL 10*5");
        
        // MUL -10 * 5 = -50
        res = run_operation(OP_MUL, 0xFFFFFFF6, 5);
        TB_ASSERT_EQ(static_cast<int32_t>(res), -50, "MUL -10*5");
        
        // MUL large numbers
        res = run_operation(OP_MUL, 1000, 2000);
        TB_ASSERT_EQ(res, 2000000, "MUL 1000*2000");
    }
    
    void test_divide() {
        TB_LOG("Test: Divide operations");
        
        // DIV 100 / 5 = 20
        uint32_t res = run_operation(OP_DIV, 100, 5);
        TB_ASSERT_EQ(res, 20, "DIV 100/5");
        
        // DIV -100 / 5 = -20
        res = run_operation(OP_DIV, 0xFFFFFF9C, 5);
        TB_ASSERT_EQ(static_cast<int32_t>(res), -20, "DIV -100/5");
        
        // DIV by 0 (should return -1 per RISC-V spec)
        res = run_operation(OP_DIV, 100, 0);
        TB_ASSERT_EQ(static_cast<int32_t>(res), -1, "DIV by 0");
    }
    
    void test_remainder() {
        TB_LOG("Test: Remainder operations");
        
        // REM 100 % 7 = 2
        uint32_t res = run_operation(OP_REM, 100, 7);
        TB_ASSERT_EQ(res, 2, "REM 100%7");
        
        // REM by 0 (should return dividend per RISC-V spec)
        res = run_operation(OP_REM, 123, 0);
        TB_ASSERT_EQ(res, 123, "REM by 0");
    }
    
    void test_unsigned_operations() {
        TB_LOG("Test: Unsigned operations");
        
        // DIVU (unsigned divide)
        uint32_t res = run_operation(OP_DIVU, 0xFFFFFFFF, 2);
        TB_ASSERT_EQ(res, 0x7FFFFFFF, "DIVU max/2");
        
        // REMU (unsigned remainder)
        res = run_operation(OP_REMU, 0xFFFFFFFF, 10);
        TB_ASSERT_EQ(res, 5, "REMU max%10");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        MDUTestbench tb;
        
        tb.reset();
        tb.test_multiply();
        tb.test_divide();
        tb.test_remainder();
        tb.test_unsigned_operations();
        
        TB_LOG("All MDU tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
