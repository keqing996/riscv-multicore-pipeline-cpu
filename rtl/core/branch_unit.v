module branch_unit (
    input wire [2:0] function_3,
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    output reg branch_condition_met
);

    always @(*) begin
        case (function_3)
            3'b000: branch_condition_met = (operand_a == operand_b);                         // BEQ
            3'b001: branch_condition_met = (operand_a != operand_b);                         // BNE
            3'b100: branch_condition_met = ($signed(operand_a) < $signed(operand_b));        // BLT
            3'b101: branch_condition_met = ($signed(operand_a) >= $signed(operand_b));       // BGE
            3'b110: branch_condition_met = (operand_a < operand_b);                          // BLTU
            3'b111: branch_condition_met = (operand_a >= operand_b);                         // BGEU
            default: branch_condition_met = 0;
        endcase
    end

endmodule
