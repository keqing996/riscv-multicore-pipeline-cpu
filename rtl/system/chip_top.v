`timescale 1ns / 1ps

module chip_top (
    input wire clk,
    input wire rst_n,
    output wire [31:0] pc_out,
    output wire [31:0] instr_out,
    output wire [31:0] alu_res_out
);

    // Bus Signals
    // Master 0 (Tile 0)
    wire [31:0] m0_addr;
    wire [31:0] m0_wdata;
    wire [3:0]  m0_be;
    wire        m0_we;
    wire        m0_req;
    wire [31:0] m0_rdata;
    wire        m0_ready;

    // Master 1 (Tile 1)
    wire [31:0] m1_addr;
    wire [31:0] m1_wdata;
    wire [3:0]  m1_be;
    wire        m1_we;
    wire        m1_req;
    wire [31:0] m1_rdata;
    wire        m1_ready;

    // Slave 0 (L2 Cache)
    wire [31:0] s0_addr;
    wire [31:0] s0_wdata;
    wire [3:0]  s0_be;
    wire        s0_we;
    wire        s0_en;
    wire [31:0] s0_rdata;
    wire        s0_ready;

    // Slave 1 (UART)
    wire [31:0] s1_addr;
    wire [31:0] s1_wdata;
    wire [3:0]  s1_be;
    wire        s1_we;
    wire        s1_en;
    wire [31:0] s1_rdata;
    wire        s1_ready;

    // Slave 2 (Timer)
    wire [31:0] s2_addr;
    wire [31:0] s2_wdata;
    wire [3:0]  s2_be;
    wire        s2_we;
    wire        s2_en;
    wire [31:0] s2_rdata;
    wire        s2_ready;

    // Interrupts
    wire timer_irq;

    // Core Tile 0 (Hart 0)
    core_tile u_tile_0 (
        .clk(clk),
        .rst_n(rst_n),
        .hart_id(32'd0),
        .bus_addr(m0_addr),
        .bus_wdata(m0_wdata),
        .bus_be(m0_be),
        .bus_we(m0_we),
        .bus_req(m0_req),
        .bus_rdata(m0_rdata),
        .bus_ready(m0_ready),
        .timer_irq(timer_irq)
    );

    // Core Tile 1 (Hart 1)
    core_tile u_tile_1 (
        .clk(clk),
        .rst_n(rst_n),
        .hart_id(32'd1),
        .bus_addr(m1_addr),
        .bus_wdata(m1_wdata),
        .bus_be(m1_be),
        .bus_we(m1_we),
        .bus_req(m1_req),
        .bus_rdata(m1_rdata),
        .bus_ready(m1_ready),
        .timer_irq(timer_irq)
    );

    // Bus Interconnect
    bus_interconnect u_bus_interconnect (
        .clk(clk),
        .rst_n(rst_n),

        // Master 0
        .m0_addr(m0_addr),
        .m0_wdata(m0_wdata),
        .m0_wstrb(m0_be),
        .m0_write(m0_we),
        .m0_enable(m0_req),
        .m0_rdata(m0_rdata),
        .m0_ready(m0_ready),

        // Master 1
        .m1_addr(m1_addr),
        .m1_wdata(m1_wdata),
        .m1_wstrb(m1_be),
        .m1_write(m1_we),
        .m1_enable(m1_req),
        .m1_rdata(m1_rdata),
        .m1_ready(m1_ready),

        // Slave 0 (L2 Cache)
        .s0_addr(s0_addr),
        .s0_wdata(s0_wdata),
        .s0_wstrb(s0_be),
        .s0_write(s0_we),
        .s0_enable(s0_en),
        .s0_rdata(s0_rdata),
        .s0_ready(s0_ready),

        // Slave 1 (UART)
        .s1_addr(s1_addr),
        .s1_wdata(s1_wdata),
        .s1_wstrb(s1_be),
        .s1_write(s1_we),
        .s1_enable(s1_en),
        .s1_rdata(s1_rdata),
        .s1_ready(s1_ready),

        // Slave 2 (Timer)
        .s2_addr(s2_addr),
        .s2_wdata(s2_wdata),
        .s2_wstrb(s2_be),
        .s2_write(s2_we),
        .s2_enable(s2_en),
        .s2_rdata(s2_rdata),
        .s2_ready(s2_ready)
    );

    // L2 Cache <-> Memory Signals
    wire [31:0] l2_mem_addr;
    wire [31:0] l2_mem_wdata;
    wire [3:0]  l2_mem_be;
    wire        l2_mem_we;
    wire        l2_mem_req;
    wire [31:0] l2_mem_rdata;
    wire        l2_mem_ready;

    // L2 Cache
    l2_cache u_l2_cache (
        .clk(clk),
        .rst_n(rst_n),
        // Bus Slave Interface
        .s_addr(s0_addr),
        .s_wdata(s0_wdata),
        .s_be(s0_be),
        .s_we(s0_we),
        .s_en(s0_en),
        .s_rdata(s0_rdata),
        .s_ready(s0_ready),
        // Memory Interface
        .mem_addr(l2_mem_addr),
        .mem_wdata(l2_mem_wdata),
        .mem_be(l2_mem_be),
        .mem_we(l2_mem_we),
        .mem_req(l2_mem_req),
        .mem_rdata(l2_mem_rdata),
        .mem_ready(l2_mem_ready)
    );

    // Memory Subsystem (Main Memory)
    // We use Port B (D-Cache Port) for L2 connection as it supports R/W
    // Port A (I-Cache Port) is unused
    memory_subsystem u_memory_subsystem (
        .clk(clk),
        .rst_n(rst_n),
        // Port A (Unused)
        .icache_mem_addr(32'b0),
        .icache_mem_req(1'b0),
        .icache_mem_rdata(),
        .icache_mem_ready(),
        // Port B (Connected to L2)
        .dcache_mem_addr(l2_mem_addr),
        .dcache_mem_wdata(l2_mem_wdata),
        .dcache_mem_be(l2_mem_be),
        .dcache_mem_we(l2_mem_we),
        .dcache_mem_req(l2_mem_req),
        .dcache_mem_rdata(l2_mem_rdata),
        .dcache_mem_ready(l2_mem_ready)
    );

    // UART Instance (Slave 1)
    uart_simulator u_uart_simulator (
        .clk(clk),
        .write_enable(s1_we && s1_en),
        .address(s1_addr),
        .write_data(s1_wdata) 
    );
    assign s1_ready = 1'b1;
    assign s1_rdata = 32'b0;

    // Timer Instance (Slave 2)
    timer u_timer (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(s2_we && s2_en),
        .address(s2_addr),
        .write_data(s2_wdata), 
        .read_data(s2_rdata),
        .interrupt_request(timer_irq)
    );
    assign s2_ready = 1'b1;

    // Expose signals for observation (from Tile 0)
    assign pc_out = u_tile_0.pc_addr;
    assign instr_out = u_tile_0.instruction;
    assign alu_res_out = u_tile_0.u_core.u_backend.alu_result_execute;

endmodule
