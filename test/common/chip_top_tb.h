#pragma once

#include "tb_base.h"

#include <Vchip_top.h>
#include <Vchip_top___024root.h>

#include <cstdlib>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

inline bool chip_top_trace_enabled_from_env() {
    const char* value = std::getenv("TRACE");
    return value != nullptr && value[0] != '\0' && std::string(value) != "0";
}

inline std::string chip_top_trace_filename_from_env() {
    const char* value = std::getenv("TRACE_FILE");
    return value != nullptr && value[0] != '\0' ? std::string(value) : "chip_top.vcd";
}

struct ChipTopSnapshot {
    uint32_t pc_if;
    uint32_t pc_id;
    uint32_t instruction_id;
    uint32_t pc_ex;
    uint32_t instruction;
    bool halted;
    bool stall_backend;
    bool stall_global;
    bool icache_stall;
    bool instruction_grant;
    bool flush_branch;
    bool flush_jump;
    bool flush_trap;

    std::string to_string() const {
        std::ostringstream os;
        os << "pc_if=0x" << std::hex << pc_if
           << " pc_id=0x" << pc_id
           << " instr_id=0x" << instruction_id
           << " pc_ex=0x" << pc_ex
           << " instr=0x" << instruction
           << std::dec
           << " halted=" << halted
           << " stall_backend=" << stall_backend
           << " stall_global=" << stall_global
           << " icache_stall=" << icache_stall
           << " instruction_grant=" << instruction_grant
           << " flush_branch=" << flush_branch
           << " flush_jump=" << flush_jump
           << " flush_trap=" << flush_trap;
        return os.str();
    }
};

class ChipTopTestbench : public ClockedTestbench<Vchip_top> {
public:
    ChipTopTestbench(
        bool enable_trace = chip_top_trace_enabled_from_env(),
        const std::string& trace_filename = chip_top_trace_filename_from_env())
        : ClockedTestbench<Vchip_top>(100, enable_trace, trace_filename) {
        dut->rst_n = 0;
    }

    void set_clk(uint8_t value) override {
        dut->clk = value;
    }

    void load_program(const std::vector<uint32_t>& program) {
        for (size_t i = 0; i < program.size(); i++) {
            dut->rootp->chip_top__DOT__u_memory_subsystem__DOT__u_main_memory__DOT__memory[i] = program[i];
        }
    }

    void load_binary(const std::string& bin_path) {
        load_program(read_binary_words(bin_path));
    }

    void reset(int reset_cycles = 20, int settle_cycles = 5) {
        dut->rst_n = 0;
        tick(reset_cycles);
        dut->rst_n = 1;
        tick(settle_cycles);
    }

    void do_reset() {
        reset();
    }

    bool run_until_halted(int max_cycles) {
        for (int i = 0; i < max_cycles; i++) {
            tick();
            if (is_halted()) {
                return true;
            }
        }
        std::cerr << "Timed out waiting for halt: " << snapshot().to_string() << std::endl;
        return false;
    }

    bool is_halted() const {
        return dut->halted_out;
    }

    bool is_ebreak() const {
        return is_halted();
    }

    uint32_t read_reg(int hart, int reg_idx) const {
        if (reg_idx < 0 || reg_idx >= 32) {
            return 0;
        }

        if (hart == 1) {
            return dut->rootp->chip_top__DOT__u_tile_1__DOT__u_core__DOT__u_backend__DOT__u_regfile__DOT__registers[reg_idx];
        }

        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_regfile__DOT__registers[reg_idx];
    }

    uint32_t read_reg(int reg_idx) const {
        return read_reg(0, reg_idx);
    }

    uint32_t read_register(int reg_idx) const {
        return read_reg(reg_idx);
    }

    uint32_t read_register_tile1(int reg_idx) const {
        return read_reg(1, reg_idx);
    }

    uint32_t read_mem_word(uint32_t byte_addr) const {
        return dut->rootp->chip_top__DOT__u_memory_subsystem__DOT__u_main_memory__DOT__memory[byte_addr / 4];
    }

    uint32_t read_memory_word(uint32_t byte_addr) const {
        return read_mem_word(byte_addr);
    }

