module core (
    input wire clk,
    input wire rst_n,
    input wire [31:0] instruction,   // Instruction from IMEM (IF stage)
    input wire instruction_grant,      // Instruction Grant (Cache Hit/Ready)
    output wire [31:0] program_counter_address, // PC output to IMEM

    // Data Memory Interface
    output wire [31:0] data_memory_address,
    output wire [31:0] data_memory_write_data_out,
    output wire [3:0]  data_memory_byte_enable_out,
    output wire        data_memory_write_enable_out,
    input  wire [31:0] data_memory_read_data_in
);

    // =========================================================================
    // Signal Declarations
    // =========================================================================

    // --- IF Stage Signals ---
    wire [31:0] program_counter_next;
    wire [31:0] program_counter_current;
    wire [31:0] fetch_stage_instruction; // Instruction in IF stage

    // Branch Prediction Signals
    wire prediction_taken;
    wire [31:0] prediction_target;

    // --- IF/ID Pipeline Registers ---
    reg [31:0] if_id_program_counter;
    reg [31:0] if_id_instruction;
    reg if_id_prediction_taken;
    reg [31:0] if_id_prediction_target;

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
    wire alu_source_a_select_decode; // For JALR/AUIPC etc if needed, or just use 0
    wire csr_write_enable_decode;
    wire csr_to_register_select_decode;
    wire is_machine_return_decode;
    wire is_environment_call_decode;
    wire is_jalr_decode = (opcode == 7'b1100111); // Added

    // Hazard / Stall Signals
    wire stall_pipeline;
    wire stall_fetch_stage; // Stall due to I-Cache miss
    wire flush_due_to_branch; // Flush due to branch taken
    wire flush_due_to_jump;   // Flush due to jump (JAL/JALR)
    wire flush_due_to_trap;   // Flush due to trap/interrupt

    assign stall_fetch_stage = !instruction_grant;
    wire stall_global = stall_pipeline || stall_fetch_stage; // Global stall condition (for PC and IF/ID)
    wire stall_backend = stall_fetch_stage;         // Backend stall (only for Cache Miss)

    // --- ID/EX Pipeline Registers ---
    reg [31:0] id_ex_program_counter;
    reg id_ex_prediction_taken;
    reg [31:0] id_ex_prediction_target;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_immediate;
    reg [4:0]  id_ex_rs1_index;
    reg [4:0]  id_ex_rs2_index;
    reg [4:0]  id_ex_rd_index;
    reg [2:0]  id_ex_function_3; // For ALU control and Branch
    reg [6:0]  id_ex_function_7; // For ALU control

    // Control Signals (ID/EX)
    reg id_ex_branch;
    reg id_ex_jump;
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
    reg id_ex_is_jalr; // Added
    reg [31:0] id_ex_csr_read_data; // Pass read CSR data to EX/MEM/WB? 
                                // Actually CSR read happens in ID, so we pass data down.

    // --- EX Stage Signals ---
    wire [31:0] alu_result_execute;
    wire [3:0] alu_control_code_execute;
    wire [31:0] alu_input_a_execute;
    wire [31:0] alu_input_b_execute;
    wire [31:0] forward_a_value;
    wire [31:0] forward_b_value;
    wire [1:0] forward_a_select;
    wire [1:0] forward_b_select;
    wire [31:0] branch_target_execute;
    wire branch_taken_execute;

    // --- EX/MEM Pipeline Registers ---
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_rs2_data; // For Store (after forwarding)
    reg [4:0]  ex_mem_rd_index;
    reg [2:0]  ex_mem_function_3; // For Load/Store size

    // Control Signals (EX/MEM)
    reg ex_mem_memory_read_enable;
    reg ex_mem_memory_to_register_select;
    reg ex_mem_memory_write_enable;
    reg ex_mem_register_write_enable;
    reg ex_mem_csr_to_register_select;
    reg [31:0] ex_mem_csr_read_data;

    // --- MEM Stage Signals ---
    // wire [31:0] data_memory_read_data_raw; // Removed internal wire, using input port directly
    wire [31:0] data_memory_read_data_aligned;
    wire [31:0] timer_read_data;
    wire [31:0] memory_read_data_final;
    wire [31:0] data_memory_write_data;
    wire [3:0] data_memory_byte_enable;
    wire is_timer_address;
    wire is_uart_address;
    wire timer_interrupt_request;

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
    // IF Stage
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
    // Note: Inputs from EX stage are feedback
    wire [31:0] jalr_target_execute; // Forward declaration
    branch_predictor u_branch_predictor (
        .clk(clk),
        .rst_n(rst_n),
        .program_counter_fetch(program_counter_current),
        .prediction_taken(prediction_taken),
        .prediction_target(prediction_target),
        .program_counter_execute(id_ex_program_counter),
        .branch_taken_execute(branch_taken_execute || id_ex_jump), 
        .branch_target_execute((id_ex_jump && id_ex_is_jalr) ? jalr_target_execute : branch_target_execute),
        .is_branch_execute(id_ex_branch),
        .is_jump_execute(id_ex_jump)
    );

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
        .is_environment_call(is_environment_call_decode)
    );

    // Register File
    // Note: Writes come from WB stage
    regfile u_regfile (
        .clk(clk),
        .write_enable(mem_wb_register_write_enable), // Write Enable from WB
        .rs1_index(rs1_index_decode),
        .rs2_index(rs2_index_decode),
        .rd_index(mem_wb_rd_index),   // Write Address from WB
        .write_data(write_data_writeback),      // Write Data from WB
        .rs1_read_data(rs1_data_decode),
        .rs2_read_data(rs2_data_decode)
    );

    // Immediate Generator
    immediate_generator u_immediate_generator (
        .instruction(if_id_instruction),
        .immediate(immediate_decode)
    );

    // CSR File
    wire [31:0] csr_read_data_decode;
    wire [31:0] mtvec;
    wire [31:0] mepc;
    wire interrupt_enable;
    
    control_status_register_file u_control_status_register_file (
        .clk(clk),
        .rst_n(rst_n),
        .csr_address(immediate_decode[11:0]), // CSR address is in imm field
        .csr_write_enable(csr_write_enable_decode && !stall_pipeline && !flush_due_to_branch), // Only write if valid
        .csr_write_data(rs1_data_decode), // Data to write to CSR
        .csr_read_data(csr_read_data_decode),
        .exception_enable(is_environment_call_decode && !stall_pipeline && !flush_due_to_branch),
        .exception_program_counter(if_id_program_counter), // PC of current instruction (for MEPC)
        .exception_cause(32'd11), // ECALL cause
        .machine_return_enable(is_machine_return_decode && !stall_pipeline && !flush_due_to_branch),
        .timer_interrupt_request(timer_interrupt_request),
        .mtvec_out(mtvec),
        .mepc_out(mepc),
        .interrupt_enable(interrupt_enable)
    );

    // Hazard Detection Unit
    hazard_detection_unit u_hazard_detection_unit (
        .rs1_index_decode(rs1_index_decode),
        .rs2_index_decode(rs2_index_decode),
        .rd_index_execute(id_ex_rd_index),
        .memory_read_enable_execute(id_ex_memory_read_enable),
        .stall_pipeline(stall_pipeline)
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
            id_ex_branch <= 0;
            id_ex_jump <= 0;
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
            id_ex_is_jalr <= 0;
            id_ex_csr_read_data <= 0;
        end else if (flush_due_to_branch || flush_due_to_jump || flush_due_to_trap || stall_pipeline) begin
            // Flush ID/EX (Insert Bubble)
            id_ex_branch <= 0;
            id_ex_jump <= 0;
            id_ex_memory_read_enable <= 0;
            id_ex_memory_write_enable <= 0;
            id_ex_register_write_enable <= 0;
            id_ex_csr_write_enable <= 0;
            id_ex_is_machine_return <= 0;
            id_ex_is_environment_call <= 0;
            id_ex_is_jalr <= 0;
            
            // Clear prediction info to avoid false mispredicts on bubbles
            id_ex_prediction_taken <= 0;
            id_ex_prediction_target <= 0;
            id_ex_program_counter <= 0; 
            
            // Others don't matter if reg_write/mem_write are 0
        end else if (stall_fetch_stage) begin
            // Stall ID/EX (Hold value)
            // Do nothing, registers keep their values
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
            id_ex_branch <= branch_decode;
            id_ex_jump <= jump_decode;
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
            id_ex_is_jalr <= is_jalr_decode;
            id_ex_csr_read_data <= csr_read_data_decode;
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
    assign forward_a_value = (forward_a_select == 2'b10) ? ex_mem_alu_result :
                           (forward_a_select == 2'b01) ? write_data_writeback :
                           id_ex_rs1_data;

    assign forward_b_value = (forward_b_select == 2'b10) ? ex_mem_alu_result :
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

    assign alu_result_execute = id_ex_jump ? (id_ex_program_counter + 32'd4) : alu_output_execute;

    // Branch Logic
    // Calculate Branch Target
    assign branch_target_execute = id_ex_program_counter + id_ex_immediate;

    // Branch Condition Check
    wire branch_condition_met;
    branch_unit u_branch_unit (
        .function_3(id_ex_function_3),
        .operand_a(forward_a_value),
        .operand_b(forward_b_value),
        .branch_condition_met(branch_condition_met)
    );

    assign branch_taken_execute = (id_ex_branch && branch_condition_met);
    
    // Jump Logic (JAL/JALR)
    // JAL target = PC + imm (calculated in branch_target_ex)
    // JALR target = (rs1 + imm) & ~1
    assign jalr_target_execute = (forward_a_value + id_ex_immediate) & 32'hFFFFFFFE;
    
    // Flush signals
    // Misprediction Logic
    wire actual_taken = branch_taken_execute || id_ex_jump;
    wire [31:0] actual_target = (id_ex_jump && id_ex_is_jalr) ? jalr_target_execute : branch_target_execute;
    wire is_control_execute = id_ex_branch || id_ex_jump;

    wire mispredict = 
        (is_control_execute && (id_ex_prediction_taken != actual_taken)) || 
        (is_control_execute && id_ex_prediction_taken && (id_ex_prediction_target != actual_target)) ||
        (!is_control_execute && id_ex_prediction_taken);

    wire [31:0] correct_pc = actual_taken ? actual_target : (id_ex_program_counter + 4);

    assign flush_due_to_branch = mispredict;
    assign flush_due_to_jump   = 0; // Handled by mispredict
    assign flush_due_to_trap   = interrupt_enable || is_environment_call_decode || is_machine_return_decode; // Flush on trap (from ID)

    // PC Next Logic
    // Priority: Reset > Interrupt > Exception > MRET > Mispredict > Prediction > Next
    assign program_counter_next = interrupt_enable ? mtvec :
                     stall_global ? program_counter_current : // Stall: Hold PC
                     is_environment_call_decode  ? mtvec : // Exception (ECALL)
                     is_machine_return_decode   ? mepc :
                     mispredict ? correct_pc :
                     prediction_taken ? prediction_target :
                     (program_counter_current + 4);

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
        end else if (!stall_global) begin
            ex_mem_alu_result <= alu_result_execute;
            ex_mem_rs2_data <= forward_b_value; // Store data (after forwarding)
            ex_mem_rd_index <= id_ex_rd_index;
            ex_mem_function_3 <= id_ex_function_3;
            ex_mem_memory_read_enable <= id_ex_memory_read_enable;
            ex_mem_memory_to_register_select <= id_ex_memory_to_register_select;
            ex_mem_memory_write_enable <= id_ex_memory_write_enable;
            ex_mem_register_write_enable <= id_ex_register_write_enable;
            ex_mem_csr_to_register_select <= id_ex_csr_to_register_select;
            ex_mem_csr_read_data <= id_ex_csr_read_data;
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
        .data_memory_read_data(data_memory_read_data_in), // Connected to input port
        .timer_read_data(timer_read_data),
        .data_memory_write_data(data_memory_write_data),
        .data_memory_byte_enable(data_memory_byte_enable),
        .data_memory_write_enable(data_memory_write_enable),
        .uart_write_enable(uart_write_enable),
        .timer_write_enable(timer_write_enable),
        .memory_read_data_final(memory_read_data_final)
    );

    // Data Memory Interface Connections
    assign data_memory_address = ex_mem_alu_result;
    assign data_memory_write_data_out = data_memory_write_data;
    assign data_memory_byte_enable_out = data_memory_byte_enable;
    assign data_memory_write_enable_out = data_memory_write_enable;
    // assign data_memory_read_data_raw = data_memory_read_data_in; // This is an input to load_store_unit, not an assignment

    // UART Instance
    uart_simulator u_uart_simulator (
        .clk(clk),
        .write_enable(uart_write_enable),
        .address(ex_mem_alu_result),
        .write_data(ex_mem_rs2_data) 
    );

    // Timer Instance
    timer u_timer (
        .clk(clk),
        .rst_n(rst_n),
        .write_enable(timer_write_enable),
        .address(ex_mem_alu_result),
        .write_data(ex_mem_rs2_data), 
        .read_data(timer_read_data),
        .interrupt_request(timer_interrupt_request)
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
        end else if (!stall_global) begin
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