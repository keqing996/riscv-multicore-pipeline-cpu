module decoder (
    input wire [31:0] instr,
    output wire [6:0] opcode,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire [4:0] rd,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    // Control signals (placeholder for now)
    output wire is_r_type,
    output wire is_i_type,
    output wire is_s_type,
    output wire is_b_type,
    output wire is_u_type,
    output wire is_j_type,
    output wire is_load,  // New: Explicit Load signal
    output wire is_store  // New: Explicit Store signal
);

    // Field extraction
    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // Instruction Type Decoding
    
    // R-type: 0110011 (OP)
    assign is_r_type = (opcode == 7'b0110011);

    // I-type: 0010011 (OP-IMM), 0000011 (LOAD), 1100111 (JALR)
    assign is_i_type = (opcode == 7'b0010011) || (opcode == 7'b0000011) || (opcode == 7'b1100111);

    // S-type: 0100011 (STORE)
    assign is_s_type = (opcode == 7'b0100011);

    // B-type: 1100011 (BRANCH)
    assign is_b_type = (opcode == 7'b1100011);

    // U-type: 0110111 (LUI), 0010111 (AUIPC)
    assign is_u_type = (opcode == 7'b0110111) || (opcode == 7'b0010111);

    // J-type: 1101111 (JAL)
    assign is_j_type = (opcode == 7'b1101111);

    // Specific Opcode Checks
    assign is_load  = (opcode == 7'b0000011);
    assign is_store = (opcode == 7'b0100011);

endmodule
