`timescale 1ns / 1ps

module main_memory (
    input wire clk,
    
    // Port A (Instruction Fetch)
    input wire [31:0] address_a,
    output reg [31:0] read_data_a,

    // Port B (Data Access)
    input wire [31:0] address_b,
    input wire [31:0] write_data_b,
    input wire write_enable_b,
    input wire [3:0] byte_enable_b,
    output reg [31:0] read_data_b
);

    // 64KB Memory (16384 words)
    reg [31:0] memory [0:16383];

    // Port A: Read Only (Instruction)
    always @(posedge clk) begin
        // Word aligned access
        read_data_a <= memory[address_a[15:2]];
    end

    // Port B: Read/Write (Data)
    always @(posedge clk) begin
        if (write_enable_b) begin
            if (byte_enable_b[0]) memory[address_b[15:2]][7:0]   <= write_data_b[7:0];
            if (byte_enable_b[1]) memory[address_b[15:2]][15:8]  <= write_data_b[15:8];
            if (byte_enable_b[2]) memory[address_b[15:2]][23:16] <= write_data_b[23:16];
            if (byte_enable_b[3]) memory[address_b[15:2]][31:24] <= write_data_b[31:24];
        end
        read_data_b <= memory[address_b[15:2]];
    end

endmodule
