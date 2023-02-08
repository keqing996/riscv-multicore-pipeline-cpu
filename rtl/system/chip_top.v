`timescale 1ns / 1ps

module chip_top (
    input wire clk,
    input wire rst_n,
    output wire [31:0] pc_out,
    output wire [31:0] instr_out,
    output wire [31:0] alu_res_out
);

    wire [31:0] instruction;
    wire [31:0] program_counter_address;
    wire instruction_grant;

    // I-Cache Signals
    wire [31:0] icache_memory_address;
    wire icache_memory_request;
    wire [31:0] icache_memory_read_data;
    wire icache_memory_ready;
    wire icache_stall_cpu;

    // Data Memory Signals (CPU <-> D-Cache)
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire [3:0]  dmem_be;
    wire        dmem_we;
    wire        dmem_re;
    wire [31:0] dmem_rdata;
    wire        dmem_busy;

    // D-Cache <-> Main Memory Signals
    wire [31:0] dcache_mem_addr;
    wire [31:0] dcache_mem_wdata;
    wire [3:0]  dcache_mem_be;
    wire        dcache_mem_we;
    wire        dcache_mem_req;
    wire [31:0] dcache_mem_rdata;
    wire        dcache_mem_ready;

    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .instruction(instruction),
        .instruction_grant(!icache_stall_cpu), // Grant when not stalled
        .program_counter_address(program_counter_address),
        // Data Memory Interface
        .data_memory_address(dmem_addr),
        .data_memory_write_data_out(dmem_wdata),
        .data_memory_byte_enable_out(dmem_be),
        .data_memory_write_enable_out(dmem_we),
        .data_memory_read_enable_out(dmem_re),
        .data_memory_read_data_in(dmem_rdata),
        .data_memory_busy(dmem_busy)
    );

    instruction_cache u_instruction_cache (
        .clk(clk),
        .rst_n(rst_n),
        .program_counter_address(program_counter_address),
        .instruction(instruction),
        .stall_cpu(icache_stall_cpu),
        .instruction_memory_address(icache_memory_address),
        .instruction_memory_request(icache_memory_request),
        .instruction_memory_read_data(icache_memory_read_data),
        .instruction_memory_ready(icache_memory_ready)
    );

    data_cache u_data_cache (
        .clk(clk),
        .rst_n(rst_n),
        // CPU Interface
        .cpu_address(dmem_addr),
        .cpu_write_data(dmem_wdata),
        .cpu_byte_enable(dmem_be),
        .cpu_write_enable(dmem_we),
        .cpu_read_enable(dmem_re),
        .cpu_read_data(dmem_rdata),
        .stall_cpu(dmem_busy),
        // Memory Interface
        .mem_address(dcache_mem_addr),
        .mem_write_data(dcache_mem_wdata),
        .mem_byte_enable(dcache_mem_be),
        .mem_write_enable(dcache_mem_we),
        .mem_request(dcache_mem_req),
        .mem_read_data(dcache_mem_rdata),
        .mem_ready(dcache_mem_ready)
    );

    memory_subsystem u_memory_subsystem (
        .clk(clk),
        .rst_n(rst_n),
        // I-Cache Interface
        .icache_mem_addr(icache_memory_address),
        .icache_mem_req(icache_memory_request),
        .icache_mem_rdata(icache_memory_read_data),
        .icache_mem_ready(icache_memory_ready),
        // D-Cache Interface
        .dcache_mem_addr(dcache_mem_addr),
        .dcache_mem_wdata(dcache_mem_wdata),
        .dcache_mem_be(dcache_mem_be),
        .dcache_mem_we(dcache_mem_we),
        .dcache_mem_req(dcache_mem_req),
        .dcache_mem_rdata(dcache_mem_rdata),
        .dcache_mem_ready(dcache_mem_ready)
    );

    // Expose signals for observation
    assign pc_out = program_counter_address;
    assign instr_out = instruction;
    assign alu_res_out = u_core.u_backend.alu_result_execute; // Or whatever signal we want to trace

endmodule
