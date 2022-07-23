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

    // Instantiate Core
    // Note: dmem is instantiated inside core.v in this design
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .instr(instr),
        .pc_addr(pc_addr)
    );

    // Instantiate IMEM
    imem u_imem (
        .addr(pc_addr),
        .data(instr)
    );

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
