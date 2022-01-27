module alu_control (
    input wire [1:0] alu_op,    // From Main Control (to be implemented)
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    output reg [3:0] alu_ctrl
);

    // ALU Control Codes (Must match alu.v)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b1000;
    localparam ALU_SLL  = 4'b0001;
    localparam ALU_SLT  = 4'b0010;
    localparam ALU_SLTU = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SRL  = 4'b0101;
    localparam ALU_SRA  = 4'b1101;
    localparam ALU_OR   = 4'b0110;
    localparam ALU_AND  = 4'b0111;

    always @(*) begin
        case (alu_op)
            2'b00: begin // LW, SW (Add)
                alu_ctrl = ALU_ADD;
            end
            
            2'b01: begin // BEQ, BNE (Sub)
                alu_ctrl = ALU_SUB;
            end

            2'b10: begin // R-type
                case (funct3)
                    3'b000: alu_ctrl = (funct7[5]) ? ALU_SUB : ALU_ADD; // ADD/SUB
                    3'b001: alu_ctrl = ALU_SLL;                         // SLL
                    3'b010: alu_ctrl = ALU_SLT;                         // SLT
                    3'b011: alu_ctrl = ALU_SLTU;                        // SLTU
                    3'b100: alu_ctrl = ALU_XOR;                         // XOR
                    3'b101: alu_ctrl = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRL/SRA
                    3'b110: alu_ctrl = ALU_OR;                          // OR
                    3'b111: alu_ctrl = ALU_AND;                         // AND
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            2'b11: begin // I-type (Immediate Arithmetic)
                case (funct3)
                    3'b000: alu_ctrl = ALU_ADD;                         // ADDI
                    3'b001: alu_ctrl = ALU_SLL;                         // SLLI
                    3'b010: alu_ctrl = ALU_SLT;                         // SLTI
                    3'b011: alu_ctrl = ALU_SLTU;                        // SLTIU
                    3'b100: alu_ctrl = ALU_XOR;                         // XORI
                    3'b101: alu_ctrl = (funct7[5]) ? ALU_SRA : ALU_SRL; // SRLI/SRAI
                    3'b110: alu_ctrl = ALU_OR;                          // ORI
                    3'b111: alu_ctrl = ALU_AND;                         // ANDI
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            default: alu_ctrl = ALU_ADD;
        endcase
    end

endmodule
