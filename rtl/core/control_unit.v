module control_unit (
    input wire [6:0] opcode,
    input wire [2:0] function_3,
    input wire [4:0] rs1_index,
    output reg branch,
    output reg jump,
    output reg memory_read_enable,
    output reg memory_to_register_select,
    output reg [2:0] alu_operation_code,
    output reg memory_write_enable,
    output reg alu_source_select,
    output reg register_write_enable,
    output reg alu_source_a_select, // 0: rs1_data, 1: PC
    output reg csr_write_enable,
    output reg csr_to_register_select,
    output reg is_machine_return,
    output reg is_environment_call
);

    always @(*) begin
        // Default values (prevent latches)
        branch                    = 0;
        jump                      = 0;
        memory_read_enable        = 0;
        memory_to_register_select = 0;
        alu_operation_code        = 3'b000;
        memory_write_enable       = 0;
        alu_source_select         = 0;
        register_write_enable     = 0;
        alu_source_a_select       = 0;
        csr_write_enable          = 0;
        csr_to_register_select    = 0;
        is_machine_return         = 0;
        is_environment_call       = 0;

        case (opcode)
            // R-type: ADD, SUB, AND, OR, etc.
            7'b0110011: begin
                register_write_enable = 1;
                alu_operation_code    = 3'b010;
            end

            // I-type: ADDI, ANDI, etc.
            7'b0010011: begin
                alu_source_select     = 1; // Use Immediate
                register_write_enable = 1;
                alu_operation_code    = 3'b011; // I-type ALU encoding
            end

            // Load: LW
            7'b0000011: begin
                alu_source_select         = 1;
                memory_to_register_select = 1;
                register_write_enable     = 1;
                memory_read_enable        = 1;
                alu_operation_code        = 3'b000; // Add (Base + Offset)
            end

            // Store: SW
            7'b0100011: begin
                alu_source_select   = 1;
                memory_write_enable = 1;
                alu_operation_code  = 3'b000; // Add (Base + Offset)
            end

            // Branch: BEQ
            7'b1100011: begin
                branch             = 1;
                alu_operation_code = 3'b001; // Sub (Comparison)
            end

            // Jump: JAL
            7'b1101111: begin
                jump                  = 1;
                register_write_enable = 1;
            end

            // Jump Register: JALR
            7'b1100111: begin
                jump                  = 1;
                register_write_enable = 1;
                alu_source_select     = 1; // Use Imm
                alu_operation_code    = 3'b000; // Add (rs1 + imm)
            end

            // LUI
            7'b0110111: begin
                alu_source_select     = 1; // Use Imm
                register_write_enable = 1;
                alu_operation_code    = 3'b100; // LUI (Pass B)
            end

            // AUIPC
            7'b0010111: begin
                alu_source_select     = 1; // Use Imm
                register_write_enable = 1;
                alu_source_a_select   = 1; // Use PC
                alu_operation_code    = 3'b000; // Add (PC + Imm)
            end

            // SYSTEM (CSRs, ECALL, MRET)
            7'b1110011: begin
                case (function_3)
                    3'b000: begin // ECALL or MRET
                        register_write_enable = 0;
                        // ECALL/MRET are funct3=0.
                    end
                    
                    3'b001: begin // CSRRW
                        register_write_enable  = 1;
                        csr_write_enable       = 1;
                        csr_to_register_select = 1;
                    end
                    
                    3'b010: begin // CSRRS
                        register_write_enable  = 1;
                        csr_write_enable       = (rs1_index != 0);
                        csr_to_register_select = 1;
                    end

                    3'b011: begin // CSRRC
                        register_write_enable  = 1;
                        csr_write_enable       = (rs1_index != 0);
                        csr_to_register_select = 1;
                    end
                    
                    default: begin
                        // Treat as CSRRW for now for testing
                        register_write_enable  = 1;
                        csr_write_enable       = 1;
                        csr_to_register_select = 1;
                    end
                endcase
            end

            default: begin
                // NOP or invalid
            end
        endcase
    end

endmodule
