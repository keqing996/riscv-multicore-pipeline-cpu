#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
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
    MDUTestbench() : ClockedTestbench<Vmdu>(100, false) {
        dut->rst_n = 0;
        dut->start = 0;
        dut->operation = 0;
        dut->operand_a = 0;
        dut->operand_b = 0;
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
        
        // MUL 10 * 5 = 50
        uint32_t res = run_operation(OP_MUL, 10, 5);
        CHECK(res == 50);
        
        // MUL -10 * 5 = -50
        res = run_operation(OP_MUL, 0xFFFFFFF6, 5);
        CHECK(static_cast<int32_t>(res) == -50);
        
        // MUL large numbers
        res = run_operation(OP_MUL, 1000, 2000);
        CHECK(res == 2000000);
    }
    
    void test_divide() {
        
        // DIV 100 / 5 = 20
        uint32_t res = run_operation(OP_DIV, 100, 5);
        CHECK(res == 20);
        
        // DIV -100 / 5 = -20
        res = run_operation(OP_DIV, 0xFFFFFF9C, 5);
        CHECK(static_cast<int32_t>(res) == -20);
        
        // DIV by 0 (should return -1 per RISC-V spec)
        res = run_operation(OP_DIV, 100, 0);
        CHECK(static_cast<int32_t>(res) == -1);
    }
    
    void test_remainder() {
        
        // REM 100 % 7 = 2
        uint32_t res = run_operation(OP_REM, 100, 7);
        CHECK(res == 2);
        
        // REM by 0 (should return dividend per RISC-V spec)
        res = run_operation(OP_REM, 123, 0);
        CHECK(res == 123);
    }
    
    void test_unsigned_operations() {
        
        // DIVU (unsigned divide)
        uint32_t res = run_operation(OP_DIVU, 0xFFFFFFFF, 2);
        CHECK(res == 0x7FFFFFFF);
        
        // REMU (unsigned remainder)
        res = run_operation(OP_REMU, 0xFFFFFFFF, 10);
        CHECK(res == 5);
    }
};

TEST_CASE("Mdu Unit") {
MDUTestbench tb;
        
        tb.reset();
        tb.test_multiply();
        tb.test_divide();
        tb.test_remainder();
        tb.test_unsigned_operations();
}
