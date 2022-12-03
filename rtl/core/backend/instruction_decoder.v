module instruction_decoder (
    input wire [31:0] instruction,
    output wire [6:0] opcode,
    output wire [2:0] function_3,
    output wire [6:0] function_7,
    output wire [4:0] rd,
    output wire [4:0] rs1,
    output wire [4:0] rs2
);

    assign opcode     = instruction[6:0];
    assign rd         = instruction[11:7];
    assign function_3 = instruction[14:12];
    assign rs1        = instruction[19:15];
    assign rs2        = instruction[24:20];
    assign function_7 = instruction[31:25];

endmodule
