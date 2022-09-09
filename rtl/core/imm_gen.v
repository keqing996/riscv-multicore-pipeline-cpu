module immediate_generator (
    input wire [31:0] instruction,
    output reg [31:0] immediate
);

    wire [6:0] opcode = instruction[6:0];

    always @(*) begin
        case (opcode)
            // I-type: [31:20] -> imm[11:0]
            // ADDI, LW, JALR, etc.
            7'b0010011, 7'b0000011, 7'b1100111: 
                immediate = {{20{instruction[31]}}, instruction[31:20]};

            // S-type: [31:25] + [11:7] -> imm[11:0]
            // SW
            7'b0100011: 
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};

            // B-type: [31], [7], [30:25], [11:8] -> imm[12:1]
            // BEQ, BNE, etc.
            7'b1100011: 
                immediate = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};

            // U-type: [31:12] -> imm[31:12]
            // LUI, AUIPC
            7'b0110111, 7'b0010111: 
                immediate = {instruction[31:12], 12'b0};

            // J-type: [31], [19:12], [20], [30:21] -> imm[20:1]
            // JAL
            7'b1101111: 
                immediate = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};

            default: 
                immediate = 32'b0;
        endcase
    end

endmodule
