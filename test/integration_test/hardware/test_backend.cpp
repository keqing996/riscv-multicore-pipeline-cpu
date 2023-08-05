#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
// Test: Backend Module Stall Handling
// Tests two scenarios:
// 1. Instruction fetch stall (instruction_grant=0): ID/EX gets bubble, other stages proceed
// 2. Data bus stall (bus_busy=1): Entire pipeline freezes

#include <Vbackend.h>
#include <Vbackend___024root.h>

class BackendTestbench : public ClockedTestbench<Vbackend> {
public:
    void set_clk(uint8_t value) override {
        dut->clk = value;
    }

    void do_reset() {
        dut->rst_n = 0;
        tick();
        tick();
        dut->rst_n = 1;
        tick();
    }

    void setup_inputs() {
        dut->if_id_program_counter = 0;
        dut->if_id_instruction = 0x00000013; // NOP
        dut->if_id_prediction_taken = 0;
        dut->if_id_prediction_target = 0;
        dut->instruction_grant = 1;
        dut->bus_read_data = 0;
        dut->bus_busy = 0;
        dut->timer_interrupt_request = 0;
        dut->hart_id = 0;
    }

    void test_instruction_stall() {
        // Test 1: Feed Instruction 1 (ADDI x1, x0, 10)
        dut->if_id_instruction = 0x00a00093;
        dut->if_id_program_counter = 4;
        dut->instruction_grant = 1;
        
        tick();
        // End of Cycle 1: ADDI x1 is latched into ID/EX
        
        // Test 2: Stall Fetch (instruction_grant = 0)
        dut->instruction_grant = 0;
        dut->if_id_instruction = 0x01400113; // ADDI x2 (waiting)
        dut->if_id_program_counter = 8;
        
        tick();
        eval();
        // End of Cycle 2: ID/EX should be bubbled (reg_write=0), EX/MEM should have valid instruction
        
        CHECK(dut->rootp->backend__DOT__id_ex_register_write_enable == 0);
        CHECK(dut->rootp->backend__DOT__ex_mem_register_write_enable == 1);
        CHECK(dut->rootp->backend__DOT__ex_mem_rd_index == 1);
        
        tick();
        eval();
        // End of Cycle 3: EX/MEM should now have the bubble, MEM/WB should have ADDI x1
        
        CHECK(dut->rootp->backend__DOT__ex_mem_register_write_enable == 0);
        CHECK(dut->rootp->backend__DOT__mem_wb_register_write_enable == 1);
        CHECK(dut->rootp->backend__DOT__mem_wb_rd_index == 1);
        
        // Release Stall
        dut->instruction_grant = 1;
        tick();
        eval();
        // End of Cycle 4: ADDI x2 should now be latched into ID/EX
        
        CHECK(dut->rootp->backend__DOT__id_ex_register_write_enable == 1);
        CHECK(dut->rootp->backend__DOT__id_ex_rd_index == 2);
    }

    void test_data_stall() {
        // Feed three instructions into the pipeline
        
        // Cycle 1: ADDI x1, x0, 10 -> ID
        dut->if_id_instruction = 0x00a00093;
        dut->if_id_program_counter = 4;
        tick();
        
        // Cycle 2: ADDI x2, x0, 20 -> ID (Instr 1 -> EX)
        dut->if_id_instruction = 0x01400113;
        dut->if_id_program_counter = 8;
        tick();
        
        // Cycle 3: ADDI x3, x0, 30 -> ID (Instr 2 -> EX, Instr 1 -> MEM)
        dut->if_id_instruction = 0x01e00193;
        dut->if_id_program_counter = 12;
        tick();
        
        // End of Cycle 3: MEM=Instr1, EX=Instr2, ID=Instr3
        
        // Cycle 4: Assert Data Stall (bus_busy = 1)
        dut->bus_busy = 1;
        tick();
        eval();
        
        // Everything should be FROZEN
        CHECK(dut->rootp->backend__DOT__mem_wb_rd_index == 1);
        CHECK(dut->rootp->backend__DOT__ex_mem_rd_index == 2);
        CHECK(dut->rootp->backend__DOT__id_ex_rd_index == 3);
        
        // Cycle 5: Release Stall
        dut->bus_busy = 0;
        tick();
        eval();
        
        // Pipeline should advance
        CHECK(dut->rootp->backend__DOT__mem_wb_rd_index == 2);
        CHECK(dut->rootp->backend__DOT__ex_mem_rd_index == 3);
    }
};

TEST_CASE("Backend") {
BackendTestbench tb;
    
    // Test 1: Instruction Stall
    tb.do_reset();
    tb.setup_inputs();
    tb.test_instruction_stall();

    // Test 2: Data Stall
    tb.do_reset();
    tb.setup_inputs();
    tb.test_data_stall();
}
