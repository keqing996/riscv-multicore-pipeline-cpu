`timescale 1ns / 1ps

module core_tile (
    input wire clk,
    input wire rst_n,
    input wire [31:0] hart_id,

    // Bus Master Interface
    output wire [31:0] bus_addr,
    output wire [31:0] bus_wdata,
    output wire [3:0]  bus_be,
    output wire        bus_we,
    output wire        bus_req,
    input wire [31:0]  bus_rdata,
    input wire         bus_ready,

    // Interrupts
    input wire         timer_irq
);

    // Internal Signals
    wire [31:0] pc_addr;
    wire [31:0] instruction;
    wire        icache_stall;
    
    wire [31:0] core_bus_addr;
    wire [31:0] core_bus_wdata;
    wire [3:0]  core_bus_be;
    wire        core_bus_we;
    wire        core_bus_re;
    wire [31:0] core_bus_rdata;
    wire        dcache_stall;

    // I-Cache <-> Arbiter
    wire [31:0] icache_mem_addr;
    wire        icache_mem_req;
    wire [31:0] icache_mem_rdata;
    wire        icache_mem_ready;

    // D-Cache <-> Arbiter
    wire [31:0] dcache_mem_addr;
    wire [31:0] dcache_mem_wdata;
    wire [3:0]  dcache_mem_be;
    wire        dcache_mem_we;
    wire        dcache_mem_req;
    wire [31:0] dcache_mem_rdata;
    wire        dcache_mem_ready;

    // Core Instance
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .hart_id(hart_id),
        .instruction(instruction),
        .instruction_grant(!icache_stall), // Grant when I-Cache is not stalling
        .program_counter_address(pc_addr),
        
        // Data Interface (to D-Cache)
        .bus_address(core_bus_addr),
        .bus_write_data(core_bus_wdata),
        .bus_byte_enable(core_bus_be),
        .bus_write_enable(core_bus_we),
        .bus_read_enable(core_bus_re),
        .bus_read_data(core_bus_rdata),
        .bus_busy(dcache_stall), // Stall when D-Cache is busy (miss or write-through)
        
        .timer_interrupt_request(timer_irq)
    );

    // Instruction Cache
    l1_inst_cache u_icache (
        .clk(clk),
        .rst_n(rst_n),
        // CPU Interface
        .program_counter_address(pc_addr),
        .instruction(instruction),
        .stall_cpu(icache_stall),
        // Memory Interface (to Arbiter)
        .instruction_memory_address(icache_mem_addr),
        .instruction_memory_request(icache_mem_req),
        .instruction_memory_read_data(icache_mem_rdata),
        .instruction_memory_ready(icache_mem_ready)
    );

    // Data Cache
    l1_data_cache u_dcache (
        .clk(clk),
        .rst_n(rst_n),
        // CPU Interface
        .cpu_address(core_bus_addr),
        .cpu_write_data(core_bus_wdata),
        .cpu_byte_enable(core_bus_be),
        .cpu_write_enable(core_bus_we),
        .cpu_read_enable(core_bus_re),
        .cpu_read_data(core_bus_rdata),
        .stall_cpu(dcache_stall),
        // Memory Interface (to Arbiter)
        .mem_address(dcache_mem_addr),
        .mem_write_data(dcache_mem_wdata),
        .mem_byte_enable(dcache_mem_be),
        .mem_write_enable(dcache_mem_we),
        .mem_request(dcache_mem_req),
        .mem_read_data(dcache_mem_rdata),
        .mem_ready(dcache_mem_ready)
    );

    // L1 Arbiter
    l1_arbiter u_l1_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        
        // I-Cache Port
        .icache_addr(icache_mem_addr),
        .icache_req(icache_mem_req),
        .icache_rdata(icache_mem_rdata),
        .icache_ready(icache_mem_ready),
        
        // D-Cache Port
        .dcache_addr(dcache_mem_addr),
        .dcache_wdata(dcache_mem_wdata),
        .dcache_be(dcache_mem_be),
        .dcache_we(dcache_mem_we),
        .dcache_req(dcache_mem_req),
        .dcache_rdata(dcache_mem_rdata),
        .dcache_ready(dcache_mem_ready),
        
        // Master Interface (to System Bus)
        .m_addr(bus_addr),
        .m_wdata(bus_wdata),
        .m_be(bus_be),
        .m_we(bus_we),
        .m_req(bus_req),
        .m_rdata(bus_rdata),
        .m_ready(bus_ready)
    );

endmodule
