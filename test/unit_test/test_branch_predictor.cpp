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
    BranchPredictorTestbench() : ClockedTestbench<Vbranch_predictor>(100, true, "branch_predictor_trace.vcd") {
        dut->rst_n = 0;
        dut->program_counter_fetch = 0;
        dut->program_counter_execute = 0;
        dut->branch_taken_execute = 0;
        dut->branch_target_execute = 0;
        dut->is_branch_execute = 0;
        dut->is_jump_execute = 0;
        TB_LOG("Branch Predictor Testbench initialized");
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
        TB_ASSERT_EQ(dut->prediction_taken, exp_taken ? 1 : 0, (prefix + " prediction_taken").c_str());
        if (exp_taken) {
            TB_ASSERT_EQ(dut->prediction_target, exp_target, (prefix + " prediction_target").c_str());
        }
    }
    
    void test_initial_state() {
        TB_LOG("Test: Initial prediction (not taken)");
        
        // BHT starts at Weakly Not Taken
        check_prediction(0x100, false, 0, "Initial state");
    }
    
    void test_training_to_taken() {
        TB_LOG("Test: Training from not taken to taken");
        
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
        TB_LOG("Test: Training from taken back to not taken");
        
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
        TB_LOG("Test: Multiple branch entries");
        
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
        TB_LOG("Test: Jump instruction updates");
        
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

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        BranchPredictorTestbench tb;
        
        tb.reset();
        tb.test_initial_state();
        tb.test_training_to_taken();
        tb.test_training_to_not_taken();
        tb.test_multiple_branches();
        tb.test_jump_updates();
        
        TB_LOG("All Branch Predictor tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
