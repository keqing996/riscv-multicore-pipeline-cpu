#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vbranch_predictor.h"
#include <string>

/**
 * Branch Predictor Testbench
 * Tests BTB (Branch Target Buffer) and BHT (Branch History Table)
 * Uses 2-bit saturating counter (Weakly/Strongly Not Taken/Taken)
 */
class BranchPredictorTestbench : public ClockedTestbench<Vbranch_predictor> {
public:
    BranchPredictorTestbench() : ClockedTestbench<Vbranch_predictor>(100, false) {
        dut->rst_n = 0;
        dut->program_counter_fetch = 0;
        dut->program_counter_execute = 0;
        dut->branch_taken_execute = 0;
        dut->branch_target_execute = 0;
        dut->is_branch_execute = 0;
        dut->is_jump_execute = 0;
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
    
    void train_branch(uint32_t pc, bool taken, uint32_t target) {
        dut->program_counter_execute = pc;
        dut->branch_taken_execute = taken ? 1 : 0;
        dut->branch_target_execute = target;
        dut->is_branch_execute = 1;
        tick();
        dut->is_branch_execute = 0;
        eval();
    }
    
    void check_prediction(uint32_t pc, bool exp_taken, uint32_t exp_target, const char* name) {
        dut->program_counter_fetch = pc;
        eval();
        
        std::string prefix(name);
        CHECK(dut->prediction_taken, exp_taken ? 1 : 0, (prefix + " prediction_taken" ==).c_str());
        if (exp_taken) {
            CHECK(dut->prediction_target, exp_target, (prefix + " prediction_target" ==).c_str());
        }
    }
    
    void test_initial_state() {
        
        // BHT starts at Weakly Not Taken
        check_prediction(0x100, false, 0, "Initial state");
    }
    
    void test_training_to_taken() {
        
        uint32_t pc = 0x100;
        uint32_t target = 0x200;
        
        // Train once: Weakly Not Taken -> Weakly Taken
        train_branch(pc, true, target);
        check_prediction(pc, true, target, "After 1 taken");
        
        // Train again: Weakly Taken -> Strongly Taken
        train_branch(pc, true, target);
        check_prediction(pc, true, target, "After 2 taken (strong)");
    }
    
    void test_training_to_not_taken() {
        
        uint32_t pc = 0x80;  // Index [7:2] = 0b100000 = 32 (different from 0x100=0)
        uint32_t target = 0x180;
        
        // First get to Strongly Taken
        train_branch(pc, true, target);
        train_branch(pc, true, target);
        check_prediction(pc, true, target, "Strongly taken");
        
        // Train not taken: Strongly Taken -> Weakly Taken
        train_branch(pc, false, target);  // Keep target even when not taken
        check_prediction(pc, true, target, "After 1 not taken (still weak taken)");
        
        // Train not taken again: Weakly Taken -> Weakly Not Taken
        train_branch(pc, false, target);  // Keep target
        check_prediction(pc, false, 0, "After 2 not taken");
    }
    
    void test_multiple_branches() {
        
        // Use PCs with different BTB indices (bits [7:2])
        uint32_t pc1 = 0x110;  // Index = 0b000100 = 4
        uint32_t pc2 = 0x120;  // Index = 0b001000 = 8
        uint32_t target1 = 0x210;
        uint32_t target2 = 0x220;
        
        // Train two different branches (need 2 takens to reach Weakly Taken)
        train_branch(pc1, true, target1);
        train_branch(pc1, true, target1);
        train_branch(pc2, true, target2);
        train_branch(pc2, true, target2);
        
        // Check both are predicted correctly
        check_prediction(pc1, true, target1, "Branch 1");
        check_prediction(pc2, true, target2, "Branch 2");
    }
    
    void test_jump_updates() {
        
        uint32_t pc = 0x500;
        uint32_t target = 0x600;
        
        // Jumps should update BTB
        dut->program_counter_execute = pc;
        dut->branch_target_execute = target;
        dut->is_jump_execute = 1;
        tick();
        dut->is_jump_execute = 0;
        eval();
        
        // Should predict taken with correct target
        check_prediction(pc, true, target, "After jump");
    }
};

TEST_CASE("Branch Predictor") {
BranchPredictorTestbench tb;
        
        tb.reset();
        tb.test_initial_state();
        tb.test_training_to_taken();
        tb.test_training_to_not_taken();
        tb.test_multiple_branches();
        tb.test_jump_updates();
}
