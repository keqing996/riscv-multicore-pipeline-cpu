module hazard_detection_unit (
    input wire [4:0] rs1_index_decode,      // RS1 address in ID stage
    input wire [4:0] rs2_index_decode,      // RS2 address in ID stage
    input wire [4:0] rd_index_execute,       // RD address in EX stage
    input wire memory_read_enable_execute,       // MemRead signal in EX stage (is it a Load?)
    
    output reg stall_pipeline              // Stall signal (1 = stall, 0 = normal)
);

    always @(*) begin
        // Load-Use Hazard Detection
        // If instruction in EX is a Load, and its destination (rd_ex) matches
        // either source register (rs1_id, rs2_id) in ID stage, we must stall.
        if (memory_read_enable_execute && (rd_index_execute != 0) && ((rd_index_execute == rs1_index_decode) || (rd_index_execute == rs2_index_decode))) begin
            stall_pipeline = 1'b1;
        end else begin
            stall_pipeline = 1'b0;
        end
    end

endmodule
