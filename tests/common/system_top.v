`timescale 1ns / 1ps

module system_top (
    input wire clk,
    input wire rst_n,
    output wire [31:0] pc_out,
    output wire [31:0] instr_out,
    output wire [31:0] alu_res_out
);

    wire [31:0] instr;
    wire [31:0] pc_addr;
    wire instr_gnt;

    // I-Cache Signals
    wire [31:0] icache_mem_addr;
    wire icache_mem_req;
    wire [31:0] icache_mem_rdata;
    wire icache_mem_ready;
    wire icache_stall;

    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .instr(instr),
        .instr_gnt(!icache_stall), // Grant when not stalled
        .pc_addr(pc_addr)
    );

    icache u_icache (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(pc_addr),
        .cpu_instr(instr),
        .cpu_stall(icache_stall),
        .mem_addr(icache_mem_addr),
        .mem_req(icache_mem_req),
        .mem_rdata(icache_mem_rdata),
        .mem_ready(icache_mem_ready)
    );

    // Instantiate IMEM (Backing Store)
    imem u_imem (
        .addr(icache_mem_addr),
        .data(icache_mem_rdata)
    );

    reg [2:0] mem_wait_counter;
    reg mem_ready_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wait_counter <= 0;
            mem_ready_reg <= 0;
        end else begin
            if (icache_mem_req) begin
                if (mem_wait_counter < 3) begin // 3 cycle latency
                    mem_wait_counter <= mem_wait_counter + 1;
                    mem_ready_reg <= 0;
                end else begin
                    mem_ready_reg <= 1;
                end
            end else begin
                mem_wait_counter <= 0;
                mem_ready_reg <= 0;
            end
        end
    end
    
    // Better Latency Logic:
    reg [31:0] last_mem_addr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wait_counter <= 0;
            mem_ready_reg <= 0;
            last_mem_addr <= 32'hFFFFFFFF;
        end else begin
            if (icache_mem_req) begin
                if (icache_mem_addr != last_mem_addr) begin
                    // New request
                    mem_wait_counter <= 0;
                    mem_ready_reg <= 0;
                    last_mem_addr <= icache_mem_addr;
                end else begin
                    // Continuing request
                    if (mem_wait_counter < 2) begin // 2 cycle latency per word
                        mem_wait_counter <= mem_wait_counter + 1;
                        mem_ready_reg <= 0;
                    end else begin
                        mem_ready_reg <= 1;
                    end
                end
            end else begin
                mem_wait_counter <= 0;
                mem_ready_reg <= 0;
                // Don't reset last_mem_addr so we don't trigger on 0
            end
        end
    end

    assign icache_mem_ready = mem_ready_reg;

    // Expose signals for observation
    assign pc_out = pc_addr;
    assign instr_out = instr;
    assign alu_res_out = u_core.alu_result_ex; // Or whatever signal we want to trace

    // Memory Initialization
    // We use a parameter or a fixed filename. Cocotb will copy the specific hex file to "program.hex"
    initial begin
        $readmemh("program.hex", u_imem.memory);
        // Load program into DMEM as well (for .rodata and .data)
        // Accessing dmem inside core
        $readmemh("program.hex", u_core.u_dmem.memory);
    end

endmodule
