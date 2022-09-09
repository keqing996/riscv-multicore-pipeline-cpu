module alu_control_unit (
    input wire [2:0] alu_operation_code,    // From Main Control (Extended to 3 bits)
    input wire [2:0] function_3,
    input wire [6:0] function_7,
    output reg [3:0] alu_control_code
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
    localparam ALU_LUI  = 4'b1001;

    always @(*) begin
        case (alu_operation_code)
            3'b000: begin // LW, SW, AUIPC (Add)
                alu_control_code = ALU_ADD;
            end
            
            3'b001: begin // Branch
                case (function_3)
                    3'b000: alu_control_code = ALU_SUB;  // BEQ (Sub to check Zero)
                    3'b001: alu_control_code = ALU_SUB;  // BNE (Sub to check Zero)
                    3'b100: alu_control_code = ALU_SLT;  // BLT (Use SLT)
                    3'b101: alu_control_code = ALU_SLT;  // BGE (Use SLT)
                    3'b110: alu_control_code = ALU_SLTU; // BLTU (Use SLTU)
                    3'b111: alu_control_code = ALU_SLTU; // BGEU (Use SLTU)
                    default: alu_control_code = ALU_SUB;
                endcase
            end

            3'b010: begin // R-type
                case (function_3)
                    3'b000: alu_control_code = (function_7[5]) ? ALU_SUB : ALU_ADD; // ADD/SUB
                    3'b001: alu_control_code = ALU_SLL;                         // SLL
                    3'b010: alu_control_code = ALU_SLT;                         // SLT
                    3'b011: alu_control_code = ALU_SLTU;                        // SLTU
                    3'b100: alu_control_code = ALU_XOR;                         // XOR
                    3'b101: alu_control_code = (function_7[5]) ? ALU_SRA : ALU_SRL; // SRL/SRA
                    3'b110: alu_control_code = ALU_OR;                          // OR
                    3'b111: alu_control_code = ALU_AND;                         // AND
                    default: alu_control_code = ALU_ADD;
                endcase
            end

            3'b011: begin // I-type (Immediate Arithmetic)
                case (function_3)
                    3'b000: alu_control_code = ALU_ADD;                         // ADDI
                    3'b001: alu_control_code = ALU_SLL;                         // SLLI
                    3'b010: alu_control_code = ALU_SLT;                         // SLTI
                    3'b011: alu_control_code = ALU_SLTU;                        // SLTIU
                    3'b100: alu_control_code = ALU_XOR;                         // XORI
                    3'b101: alu_control_code = (function_7[5]) ? ALU_SRA : ALU_SRL; // SRLI/SRAI
                    3'b110: alu_control_code = ALU_OR;                          // ORI
                    3'b111: alu_control_code = ALU_AND;                         // ANDI
                    default: alu_control_code = ALU_ADD;
                endcase
            end

            3'b100: begin // LUI
                alu_control_code = ALU_LUI;
            end

            default: alu_control_code = ALU_ADD;
        endcase
    end

endmodule
