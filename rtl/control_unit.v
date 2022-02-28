module control_unit (
    input wire [6:0] opcode,
    output reg branch,
    output reg jump,
    output reg mem_read,
    output reg mem_to_reg,
    output reg [2:0] alu_op,
    output reg mem_write,
    output reg alu_src,
    output reg reg_write,
    output reg alu_src_a // 0: rs1_data, 1: PC
);

    always @(*) begin
        // Default values (prevent latches)
        branch     = 0;
        jump       = 0;
        mem_read   = 0;
        mem_to_reg = 0;
        alu_op     = 3'b000;
        mem_write  = 0;
        alu_src    = 0;
        reg_write  = 0;
        alu_src_a  = 0;

        case (opcode)
            // R-type: ADD, SUB, AND, OR, etc.
            7'b0110011: begin
                reg_write = 1;
                alu_op    = 3'b010;
            end

            // I-type: ADDI, ANDI, etc.
            7'b0010011: begin
                alu_src   = 1; // Use Immediate
                reg_write = 1;
                alu_op    = 3'b011; // I-type ALU encoding
            end

            // Load: LW
            7'b0000011: begin
                alu_src    = 1;
                mem_to_reg = 1;
                reg_write  = 1;
                mem_read   = 1;
                alu_op     = 3'b000; // Add (Base + Offset)
            end

            // Store: SW
            7'b0100011: begin
                alu_src   = 1;
                mem_write = 1;
                alu_op    = 3'b000; // Add (Base + Offset)
            end

            // Branch: BEQ
            7'b1100011: begin
                branch = 1;
                alu_op = 3'b001; // Sub (Comparison)
            end

            // Jump: JAL
            7'b1101111: begin
                jump      = 1;
                reg_write = 1;
                // ALU op doesn't matter for JAL, but let's keep it clean
            end

            // Jump Register: JALR
            7'b1100111: begin
                jump      = 1; // Treat as jump for write back logic (PC+4)
                reg_write = 1;
                alu_src   = 1; // Use Imm
                alu_op    = 3'b000; // Add (rs1 + imm) - though we calculate target separately in core
            end

            // LUI
            7'b0110111: begin
                alu_src   = 1; // Use Imm
                reg_write = 1;
                alu_op    = 3'b100; // LUI (Pass B)
            end

            // AUIPC
            7'b0010111: begin
                alu_src   = 1; // Use Imm
                reg_write = 1;
                alu_src_a = 1; // Use PC
                alu_op    = 3'b000; // Add (PC + Imm)
            end

            default: begin
                // NOP or invalid
            end
        endcase
    end

endmodule
