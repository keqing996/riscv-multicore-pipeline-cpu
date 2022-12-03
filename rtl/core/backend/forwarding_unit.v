module forwarding_unit (
    input wire [4:0] rs1_index_execute,      // RS1 address in EX stage
    input wire [4:0] rs2_index_execute,      // RS2 address in EX stage
    input wire [4:0] rd_index_memory,      // RD address in MEM stage
    input wire register_write_enable_memory,     // RegWrite signal in MEM stage
    input wire [4:0] rd_index_writeback,       // RD address in WB stage
    input wire register_write_enable_writeback,      // RegWrite signal in WB stage
    
    output reg [1:0] forward_a_select,   // Forwarding control for ALU Operand A
    output reg [1:0] forward_b_select    // Forwarding control for ALU Operand B
);

    // Forwarding for Operand A (RS1)
    always @(*) begin
        // EX Hazard: Forward from MEM stage
        if (register_write_enable_memory && (rd_index_memory != 0) && (rd_index_memory == rs1_index_execute)) begin
            forward_a_select = 2'b10;
        end
        // MEM Hazard: Forward from WB stage
        // Only forward if EX hazard condition isn't met (priority to most recent)
        else if (register_write_enable_writeback && (rd_index_writeback != 0) && (rd_index_writeback == rs1_index_execute)) begin
            forward_a_select = 2'b01;
        end
        else begin
            forward_a_select = 2'b00; // No forwarding
        end
    end

    // Forwarding for Operand B (RS2)
    always @(*) begin
        // EX Hazard: Forward from MEM stage
        if (register_write_enable_memory && (rd_index_memory != 0) && (rd_index_memory == rs2_index_execute)) begin
            forward_b_select = 2'b10;
        end
        // MEM Hazard: Forward from WB stage
        else if (register_write_enable_writeback && (rd_index_writeback != 0) && (rd_index_writeback == rs2_index_execute)) begin
            forward_b_select = 2'b01;
        end
        else begin
            forward_b_select = 2'b00; // No forwarding
        end
    end

endmodule
