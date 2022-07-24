module imm_gen (
    input wire [31:0] instr,
    output reg [31:0] imm
);

    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)
            // I-type: [31:20] -> imm[11:0]
            // ADDI, LW, JALR, etc.
            7'b0010011, 7'b0000011, 7'b1100111: 
                imm = {{20{instr[31]}}, instr[31:20]};

            // S-type: [31:25] + [11:7] -> imm[11:0]
            // SW
            7'b0100011: 
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: [31], [7], [30:25], [11:8] -> imm[12:1]
            // BEQ, BNE, etc.
            7'b1100011: 
                imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};

            // U-type: [31:12] -> imm[31:12]
            // LUI, AUIPC
            7'b0110111, 7'b0010111: 
                imm = {instr[31:12], 12'b0};

            // J-type: [31], [19:12], [20], [30:21] -> imm[20:1]
            // JAL
            7'b1101111: 
                imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

            default: 
                imm = 32'b0;
        endcase
    end

endmodule
