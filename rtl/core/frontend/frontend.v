module frontend (
    input wire clk,
    input wire rst_n,

    // I-Cache Interface
    input wire [31:0] instruction,
    input wire instruction_grant,
    output wire [31:0] program_counter_address,

    // Backend Control / Feedback
    input wire stall_backend, // Stall from Backend (Hazard)
    input wire flush_due_to_branch,
    input wire flush_due_to_jump,
    input wire flush_due_to_trap,
    input wire [31:0] correct_pc, // For mispredict recovery
    input wire [31:0] trap_pc,    // For traps/returns
    input wire pc_mux_select_trap, // Select trap_pc

    // Branch Predictor Update (from Backend EX stage)
    input wire [31:0] id_ex_program_counter,
    input wire branch_taken_execute,
    input wire [31:0] branch_target_execute,
    input wire is_branch_execute,
    input wire is_jump_execute,
    input wire is_jalr_execute,
    input wire [31:0] jalr_target_execute,

    // Outputs to Backend (IF/ID Pipeline Register)
    output reg [31:0] if_id_program_counter,
    output reg [31:0] if_id_instruction,
    output reg if_id_prediction_taken,
    output reg [31:0] if_id_prediction_target
);

    // =========================================================================
    // Signal Declarations
    // =========================================================================

    reg [31:0] program_counter_next;
    wire [31:0] program_counter_current;
    wire [31:0] fetch_stage_instruction;

    // Branch Prediction Signals
    wire prediction_taken;
    wire [31:0] prediction_target;

    // Stall Logic
    wire stall_fetch_stage = !instruction_grant;
    wire stall_global = stall_backend || stall_fetch_stage;

    // =========================================================================
    // IF Stage Logic
    // =========================================================================

    // PC Instance
    program_counter u_program_counter (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(program_counter_next),
        .data_out(program_counter_current)
    );

    assign program_counter_address = program_counter_current;
    assign fetch_stage_instruction = instruction;

    // Branch Predictor
    branch_predictor u_branch_predictor (
        .clk(clk),
        .rst_n(rst_n),
        .program_counter_fetch(program_counter_current),
        .prediction_taken(prediction_taken),
        .prediction_target(prediction_target),
        .program_counter_execute(id_ex_program_counter),
        .branch_taken_execute(branch_taken_execute || is_jump_execute), 
        .branch_target_execute((is_jump_execute && is_jalr_execute) ? jalr_target_execute : branch_target_execute),
        .is_branch_execute(is_branch_execute),
        .is_jump_execute(is_jump_execute)
    );

    // PC Next Logic
    // Priority: Reset > Interrupt/Trap > Mispredict > Stall > Prediction > Next
    // Note: Mispredict logic is handled in Backend to generate flush signals, 
    // but we need to know WHICH PC to take.
    // Backend provides: correct_pc (for mispredict), trap_pc (for traps)
    always @(*) begin
        if (pc_mux_select_trap) begin
            program_counter_next = trap_pc;
        end else if (flush_due_to_branch || flush_due_to_jump) begin
            program_counter_next = correct_pc; // Mispredict recovery
        end else if (stall_global) begin
            program_counter_next = program_counter_current; // Stall: Hold PC
        end else if (prediction_taken) begin
            program_counter_next = prediction_target;
        end else begin
            program_counter_next = program_counter_current + 4;
        end
    end

    // IF/ID Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_program_counter <= 0;
            if_id_instruction <= 0; // NOP
            if_id_prediction_taken <= 0;
            if_id_prediction_target <= 0;
        end else if (flush_due_to_branch || flush_due_to_jump || flush_due_to_trap) begin
            if_id_program_counter <= 0;
            if_id_instruction <= 0; // Flush -> NOP
            if_id_prediction_taken <= 0;
            if_id_prediction_target <= 0;
        end else if (!stall_global) begin
            if_id_program_counter <= program_counter_current;
            if_id_instruction <= fetch_stage_instruction;
            if_id_prediction_taken <= prediction_taken;
            if_id_prediction_target <= prediction_target;
        end
        // If stall, hold value
    end

endmodule
