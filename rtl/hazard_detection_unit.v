module hazard_detection_unit (
    input wire [4:0] rs1_id,      // RS1 address in ID stage
    input wire [4:0] rs2_id,      // RS2 address in ID stage
    input wire [4:0] rd_ex,       // RD address in EX stage
    input wire mem_read_ex,       // MemRead signal in EX stage (is it a Load?)
    
    output reg stall              // Stall signal (1 = stall, 0 = normal)
);

    always @(*) begin
        // Load-Use Hazard Detection
        // If instruction in EX is a Load, and its destination (rd_ex) matches
        // either source register (rs1_id, rs2_id) in ID stage, we must stall.
        if (mem_read_ex && ((rd_ex == rs1_id) || (rd_ex == rs2_id))) begin
            stall = 1'b1;
        end else begin
            stall = 1'b0;
        end
    end

endmodule
