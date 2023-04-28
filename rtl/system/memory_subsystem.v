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
    reg [31:0] last_imem_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_wait_counter <= 0;
            imem_ready_reg <= 0;
            last_imem_addr <= 32'hFFFFFFFF;
        end else begin
            if (icache_mem_req) begin
                if (icache_mem_addr != last_imem_addr) begin
                    imem_wait_counter <= 0;
                    imem_ready_reg <= 0;
                    last_imem_addr <= icache_mem_addr;
                end else if (imem_wait_counter < 2) begin // 2 cycle latency
                    imem_wait_counter <= imem_wait_counter + 1;
                    imem_ready_reg <= 0;
                end else begin
                    imem_ready_reg <= 1;
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
    reg [31:0] last_dmem_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_wait_counter <= 0;
            dmem_ready_reg <= 0;
            last_dmem_addr <= 32'hFFFFFFFF;
        end else if (dcache_mem_req) begin
            if (dcache_mem_addr != last_dmem_addr) begin
                dmem_wait_counter <= 0;
                dmem_ready_reg <= 0;
                last_dmem_addr <= dcache_mem_addr;
            end else if (dmem_wait_counter < 2) begin // 2 cycle latency
                dmem_wait_counter <= dmem_wait_counter + 1;
                dmem_ready_reg <= 0;
            end else begin
                dmem_ready_reg <= 1;
            end
        end else begin
            dmem_wait_counter <= 0;
            dmem_ready_reg <= 0;
        end
    end
    assign dcache_mem_ready = dmem_ready_reg;

    // Memory Initialization
    reg [1023:0] hex_file_path;
    initial begin
        // Force first instruction to be NOP to debug
        u_main_memory.memory[0] = 32'h00000013; 
        
        if ($value$plusargs("PROGRAM_HEX=%s", hex_file_path)) begin
            $display("Loading memory from %0s...", hex_file_path);
            $readmemh(hex_file_path, u_main_memory.memory);
        end else begin
            $display("Loading memory from program.hex...");
            $readmemh("program.hex", u_main_memory.memory);
        end
        $display("Memory[0] = %h", u_main_memory.memory[0]);
        $display("Memory[4] = %h", u_main_memory.memory[4]);
    end

endmodule