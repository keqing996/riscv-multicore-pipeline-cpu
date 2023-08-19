#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vhazard_detection_unit.h"

/**
 * Hazard Detection Unit Testbench
 * Detects load-use hazards that require pipeline stall
 */
class HazardDetectionTestbench : public TestbenchBase<Vhazard_detection_unit> {
public:
    HazardDetectionTestbench() : TestbenchBase<Vhazard_detection_unit>(false) {
    }
    
    void check(uint8_t rs1_id, uint8_t rs2_id, uint8_t rd_ex, uint8_t mem_read_ex, uint8_t expected_stall, const char* name) {
        dut->rs1_index_decode = rs1_id;
        dut->rs2_index_decode = rs2_id;
        dut->rd_index_execute = rd_ex;
        dut->memory_read_enable_execute = mem_read_ex;
        eval();
        
        INFO(name);
        CHECK(dut->stall_pipeline == expected_stall);
    }
    
    void test_no_hazard() {
        check(1, 2, 3, 0, 0, "No Hazard (No Load)");
        check(1, 2, 3, 1, 0, "No Hazard (Load, No Dep)");
    }
    
    void test_load_use_hazard() {
        check(1, 2, 1, 1, 1, "Hazard on RS1");
        check(1, 2, 2, 1, 1, "Hazard on RS2");
        check(1, 1, 1, 1, 1, "Hazard on both RS1==RS2");
    }
    
    void test_x0_no_stall() {
        check(0, 2, 0, 1, 0, "x0 Hazard Check RS1");
        check(1, 0, 0, 1, 0, "x0 Hazard Check RS2");
        check(0, 0, 0, 1, 0, "x0 Hazard Check Both");
    }
};

TEST_CASE("Hazard Detection Unit") {
HazardDetectionTestbench tb;
        
        tb.test_no_hazard();
        tb.test_load_use_hazard();
        tb.test_x0_no_stall();
}
