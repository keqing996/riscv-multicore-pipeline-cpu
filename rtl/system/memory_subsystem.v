`timescale 1ns / 1ps

module memory_subsystem (
    input wire clk,
    input wire rst_n,

    // I-Cache Interface
    input wire [31:0] icache_mem_addr,
    input wire        icache_mem_req,
    output wire [31:0] icache_mem_rdata,
    output wire       icache_mem_ready,

    // D-Cache Interface
    input wire [31:0] dcache_mem_addr,
    input wire [31:0] dcache_mem_wdata,
    input wire [3:0]  dcache_mem_be,
    input wire        dcache_mem_we,
    input wire        dcache_mem_req,
    output wire [31:0] dcache_mem_rdata,
    output wire       dcache_mem_ready
);

    // Instantiate Main Memory (Unified)
    main_memory u_main_memory (
        .clk(clk),
        // Port A: Instruction
        .address_a(icache_mem_addr),
        .read_data_a(icache_mem_rdata),
        // Port B: Data
        .address_b(dcache_mem_addr),
        .write_data_b(dcache_mem_wdata),
        .write_enable_b(dcache_mem_we),
        .byte_enable_b(dcache_mem_be),
        .read_data_b(dcache_mem_rdata)
    );

    // Instruction Memory Latency Logic (Port A)
    reg [2:0] imem_wait_counter;
    reg imem_ready_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_wait_counter <= 0;
            imem_ready_reg <= 0;
        end else begin
            if (icache_mem_req) begin
                if (imem_wait_counter < 2) begin // 2 cycle latency
                    imem_wait_counter <= imem_wait_counter + 1;
                    imem_ready_reg <= 0;
                end else begin
                    // Assert ready for one cycle, then reset counter
                    imem_ready_reg <= 1;
                    imem_wait_counter <= 0;
                end
            end else begin
                imem_wait_counter <= 0;
                imem_ready_reg <= 0;
            end
        end
    end
    assign icache_mem_ready = imem_ready_reg;

    // Data Memory Latency Logic (Port B)
    reg [2:0] dmem_wait_counter;
    reg dmem_ready_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_wait_counter <= 0;
            dmem_ready_reg <= 0;
        end else if (dcache_mem_req) begin
            if (dmem_wait_counter < 2) begin // 2 cycle latency
                dmem_wait_counter <= dmem_wait_counter + 1;
                dmem_ready_reg <= 0;
            end else begin
                // Assert ready for one cycle, then reset counter
                dmem_ready_reg <= 1;
                dmem_wait_counter <= 0;
            end
        end else begin
            dmem_wait_counter <= 0;
            dmem_ready_reg <= 0;
        end
    end
    assign dcache_mem_ready = dmem_ready_reg;

endmodule
