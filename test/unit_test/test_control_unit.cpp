#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "doctest.h"
#include "tb_base.h"
#include "Vcontrol_unit.h"
#include <map>
#include <string>

/**
 * Control Unit Testbench
 * Generates all control signals based on opcode and funct3
 */
class ControlUnitTestbench : public TestbenchBase<Vcontrol_unit> {
public:
    ControlUnitTestbench() : TestbenchBase<Vcontrol_unit>(false) {
    }
    
    void check(uint8_t opcode, uint8_t funct3, uint8_t rs1, 
               const std::map<std::string, uint8_t>& expected, const char* name) {
        dut->opcode = opcode;
        dut->function_3 = funct3;
        dut->rs1_index = rs1;
        eval();
        
        for (const auto& sig : expected) {
            uint8_t got = 0;
            if (sig.first == "register_write_enable") got = dut->register_write_enable;
            else if (sig.first == "alu_operation_code") got = dut->alu_operation_code;
            else if (sig.first == "alu_source_select") got = dut->alu_source_select;
            else if (sig.first == "memory_write_enable") got = dut->memory_write_enable;
            else if (sig.first == "memory_read_enable") got = dut->memory_read_enable;
            else if (sig.first == "memory_to_register_select") got = dut->memory_to_register_select;
            else if (sig.first == "branch") got = dut->branch;
            else if (sig.first == "jump") got = dut->jump;
            else if (sig.first == "alu_source_a_select") got = dut->alu_source_a_select;
            else if (sig.first == "csr_write_enable") got = dut->csr_write_enable;
            else if (sig.first == "csr_to_register_select") got = dut->csr_to_register_select;
            
            CHECK(got == sig.second);
        }
    }
    
    void test_r_type() {
        check(0b0110011, 0, 0, {
            {"register_write_enable", 1},
            {"alu_operation_code", 0b010},
            {"alu_source_select", 0},
            {"memory_write_enable", 0},
            {"branch", 0},
            {"jump", 0}
        }, "R-Type");
    }
    
    void test_i_type() {
        check(0b0010011, 0, 0, {
            {"register_write_enable", 1},
            {"alu_operation_code", 0b011},
            {"alu_source_select", 1},
            {"memory_write_enable", 0}
        }, "I-Type");
    }
    
    void test_load() {
        check(0b0000011, 0, 0, {
            {"register_write_enable", 1},
            {"memory_read_enable", 1},
            {"memory_to_register_select", 1},
            {"alu_source_select", 1},
            {"alu_operation_code", 0b000}
        }, "Load");
    }
    
    void test_store() {
        check(0b0100011, 0, 0, {
            {"memory_write_enable", 1},
            {"alu_source_select", 1},
            {"register_write_enable", 0},
            {"alu_operation_code", 0b000}
        }, "Store");
    }
    
    void test_branch() {
        check(0b1100011, 0, 0, {
            {"branch", 1},
            {"alu_operation_code", 0b001},
            {"register_write_enable", 0}
        }, "Branch");
    }
    
    void test_jal() {
        check(0b1101111, 0, 0, {
            {"jump", 1},
            {"register_write_enable", 1},
            {"alu_source_select", 0}
        }, "JAL");
    }
    
    void test_jalr() {
        check(0b1100111, 0, 0, {
            {"jump", 1},
            {"register_write_enable", 1},
            {"alu_source_select", 1},
            {"alu_operation_code", 0b000}
        }, "JALR");
    }
    
    void test_lui() {
        check(0b0110111, 0, 0, {
            {"register_write_enable", 1},
            {"alu_source_select", 1},
            {"alu_operation_code", 0b100}
        }, "LUI");
    }
    
    void test_auipc() {
        check(0b0010111, 0, 0, {
            {"register_write_enable", 1},
            {"alu_source_select", 1},
            {"alu_source_a_select", 1},
            {"alu_operation_code", 0b000}
        }, "AUIPC");
    }
    
    void test_csr() {
        check(0b1110011, 0b001, 0, {
            {"register_write_enable", 1},
            {"csr_write_enable", 1},
            {"csr_to_register_select", 1}
        }, "CSRRW");
    }
};

TEST_CASE("Control Unit") {
ControlUnitTestbench tb;
        
        tb.test_r_type();
        tb.test_i_type();
        tb.test_load();
        tb.test_store();
        tb.test_branch();
        tb.test_jal();
        tb.test_jalr();
        tb.test_lui();
        tb.test_auipc();
        tb.test_csr();
}
