#include "tb_base.h"
#include "Vhazard_detection_unit.h"

/**
 * Hazard Detection Unit Testbench
 * Detects load-use hazards that require pipeline stall
 */
class HazardDetectionTestbench : public TestbenchBase<Vhazard_detection_unit> {
public:
    HazardDetectionTestbench() : TestbenchBase<Vhazard_detection_unit>(true, "hazard_detection_trace.vcd") {
        TB_LOG("Hazard Detection Unit Testbench initialized");
    }
    
    void check(uint8_t rs1_id, uint8_t rs2_id, uint8_t rd_ex, uint8_t mem_read_ex, uint8_t expected_stall, const char* name) {
        dut->rs1_index_decode = rs1_id;
        dut->rs2_index_decode = rs2_id;
        dut->rd_index_execute = rd_ex;
        dut->memory_read_enable_execute = mem_read_ex;
        eval();
        
        TB_ASSERT_EQ(dut->stall_pipeline, expected_stall, name);
    }
    
    void test_no_hazard() {
        TB_LOG("Test: No hazard conditions");
        check(1, 2, 3, 0, 0, "No Hazard (No Load)");
        check(1, 2, 3, 1, 0, "No Hazard (Load, No Dep)");
    }
    
    void test_load_use_hazard() {
        TB_LOG("Test: Load-use hazards");
        check(1, 2, 1, 1, 1, "Hazard on RS1");
        check(1, 2, 2, 1, 1, "Hazard on RS2");
        check(1, 1, 1, 1, 1, "Hazard on both RS1==RS2");
    }
    
    void test_x0_no_stall() {
        TB_LOG("Test: Never stall for x0");
        check(0, 2, 0, 1, 0, "x0 Hazard Check RS1");
        check(1, 0, 0, 1, 0, "x0 Hazard Check RS2");
        check(0, 0, 0, 1, 0, "x0 Hazard Check Both");
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    
    try {
        HazardDetectionTestbench tb;
        
        tb.test_no_hazard();
        tb.test_load_use_hazard();
        tb.test_x0_no_stall();
        
        TB_LOG("All Hazard Detection Unit tests PASSED!");
        return 0;
        
    } catch (const std::exception& e) {
        TB_ERROR(e.what());
        return 1;
    }
}
