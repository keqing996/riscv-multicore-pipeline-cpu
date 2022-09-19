`timescale 1ns / 1ps

module system_top (
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

    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .instruction(instruction),
        .instruction_grant(!icache_stall_cpu), // Grant when not stalled
        .program_counter_address(program_counter_address)
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

    // Instantiate IMEM (Backing Store)
    instruction_memory u_instruction_memory (
        .address(icache_memory_address),
        .read_data(icache_memory_read_data)
    );

    reg [2:0] mem_wait_counter;
    reg mem_ready_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wait_counter <= 0;
            mem_ready_reg <= 0;
        end else begin
            if (icache_memory_request) begin
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
            if (icache_memory_request) begin
                if (icache_memory_address != last_mem_addr) begin
                    // New request
                    mem_wait_counter <= 0;
                    mem_ready_reg <= 0;
                    last_mem_addr <= icache_memory_address;
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

    assign icache_memory_ready = mem_ready_reg;

    // Expose signals for observation
    assign pc_out = program_counter_address;
    assign instr_out = instruction;
    assign alu_res_out = u_core.alu_result_execute; // Or whatever signal we want to trace

    // Memory Initialization
    // We use a parameter or a fixed filename. Cocotb will copy the specific hex file to "program.hex"
    initial begin
        $readmemh("program.hex", u_instruction_memory.memory);
        // Load program into DMEM as well (for .rodata and .data)
        // Accessing dmem inside core
        $readmemh("program.hex", u_core.u_data_memory.memory);
    end

endmodule
