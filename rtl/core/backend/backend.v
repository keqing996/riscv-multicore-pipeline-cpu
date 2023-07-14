module backend (
    input wire clk,
    input wire rst_n,
    input wire [31:0] hart_id, // Added: Hart ID

    // Inputs from Frontend (IF/ID Pipeline Register)
    input wire [31:0] if_id_program_counter,
    input wire [31:0] if_id_instruction,
    input wire if_id_prediction_taken,
    input wire [31:0] if_id_prediction_target,

    // I-Cache Status (for stalling)
    input wire instruction_grant,

    // Bus Interface
    output wire [31:0] bus_address,
    output wire [31:0] bus_write_data,
    output wire [3:0]  bus_byte_enable,
    output wire        bus_write_enable,
    output wire        bus_read_enable,
    input  wire [31:0] bus_read_data,
    input  wire        bus_busy,
    input  wire        timer_interrupt_request, // Added input

    // Outputs to Frontend (Control / Feedback)
    output wire stall_pipeline, // To Frontend
    output wire flush_due_to_branch,
    output wire flush_due_to_jump,
    output wire flush_due_to_trap,
    output wire [31:0] correct_pc,
    output wire [31:0] trap_pc,
    output wire pc_mux_select_trap,

    // Outputs to Frontend (BP Update)
    output reg [31:0] id_ex_program_counter,
    output wire branch_taken_execute,
    output wire [31:0] branch_target_execute,
    output reg is_branch_execute, // id_ex_branch
    output reg is_jump_execute,   // id_ex_jump
    output reg is_jalr_execute,   // id_ex_is_jalr
    output wire [31:0] jalr_target_execute
);

    // =========================================================================
    // Signal Declarations
    // =========================================================================

    // --- ID Stage Signals ---
    wire [6:0] opcode;
    wire [2:0] function_3;
    wire [6:0] function_7;
    wire [4:0] rd_index_decode;
    wire [4:0] rs1_index_decode;
    wire [4:0] rs2_index_decode;
    wire [31:0] immediate_decode;
    wire [31:0] rs1_data_decode;
    wire [31:0] rs2_data_decode;
    
    // Control Signals (ID)
    wire branch_decode;
    wire jump_decode;
    wire memory_read_enable_decode;
    wire memory_to_register_select_decode;
    wire [2:0] alu_operation_code_decode;
    wire memory_write_enable_decode;
    wire alu_source_select_decode;
    wire register_write_enable_decode;
    wire alu_source_a_select_decode;
    wire csr_write_enable_decode;
    wire csr_to_register_select_decode;
    wire is_machine_return_decode;
    wire is_environment_call_decode;
    wire is_mdu_operation_decode; // New wire
    wire is_jalr_decode = (opcode == 7'b1100111);

    // Hazard / Stall Signals
    wire stall_fetch_stage = !instruction_grant;
    wire stall_mem_stage = bus_busy;
    wire stall_hazard;
    wire mdu_busy; 
    wire mdu_ready;
    wire mdu_stall = id_ex_is_mdu_operation && !mdu_ready; // Stall until MDU is ready
    assign stall_pipeline = stall_hazard || stall_mem_stage || mdu_stall; 

    // --- ID/EX Pipeline Registers ---
    // id_ex_program_counter is output
    reg id_ex_prediction_taken;
    reg [31:0] id_ex_prediction_target;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_immediate;
    reg [4:0]  id_ex_rs1_index;
    reg [4:0]  id_ex_rs2_index;
    reg [4:0]  id_ex_rd_index;
    reg [2:0]  id_ex_function_3;
    reg [6:0]  id_ex_function_7;

    // Control Signals (ID/EX)
    // id_ex_branch, id_ex_jump, id_ex_is_jalr are outputs
    reg id_ex_memory_read_enable;
    reg id_ex_memory_to_register_select;
    reg [2:0] id_ex_alu_operation_code;
    reg id_ex_memory_write_enable;
    reg id_ex_alu_source_select;
    reg id_ex_register_write_enable;
    reg id_ex_alu_source_a_select;
    reg id_ex_csr_write_enable;
    reg id_ex_csr_to_register_select;
    reg id_ex_is_machine_return;
    reg id_ex_is_environment_call;
    reg id_ex_is_mdu_operation; // New register

    // --- EX Stage Signals ---
    wire [31:0] alu_result_execute;
    wire [3:0] alu_control_code_execute;
    wire [31:0] alu_input_a_execute;
    wire [31:0] alu_input_b_execute;
    wire [31:0] forward_a_value;
    wire [31:0] forward_b_value;
    wire [1:0] forward_a_select;
    wire [1:0] forward_b_select;
    // branch_target_execute, branch_taken_execute are outputs

    // --- EX/MEM Pipeline Registers ---
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_rs2_data;
    reg [4:0]  ex_mem_rd_index;
    reg [2:0]  ex_mem_function_3;

    // Control Signals (EX/MEM)
    reg ex_mem_memory_read_enable;
    reg ex_mem_memory_to_register_select;
    reg ex_mem_memory_write_enable;
    reg ex_mem_register_write_enable;
    reg ex_mem_csr_to_register_select;
    reg [31:0] ex_mem_csr_read_data;

    // --- MEM Stage Signals ---
    wire [31:0] memory_read_data_final;
    // wire timer_interrupt_request; // Removed wire declaration, now input

    // --- MEM/WB Pipeline Registers ---
    reg [31:0] mem_wb_read_data;
    reg [31:0] mem_wb_alu_result;
    reg [4:0]  mem_wb_rd_index;
    reg [31:0] mem_wb_csr_read_data;

    // Control Signals (MEM/WB)
    reg mem_wb_memory_to_register_select;
    reg mem_wb_register_write_enable;
    reg mem_wb_csr_to_register_select;

    // --- WB Stage Signals ---
    wire [31:0] write_data_writeback;

    // =========================================================================
    // ID Stage
    // =========================================================================

    // Decoder
    instruction_decoder u_instruction_decoder (
        .instruction(if_id_instruction),
        .opcode(opcode),
        .function_3(function_3),
        .function_7(function_7),
        .rd(rd_index_decode),
        .rs1(rs1_index_decode),
        .rs2(rs2_index_decode)
    );

    // Control Unit
    control_unit u_control_unit (
        .opcode(opcode),
        .function_3(function_3),
        .function_7(function_7),
        .rs2_index(rs2_index_decode),
        .rs1_index(rs1_index_decode),
        .branch(branch_decode),
        .jump(jump_decode),
        .memory_read_enable(memory_read_enable_decode),
        .memory_to_register_select(memory_to_register_select_decode),
        .alu_operation_code(alu_operation_code_decode),
        .memory_write_enable(memory_write_enable_decode),
        .alu_source_select(alu_source_select_decode),
        .register_write_enable(register_write_enable_decode),
        .alu_source_a_select(alu_source_a_select_decode),
        .csr_write_enable(csr_write_enable_decode),
        .csr_to_register_select(csr_to_register_select_decode),
        .is_machine_return(is_machine_return_decode),
        .is_environment_call(is_environment_call_decode),
        .is_mdu_operation(is_mdu_operation_decode) // Connected
    );

    // Register File
    regfile u_regfile (
        .clk(clk),
        .write_enable(mem_wb_register_write_enable),
        .rs1_index(rs1_index_decode),
        .rs2_index(rs2_index_decode),
        .rd_index(mem_wb_rd_index),
        .write_data(write_data_writeback),
        .rs1_read_data(rs1_data_decode),
        .rs2_read_data(rs2_data_decode)
    );

    // Immediate Generator
    immediate_generator u_immediate_generator (
        .instruction(if_id_instruction),
        .immediate(immediate_decode)
    );

    // CSR File
    wire [31:0] csr_read_data_execute;
    wire [31:0] mtvec;
    wire [31:0] mepc;
    wire interrupt_enable;
    wire [31:0] csr_new_value; // Forwarding signal
    
    control_status_register_file u_control_status_register_file (
        .clk(clk),
        .rst_n(rst_n),
        .hart_id(hart_id), // Added: Hart ID
        .csr_address(id_ex_immediate[11:0]),
        .csr_write_enable(id_ex_csr_write_enable),
        .csr_write_data(forward_a_value),
        .csr_op(id_ex_function_3),
        .csr_read_data(csr_read_data_execute),
        .exception_enable(id_ex_is_environment_call),
        .exception_program_counter(id_ex_program_counter),
        .exception_cause(32'd11),
        .machine_return_enable(id_ex_is_machine_return),
        .timer_interrupt_request(timer_interrupt_request),
        .mtvec_out(mtvec),
        .mepc_out(mepc),
        .interrupt_enable(interrupt_enable),
        .csr_new_value_out(csr_new_value)
    );

    // Hazard Detection Unit
    hazard_detection_unit u_hazard_detection_unit (
        .rs1_index_decode(rs1_index_decode),
        .rs2_index_decode(rs2_index_decode),
        .rd_index_execute(id_ex_rd_index),
        .memory_read_enable_execute(id_ex_memory_read_enable),
        .stall_pipeline(stall_hazard)
    );

    // ID/EX Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_program_counter <= 0;
            id_ex_prediction_taken <= 0;
            id_ex_prediction_target <= 0;
            id_ex_rs1_data <= 0;
            id_ex_rs2_data <= 0;
            id_ex_immediate <= 0;
            id_ex_rs1_index <= 0;
            id_ex_rs2_index <= 0;
            id_ex_rd_index <= 0;
            id_ex_function_3 <= 0;
            id_ex_function_7 <= 0;
            // Control
            is_branch_execute <= 0;
            is_jump_execute <= 0;
            id_ex_memory_read_enable <= 0;
            id_ex_memory_to_register_select <= 0;
            id_ex_alu_operation_code <= 0;
            id_ex_memory_write_enable <= 0;
            id_ex_alu_source_select <= 0;
            id_ex_register_write_enable <= 0;
            id_ex_alu_source_a_select <= 0;
            id_ex_csr_write_enable <= 0;
            id_ex_csr_to_register_select <= 0;
            id_ex_is_machine_return <= 0;
            id_ex_is_environment_call <= 0;
            is_jalr_execute <= 0;
            id_ex_is_mdu_operation <= 0; // Reset
        end else if (stall_mem_stage || mdu_stall) begin // Stall if MDU is busy/not ready
            // Stall ID/EX (Hold value)
        end else if (flush_due_to_branch || flush_due_to_jump || stall_hazard) begin
            // Flush ID/EX (Insert Bubble)
            is_branch_execute <= 0;
            is_jump_execute <= 0;
            id_ex_memory_read_enable <= 0;
            id_ex_memory_write_enable <= 0;
            id_ex_register_write_enable <= 0;
            id_ex_csr_write_enable <= 0;
            id_ex_is_machine_return <= 0;
            id_ex_is_environment_call <= 0;
            is_jalr_execute <= 0;
            id_ex_is_mdu_operation <= 0; // Flush
            
            id_ex_prediction_taken <= 0;
            id_ex_prediction_target <= 0;
            id_ex_program_counter <= 0; 
        end else begin
            id_ex_program_counter <= if_id_program_counter;
            id_ex_prediction_taken <= if_id_prediction_taken;
            id_ex_prediction_target <= if_id_prediction_target;
            id_ex_rs1_data <= rs1_data_decode;
            id_ex_rs2_data <= rs2_data_decode;
            id_ex_immediate <= immediate_decode;
            id_ex_rs1_index <= rs1_index_decode;
            id_ex_rs2_index <= rs2_index_decode;
            id_ex_rd_index <= rd_index_decode;
            id_ex_function_3 <= function_3;
            id_ex_function_7 <= function_7;
            // Control
            is_branch_execute <= branch_decode;
            is_jump_execute <= jump_decode;
            id_ex_memory_read_enable <= memory_read_enable_decode;
            id_ex_memory_to_register_select <= memory_to_register_select_decode;
            id_ex_alu_operation_code <= alu_operation_code_decode;
            id_ex_memory_write_enable <= memory_write_enable_decode;
            id_ex_alu_source_select <= alu_source_select_decode;
            id_ex_register_write_enable <= register_write_enable_decode;
            id_ex_alu_source_a_select <= alu_source_a_select_decode;
            id_ex_csr_write_enable <= csr_write_enable_decode;
            id_ex_csr_to_register_select <= csr_to_register_select_decode;
            id_ex_is_machine_return <= is_machine_return_decode;
            id_ex_is_environment_call <= is_environment_call_decode;
            is_jalr_execute <= is_jalr_decode;
            id_ex_is_mdu_operation <= is_mdu_operation_decode; // Assign
        end
    end

    // =========================================================================
    // EX Stage
    // =========================================================================

    // Forwarding Unit
    forwarding_unit u_forwarding_unit (
        .rs1_index_execute(id_ex_rs1_index),
        .rs2_index_execute(id_ex_rs2_index),
        .rd_index_memory(ex_mem_rd_index),
        .register_write_enable_memory(ex_mem_register_write_enable),
        .rd_index_writeback(mem_wb_rd_index),
        .register_write_enable_writeback(mem_wb_register_write_enable),
        .forward_a_select(forward_a_select),
        .forward_b_select(forward_b_select)
    );

    // ALU Input Muxes (Forwarding)
    assign forward_a_value = (forward_a_select == 2'b10) ? (ex_mem_csr_to_register_select ? ex_mem_csr_read_data : ex_mem_alu_result) :
                           (forward_a_select == 2'b01) ? write_data_writeback :
                           id_ex_rs1_data;

    assign forward_b_value = (forward_b_select == 2'b10) ? (ex_mem_csr_to_register_select ? ex_mem_csr_read_data : ex_mem_alu_result) :
                           (forward_b_select == 2'b01) ? write_data_writeback :
                           id_ex_rs2_data;

    // ALU Source Muxes (Immediate vs Register)
    assign alu_input_a_execute = id_ex_alu_source_a_select ? id_ex_program_counter : forward_a_value;
    assign alu_input_b_execute = id_ex_alu_source_select   ? id_ex_immediate : forward_b_value;

    // ALU Control
    alu_control_unit u_alu_control_unit (
        .alu_operation_code(id_ex_alu_operation_code),
        .function_3(id_ex_function_3),
        .function_7(id_ex_function_7),
        .alu_control_code(alu_control_code_execute)
    );

    // ALU
    wire [31:0] alu_output_execute;
    alu u_alu (
        .a(alu_input_a_execute),
        .b(alu_input_b_execute),
        .alu_control_code(alu_control_code_execute),
        .result(alu_output_execute)
    );

    // MDU (Multiplication Division Unit)
    wire [31:0] mdu_result;
    
    mdu u_mdu (
        .clk(clk),
        .rst_n(rst_n),
        .start(id_ex_is_mdu_operation && !mdu_busy && !mdu_ready), 
        .operation(id_ex_function_3),
        .operand_a(forward_a_value),
        .operand_b(forward_b_value),
        .busy(mdu_busy),
        .ready(mdu_ready),
        .result(mdu_result)
    );

    assign alu_result_execute = is_jump_execute ? (id_ex_program_counter + 32'd4) : 
                                id_ex_is_mdu_operation ? mdu_result :
                                alu_output_execute;

    // Branch Logic
    assign branch_target_execute = id_ex_program_counter + id_ex_immediate;

    wire branch_condition_met;
    branch_unit u_branch_unit (
        .function_3(id_ex_function_3),
        .operand_a(forward_a_value),
        .operand_b(forward_b_value),
        .branch_condition_met(branch_condition_met)
    );

    assign branch_taken_execute = (is_branch_execute && branch_condition_met);
    
    // Jump Logic (JAL/JALR)
    assign jalr_target_execute = (forward_a_value + id_ex_immediate) & 32'hFFFFFFFE;
    
    // Flush signals
    wire actual_taken = branch_taken_execute || is_jump_execute;
    wire [31:0] actual_target = (is_jump_execute && is_jalr_execute) ? jalr_target_execute : branch_target_execute;
    wire is_control_execute = is_branch_execute || is_jump_execute;

    wire mispredict = 
        (is_control_execute && (id_ex_prediction_taken != actual_taken)) || 
        (is_control_execute && id_ex_prediction_taken && (id_ex_prediction_target != actual_target)) ||
        (!is_control_execute && id_ex_prediction_taken);

    assign correct_pc = actual_taken ? actual_target : (id_ex_program_counter + 4);

    assign flush_due_to_branch = mispredict;
    assign flush_due_to_jump   = 0; 
    assign flush_due_to_trap   = interrupt_enable || is_environment_call_decode || is_machine_return_decode;

    // CSR Forwarding Logic
    wire [11:0] csr_write_address_execute = id_ex_immediate[11:0];
    wire [31:0] mtvec_forwarded;
    wire [31:0] mepc_forwarded;

    assign mtvec_forwarded = (id_ex_csr_write_enable && (csr_write_address_execute == 12'h305)) ? csr_new_value : mtvec;
    assign mepc_forwarded  = (id_ex_csr_write_enable && (csr_write_address_execute == 12'h341)) ? csr_new_value : mepc;

    // Trap PC Logic
    assign trap_pc = (interrupt_enable || is_environment_call_decode) ? mtvec_forwarded : mepc_forwarded;
    assign pc_mux_select_trap = interrupt_enable || is_environment_call_decode || is_machine_return_decode;

    // EX/MEM Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= 0;
            ex_mem_rs2_data <= 0;
            ex_mem_rd_index <= 0;
            ex_mem_function_3 <= 0;
            ex_mem_memory_read_enable <= 0;
            ex_mem_memory_to_register_select <= 0;
            ex_mem_memory_write_enable <= 0;
            ex_mem_register_write_enable <= 0;
            ex_mem_csr_to_register_select <= 0;
            ex_mem_csr_read_data <= 0;
        end else if (stall_mem_stage) begin
            // Stall EX/MEM (Hold value)
        end else if (mdu_stall) begin
            // Insert Bubble (NOP) while MDU is busy/not ready
            ex_mem_memory_read_enable <= 0;
            ex_mem_memory_write_enable <= 0;
            ex_mem_register_write_enable <= 0;
            ex_mem_csr_to_register_select <= 0;
            ex_mem_rd_index <= 0;
            ex_mem_alu_result <= 0;
            ex_mem_rs2_data <= 0;
            ex_mem_function_3 <= 0;
            ex_mem_memory_to_register_select <= 0;
            ex_mem_csr_read_data <= 0;
        end else begin
            ex_mem_alu_result <= alu_result_execute;
            ex_mem_rs2_data <= forward_b_value;
            ex_mem_rd_index <= id_ex_rd_index;
            ex_mem_function_3 <= id_ex_function_3;
            ex_mem_memory_read_enable <= id_ex_memory_read_enable;
            ex_mem_memory_to_register_select <= id_ex_memory_to_register_select;
            ex_mem_memory_write_enable <= id_ex_memory_write_enable;
            ex_mem_register_write_enable <= id_ex_register_write_enable;
            ex_mem_csr_to_register_select <= id_ex_csr_to_register_select;
            ex_mem_csr_read_data <= csr_read_data_execute;
        end
    end

    // =========================================================================
    // MEM Stage
    // =========================================================================

    // Load Store Unit
    load_store_unit u_load_store_unit (
        .address(ex_mem_alu_result),
        .write_data_in(ex_mem_rs2_data),
        .memory_read_enable(ex_mem_memory_read_enable),
        .memory_write_enable(ex_mem_memory_write_enable),
        .function_3(ex_mem_function_3),
        .bus_address(bus_address),
        .bus_write_data(bus_write_data),
        .bus_byte_enable(bus_byte_enable),
        .bus_write_enable(bus_write_enable),
        .bus_read_enable(bus_read_enable),
        .bus_read_data(bus_read_data),
        .memory_read_data_final(memory_read_data_final)
    );

    // MEM/WB Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_read_data <= 0;
            mem_wb_alu_result <= 0;
            mem_wb_rd_index <= 0;
            mem_wb_memory_to_register_select <= 0;
            mem_wb_register_write_enable <= 0;
            mem_wb_csr_to_register_select <= 0;
            mem_wb_csr_read_data <= 0;
        end else if (stall_mem_stage) begin
            // Stall MEM/WB (Hold value)
        end else begin
            mem_wb_read_data <= memory_read_data_final;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_rd_index <= ex_mem_rd_index;
            mem_wb_memory_to_register_select <= ex_mem_memory_to_register_select;
            mem_wb_register_write_enable <= ex_mem_register_write_enable;
            mem_wb_csr_to_register_select <= ex_mem_csr_to_register_select;
            mem_wb_csr_read_data <= ex_mem_csr_read_data;
        end
    end

    // =========================================================================
    // WB Stage
    // =========================================================================

    assign write_data_writeback = mem_wb_csr_to_register_select ? mem_wb_csr_read_data :
                      mem_wb_memory_to_register_select ? mem_wb_read_data : 
                      mem_wb_alu_result;

endmodule
