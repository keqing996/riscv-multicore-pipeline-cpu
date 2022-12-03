module branch_predictor (
    input wire clk,
    input wire rst_n,
    
    // IF Stage: Prediction
    input wire [31:0] program_counter_fetch,
    output wire prediction_taken,
    output wire [31:0] prediction_target,
    
    // EX Stage: Update
    input wire [31:0] program_counter_execute,          // PC of the branch instruction in EX
    input wire branch_taken_execute,       // Actual outcome (Taken/Not Taken)
    input wire [31:0] branch_target_execute, // Actual target address
    input wire is_branch_execute,          // Is it a branch instruction
    input wire is_jump_execute             // Is it a jump instruction (JAL)
);

    // Simple BTB (Branch Target Buffer) + BHT (Branch History Table)
    // Direct Mapped
    parameter ENTRIES = 64;
    parameter INDEX_BITS = 6; // log2(ENTRIES)
    
    reg [31:0] btb_tag [0:ENTRIES-1];
    reg [31:0] btb_target [0:ENTRIES-1];
    reg [1:0]  bht [0:ENTRIES-1]; // 2-bit saturating counter
    reg        valid [0:ENTRIES-1];
    
    // -------------------------------------------------------------------------
    // Prediction Logic (IF Stage)
    // -------------------------------------------------------------------------
    wire [INDEX_BITS-1:0] index_if = program_counter_fetch[INDEX_BITS+1:2];
    wire [31:0] tag_if = program_counter_fetch;
    
    wire entry_valid = valid[index_if];
    wire tag_match = (btb_tag[index_if] == tag_if);
    wire [1:0] history = bht[index_if];
    
    // Predict taken if entry exists, tag matches, and counter >= 2 (Weakly Taken)
    assign prediction_taken = entry_valid && tag_match && (history >= 2'b10);
    assign prediction_target = btb_target[index_if];
    
    // -------------------------------------------------------------------------
    // Update Logic (EX Stage)
    // -------------------------------------------------------------------------
    wire [INDEX_BITS-1:0] index_ex = program_counter_execute[INDEX_BITS+1:2];
    
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid[i] <= 0;
                bht[i] <= 2'b01; // Weakly Not Taken
            end
        end else if (is_branch_execute || is_jump_execute) begin
            // Update BTB/BHT
            valid[index_ex] <= 1'b1;
            btb_tag[index_ex] <= program_counter_execute;
            btb_target[index_ex] <= branch_target_execute;
            
            if (branch_taken_execute) begin
                if (bht[index_ex] != 2'b11)
                    bht[index_ex] <= bht[index_ex] + 1;
            end else begin
                if (bht[index_ex] != 2'b00)
                    bht[index_ex] <= bht[index_ex] - 1;
            end
        end
    end

endmodule
