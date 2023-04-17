module core (
    input wire clk,
    input wire rst_n,
    input wire [31:0] instruction,   // Instruction from IMEM (IF stage)
    input wire instruction_grant,      // Instruction Grant (Cache Hit/Ready)
    output wire [31:0] program_counter_address, // PC output to IMEM

    // Bus Interface
    output wire [31:0] bus_address,
    output wire [31:0] bus_write_data,
    output wire [3:0]  bus_byte_enable,
    output wire        bus_write_enable,
    output wire        bus_read_enable,
    input  wire [31:0] bus_read_data,
    input  wire        bus_busy,
    input  wire        timer_interrupt_request
);

    // =========================================================================
    // Signal Declarations
    // =========================================================================

    // Interconnect Signals
    wire stall_pipeline;
    wire flush_due_to_branch;
    wire flush_due_to_jump;
    wire flush_due_to_trap;
    wire [31:0] correct_pc;
    wire [31:0] trap_pc;
    wire pc_mux_select_trap;

    wire [31:0] if_id_program_counter;
    wire [31:0] if_id_instruction;
    wire if_id_prediction_taken;
    wire [31:0] if_id_prediction_target;

    wire [31:0] id_ex_program_counter;
    wire branch_taken_execute;
    wire [31:0] branch_target_execute;
    wire is_branch_execute;
    wire is_jump_execute;
    wire is_jalr_execute;
    wire [31:0] jalr_target_execute;

    // =========================================================================
    // Frontend Instance
    // =========================================================================
    frontend u_frontend (
        .clk(clk),
        .rst_n(rst_n),
        .instruction(instruction),
        .instruction_grant(instruction_grant),
        .program_counter_address(program_counter_address),
        .stall_backend(stall_pipeline),
        .flush_due_to_branch(flush_due_to_branch),
        .flush_due_to_jump(flush_due_to_jump),
        .flush_due_to_trap(flush_due_to_trap),
        .correct_pc(correct_pc),
        .trap_pc(trap_pc),
        .pc_mux_select_trap(pc_mux_select_trap),
        .id_ex_program_counter(id_ex_program_counter),
        .branch_taken_execute(branch_taken_execute),
        .branch_target_execute(branch_target_execute),
        .is_branch_execute(is_branch_execute),
        .is_jump_execute(is_jump_execute),
        .is_jalr_execute(is_jalr_execute),
        .jalr_target_execute(jalr_target_execute),
        .if_id_program_counter(if_id_program_counter),
        .if_id_instruction(if_id_instruction),
        .if_id_prediction_taken(if_id_prediction_taken),
        .if_id_prediction_target(if_id_prediction_target)
    );

    // =========================================================================
    // Backend Instance
    // =========================================================================
    backend u_backend (
        .clk(clk),
        .rst_n(rst_n),
        .if_id_program_counter(if_id_program_counter),
        .if_id_instruction(if_id_instruction),
        .if_id_prediction_taken(if_id_prediction_taken),
        .if_id_prediction_target(if_id_prediction_target),
        .instruction_grant(instruction_grant),
        .bus_address(bus_address),
        .bus_write_data(bus_write_data),
        .bus_byte_enable(bus_byte_enable),
        .bus_write_enable(bus_write_enable),
        .bus_read_enable(bus_read_enable),
        .bus_read_data(bus_read_data),
        .bus_busy(bus_busy),
        .timer_interrupt_request(timer_interrupt_request),
        .stall_pipeline(stall_pipeline),
        .flush_due_to_branch(flush_due_to_branch),
        .flush_due_to_jump(flush_due_to_jump),
        .flush_due_to_trap(flush_due_to_trap),
        .correct_pc(correct_pc),
        .trap_pc(trap_pc),
        .pc_mux_select_trap(pc_mux_select_trap),
        .id_ex_program_counter(id_ex_program_counter),
        .branch_taken_execute(branch_taken_execute),
        .branch_target_execute(branch_target_execute),
        .is_branch_execute(is_branch_execute),
        .is_jump_execute(is_jump_execute),
        .is_jalr_execute(is_jalr_execute),
        .jalr_target_execute(jalr_target_execute)
    );

endmodule