    uint32_t read_csr_mcause(int hart = 0) const {
        if (hart == 1) {
            return dut->rootp->chip_top__DOT__u_tile_1__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mcause;
        }
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mcause;
    }

    uint32_t read_csr_mepc(int hart = 0) const {
        if (hart == 1) {
            return dut->rootp->chip_top__DOT__u_tile_1__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mepc;
        }
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mepc;
    }

    uint32_t read_csr_mtvec(int hart = 0) const {
        if (hart == 1) {
            return dut->rootp->chip_top__DOT__u_tile_1__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mtvec;
        }
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_control_status_register_file__DOT__mtvec;
    }

    uint32_t get_mcause() const {
        return read_csr_mcause();
    }

    uint32_t get_mepc() const {
        return read_csr_mepc();
    }

    uint32_t get_pc_ex(int hart = 0) const {
        if (hart == 1) {
            return dut->rootp->chip_top__DOT__u_tile_1__DOT__u_core__DOT__u_backend__DOT__id_ex_program_counter;
        }
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__id_ex_program_counter;
    }

    uint32_t get_pc_ex_tile1() const {
        return get_pc_ex(1);
    }

    uint32_t get_pc() const {
        return get_pc_ex();
    }

    uint32_t get_pc_if() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__program_counter_current;
    }

    uint32_t get_pc_id() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__if_id_program_counter;
    }

    uint32_t get_if_id_pc() const {
        return get_pc_id();
    }

    uint32_t get_instruction_id() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__if_id_instruction;
    }

    uint32_t get_instruction() const {
        return get_instruction_id();
    }

    uint32_t get_icache_instruction() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__instruction;
    }

    uint32_t get_instr() const {
        return get_icache_instruction();
    }

    uint8_t get_icache_state() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_icache__DOT__state;
    }

    bool get_icache_stall() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__icache_stall;
    }

    bool get_instruction_grant() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__instruction_grant_reg;
    }

    uint32_t get_grant() const {
        return get_instruction_grant();
    }

    bool get_stall_backend() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__stall_pipeline;
    }

    uint32_t get_stall() const {
        return get_stall_backend();
    }

    bool get_stall_global() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__stall_global;
    }

    bool get_flush_branch() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__flush_due_to_branch;
    }

    bool get_flush_jump() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__flush_due_to_jump;
    }

    bool get_flush_trap() const {
        return dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_frontend__DOT__flush_due_to_trap;
    }

    bool is_ecall() const {
        return get_instruction() == 0x00000073;
    }

    ChipTopSnapshot snapshot() const {
        return {
            get_pc_if(),
            get_pc_id(),
            get_instruction_id(),
            get_pc_ex(),
            get_icache_instruction(),
            is_halted(),
            get_stall_backend(),
            get_stall_global(),
            get_icache_stall(),
            get_instruction_grant(),
            get_flush_branch(),
            get_flush_jump(),
            get_flush_trap(),
        };
    }

private:
    static std::vector<uint32_t> read_binary_words(const std::string& bin_path) {
        std::ifstream file(bin_path, std::ios::binary | std::ios::ate);
        if (!file.is_open()) {
            throw std::runtime_error("Failed to open binary file: " + bin_path);
        }

        std::streamsize size = file.tellg();
        file.seekg(0, std::ios::beg);

        std::vector<uint8_t> buffer(size);
        if (!file.read(reinterpret_cast<char*>(buffer.data()), size)) {
            throw std::runtime_error("Failed to read binary file: " + bin_path);
        }

        while (buffer.size() % 4 != 0) {
            buffer.push_back(0);
        }

        std::vector<uint32_t> program;
        program.reserve(buffer.size() / 4);

        for (size_t i = 0; i < buffer.size(); i += 4) {
            program.push_back(static_cast<uint32_t>(buffer[i]) |
                              (static_cast<uint32_t>(buffer[i + 1]) << 8) |
                              (static_cast<uint32_t>(buffer[i + 2]) << 16) |
                              (static_cast<uint32_t>(buffer[i + 3]) << 24));
        }

        return program;
    }
};
