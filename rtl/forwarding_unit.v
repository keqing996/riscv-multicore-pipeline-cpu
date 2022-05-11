module forwarding_unit (
    input wire [4:0] rs1_ex,      // RS1 address in EX stage
    input wire [4:0] rs2_ex,      // RS2 address in EX stage
    input wire [4:0] rd_mem,      // RD address in MEM stage
    input wire reg_write_mem,     // RegWrite signal in MEM stage
    input wire [4:0] rd_wb,       // RD address in WB stage
    input wire reg_write_wb,      // RegWrite signal in WB stage
    
    output reg [1:0] forward_a,   // Forwarding control for ALU Operand A
    output reg [1:0] forward_b    // Forwarding control for ALU Operand B
);

    // Forwarding for Operand A (RS1)
    always @(*) begin
        // EX Hazard: Forward from MEM stage
        if (reg_write_mem && (rd_mem != 0) && (rd_mem == rs1_ex)) begin
            forward_a = 2'b10;
        end
        // MEM Hazard: Forward from WB stage
        // Only forward if EX hazard condition isn't met (priority to most recent)
        else if (reg_write_wb && (rd_wb != 0) && (rd_wb == rs1_ex)) begin
            forward_a = 2'b01;
        end
        else begin
            forward_a = 2'b00; // No forwarding
        end
    end

    // Forwarding for Operand B (RS2)
    always @(*) begin
        // EX Hazard: Forward from MEM stage
        if (reg_write_mem && (rd_mem != 0) && (rd_mem == rs2_ex)) begin
            forward_b = 2'b10;
        end
        // MEM Hazard: Forward from WB stage
        else if (reg_write_wb && (rd_wb != 0) && (rd_wb == rs2_ex)) begin
            forward_b = 2'b01;
        end
        else begin
            forward_b = 2'b00; // No forwarding
        end
    end

endmodule
