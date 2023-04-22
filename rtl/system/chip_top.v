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
    // Replaced by Bus Signals
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [3:0]  bus_be;
    wire        bus_we;
    wire        bus_re;
    wire [31:0] bus_rdata;
    wire        bus_busy;
    wire        timer_irq;

    // Bus Slave Signals
    // Slave 0: D-Cache
    wire [31:0] s0_addr;
    wire [31:0] s0_wdata;
    wire [3:0]  s0_be;
    wire        s0_we;
    wire        s0_en;
    wire [31:0] s0_rdata;
    wire        s0_ready;

    // Slave 1: UART
    wire [31:0] s1_addr;
    wire [31:0] s1_wdata;
    wire [3:0]  s1_be;
    wire        s1_we;
    wire        s1_en;
    wire [31:0] s1_rdata;
    wire        s1_ready;

    // Slave 2: Timer
    wire [31:0] s2_addr;
    wire [31:0] s2_wdata;
    wire [3:0]  s2_be;
    wire        s2_we;
    wire        s2_en;
    wire [31:0] s2_rdata;
    wire        s2_ready;

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
        // Bus Interface
        .bus_address(bus_addr),
        .bus_write_data(bus_wdata),
        .bus_byte_enable(bus_be),
        .bus_write_enable(bus_we),
        .bus_read_enable(bus_re),
        .bus_read_data(bus_rdata),
        .bus_busy(bus_busy),
        .timer_interrupt_request(timer_irq)
    );

    // Bus Ready Logic
    wire m0_ready;
    assign bus_busy = (bus_we || bus_re) && !m0_ready;

    bus_interconnect u_bus_interconnect (
        .clk(clk),
        .rst_n(rst_n),

        // Master 0 (Core 0)
        .m0_addr(bus_addr),
        .m0_wdata(bus_wdata),
        .m0_wstrb(bus_be),
        .m0_write(bus_we),
        .m0_enable(bus_we || bus_re),
        .m0_rdata(bus_rdata),
        .m0_ready(m0_ready),

        // Master 1 (Core 1 - Placeholder)
        .m1_addr(32'b0),
        .m1_wdata(32'b0),
        .m1_wstrb(4'b0),
        .m1_write(1'b0),
        .m1_enable(1'b0),
        .m1_rdata(),
        .m1_ready(),

        // Slave 0 (D-Cache)
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
    
    // Bus Busy Logic (Moved up)
    // wire bus_busy_n;
    // assign bus_busy = (bus_we || bus_re) && !bus_busy_n;

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
        // CPU Interface (Connected to Bus Slave 0)
        .cpu_address(s0_addr),
        .cpu_write_data(s0_wdata),
        .cpu_byte_enable(s0_be),
        .cpu_write_enable(s0_we && s0_en),
        .cpu_read_enable(!s0_we && s0_en),
        .cpu_read_data(s0_rdata),
        .stall_cpu(dmem_busy_internal), // Cache says if it's busy
        // Memory Interface
        .mem_address(dcache_mem_addr),
        .mem_write_data(dcache_mem_wdata),
        .mem_byte_enable(dcache_mem_be),
        .mem_write_enable(dcache_mem_we),
        .mem_request(dcache_mem_req),
        .mem_read_data(dcache_mem_rdata),
        .mem_ready(dcache_mem_ready)
    );
    
    // D-Cache Ready Logic
    // Cache 'stall_cpu' is high when busy.
    // Bus expects 'ready' high when done.
    // So ready = !stall_cpu
    wire dmem_busy_internal;
    assign s0_ready = !dmem_busy_internal;

    // UART Instance (Slave 1)
    uart_simulator u_uart_simulator (
        .clk(clk),
        .write_enable(s1_we && s1_en),
        .address(s1_addr),
        .write_data(s1_wdata) 
    );
    // UART is always ready (combinatorial write)
    assign s1_ready = 1'b1;
    assign s1_rdata = 32'b0; // UART is write-only in this sim

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
    // Timer is always ready (combinatorial read/write)
    assign s2_ready = 1'b1;

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
