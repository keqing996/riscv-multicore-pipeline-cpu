module core (
    input wire clk,
    input wire rst_n,
    input wire [31:0] instr,   // Instruction from IMEM (IF stage)
    input wire instr_gnt,      // Instruction Grant (Cache Hit/Ready)
    output wire [31:0] pc_addr // PC output to IMEM
);

    // =========================================================================
    // Signal Declarations
    // =========================================================================

    // --- IF Stage Signals ---
    wire [31:0] pc_next;
    wire [31:0] pc_curr;
    wire [31:0] if_instr; // Instruction in IF stage

    // Branch Prediction Signals
    wire predict_taken;
    wire [31:0] predict_target;

    // --- IF/ID Pipeline Registers ---
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;
    reg if_id_predict_taken;
    reg [31:0] if_id_predict_target;

    // --- ID Stage Signals ---
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] rd_id;
    wire [4:0] rs1_id;
    wire [4:0] rs2_id;
    wire [31:0] imm_id;
    wire [31:0] rs1_data_id;
    wire [31:0] rs2_data_id;
    
    // Control Signals (ID)
    wire branch_id;
    wire jump_id;
    wire mem_read_id;
    wire mem_to_reg_id;
    wire [2:0] alu_op_id;
    wire mem_write_id;
    wire alu_src_id;
    wire reg_write_id;
    wire alu_src_a_id; // For JALR/AUIPC etc if needed, or just use 0
    wire csr_we_id;
    wire csr_to_reg_id;
    wire is_mret_id;
    wire is_ecall_id;
    wire is_jalr_id = (opcode == 7'b1100111); // Added

    // Hazard / Stall Signals
    wire stall;
    wire stall_if; // Stall due to I-Cache miss
    wire flush_branch; // Flush due to branch taken
    wire flush_jump;   // Flush due to jump (JAL/JALR)
    wire flush_trap;   // Flush due to trap/interrupt

    assign stall_if = !instr_gnt;
    wire stall_global = stall || stall_if; // Global stall condition (for PC and IF/ID)
    wire stall_backend = stall_if;         // Backend stall (only for Cache Miss)

    // --- ID/EX Pipeline Registers ---
    reg [31:0] id_ex_pc;
    reg id_ex_predict_taken;
    reg [31:0] id_ex_predict_target;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_imm;
    reg [4:0]  id_ex_rs1;
    reg [4:0]  id_ex_rs2;
    reg [4:0]  id_ex_rd;
    reg [2:0]  id_ex_funct3; // For ALU control and Branch
    reg [6:0]  id_ex_funct7; // For ALU control

    // Control Signals (ID/EX)
    reg id_ex_branch;
    reg id_ex_jump;
    reg id_ex_mem_read;
    reg id_ex_mem_to_reg;
    reg [2:0] id_ex_alu_op;
    reg id_ex_mem_write;
    reg id_ex_alu_src;
    reg id_ex_reg_write;
    reg id_ex_alu_src_a;
    reg id_ex_csr_we;
    reg id_ex_csr_to_reg;
    reg id_ex_is_mret;
    reg id_ex_is_ecall;
    reg id_ex_is_jalr; // Added
    reg [31:0] id_ex_csr_rdata; // Pass read CSR data to EX/MEM/WB? 
                                // Actually CSR read happens in ID, so we pass data down.

    // --- EX Stage Signals ---
    wire [31:0] alu_result_ex;
    wire [3:0] alu_ctrl_ex;
    wire [31:0] alu_in_a_ex;
    wire [31:0] alu_in_b_ex;
    wire [31:0] forward_a_val;
    wire [31:0] forward_b_val;
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    wire [31:0] branch_target_ex;
    wire branch_taken_ex;

    // --- EX/MEM Pipeline Registers ---
    reg [31:0] ex_mem_alu_result;
    reg [31:0] ex_mem_rs2_data; // For Store (after forwarding)
    reg [4:0]  ex_mem_rd;
    reg [2:0]  ex_mem_funct3; // For Load/Store size

    // Control Signals (EX/MEM)
    reg ex_mem_mem_read;
    reg ex_mem_mem_to_reg;
    reg ex_mem_mem_write;
    reg ex_mem_reg_write;
    reg ex_mem_csr_to_reg;
    reg [31:0] ex_mem_csr_rdata;

    // --- MEM Stage Signals ---
    wire [31:0] dmem_rdata_raw;
    wire [31:0] dmem_rdata_aligned;
    wire [31:0] timer_rdata;
    wire [31:0] mem_rdata_final;
    wire [31:0] dmem_wdata;
    wire [3:0] dmem_byte_enable;
    wire is_timer_addr;
    wire is_uart_addr;
    wire timer_irq;

    // --- MEM/WB Pipeline Registers ---
    reg [31:0] mem_wb_rdata;
    reg [31:0] mem_wb_alu_result;
    reg [4:0]  mem_wb_rd;
    reg [31:0] mem_wb_csr_rdata;

    // Control Signals (MEM/WB)
    reg mem_wb_mem_to_reg;
    reg mem_wb_reg_write;
    reg mem_wb_csr_to_reg;

    // --- WB Stage Signals ---
    wire [31:0] wdata_wb;

    // =========================================================================
    // IF Stage
    // =========================================================================
    
    // PC Instance
    pc u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .din(pc_next),
        .dout(pc_curr)
    );

    assign pc_addr = pc_curr;
    assign if_instr = instr;

    // Branch Predictor
    // Note: Inputs from EX stage are feedback
    wire [31:0] jalr_target_ex; // Forward declaration
    branch_predictor u_branch_predictor (
        .clk(clk),
        .rst_n(rst_n),
        .pc_if(pc_curr),
        .predict_taken(predict_taken),
        .predict_target(predict_target),
        .pc_ex(id_ex_pc),
        .branch_taken_ex(branch_taken_ex || id_ex_jump), 
        .branch_target_ex((id_ex_jump && id_ex_is_jalr) ? jalr_target_ex : branch_target_ex),
        .is_branch_ex(id_ex_branch),
        .is_jump_ex(id_ex_jump)
    );

    // IF/ID Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc <= 0;
            if_id_instr <= 0; // NOP
            if_id_predict_taken <= 0;
            if_id_predict_target <= 0;
        end else if (flush_branch || flush_jump || flush_trap) begin
            if_id_pc <= 0;
            if_id_instr <= 0; // Flush -> NOP
            if_id_predict_taken <= 0;
            if_id_predict_target <= 0;
        end else if (!stall_global) begin
            if_id_pc <= pc_curr;
            if_id_instr <= if_instr;
            if_id_predict_taken <= predict_taken;
            if_id_predict_target <= predict_target;
        end
        // If stall, hold value
    end

    // =========================================================================
    // ID Stage
    // =========================================================================

    // Decoder
    decoder u_decoder (
        .instr(if_id_instr),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rd(rd_id),
        .rs1(rs1_id),
        .rs2(rs2_id)
    );

    // Control Unit
    control_unit u_control_unit (
        .opcode(opcode),
        .funct3(funct3),
        .rs1_addr(rs1_id),
        .branch(branch_id),
        .jump(jump_id),
        .mem_read(mem_read_id),
        .mem_to_reg(mem_to_reg_id),
        .alu_op(alu_op_id),
        .mem_write(mem_write_id),
        .alu_src(alu_src_id),
        .reg_write(reg_write_id),
        .alu_src_a(alu_src_a_id),
        .csr_we(csr_we_id),
        .csr_to_reg(csr_to_reg_id),
        .is_mret(is_mret_id),
        .is_ecall(is_ecall_id)
    );

    // Register File
    // Note: Writes come from WB stage
    regfile u_regfile (
        .clk(clk),
        .we(mem_wb_reg_write), // Write Enable from WB
        .rs1_addr(rs1_id),
        .rs2_addr(rs2_id),
        .rd_addr(mem_wb_rd),   // Write Address from WB
        .wdata(wdata_wb),      // Write Data from WB
        .rs1_data(rs1_data_id),
        .rs2_data(rs2_data_id)
    );

    // Immediate Generator
    imm_gen u_imm_gen (
        .instr(if_id_instr),
        .imm(imm_id)
    );

    // CSR File
    wire [31:0] csr_rdata_id;
    wire [31:0] mtvec;
    wire [31:0] mepc;
    wire interrupt_en;
    
    csr_file u_csr_file (
        .clk(clk),
        .rst_n(rst_n),
        .csr_addr(imm_id[11:0]), // CSR address is in imm field
        .csr_we(csr_we_id && !stall && !flush_branch), // Only write if valid
        .csr_wdata(rs1_data_id), // Data to write to CSR
        .csr_rdata(csr_rdata_id),
        .exception_en(is_ecall_id && !stall && !flush_branch),
        .exception_pc(if_id_pc), // PC of current instruction (for MEPC)
        .exception_cause(32'd11), // ECALL cause
        .mret_en(is_mret_id && !stall && !flush_branch),
        .timer_irq(timer_irq),
        .mtvec_out(mtvec),
        .mepc_out(mepc),
        .interrupt_en(interrupt_en)
    );

    // Hazard Detection Unit
    hazard_detection_unit u_hazard_detection (
        .rs1_id(rs1_id),
        .rs2_id(rs2_id),
        .rd_ex(id_ex_rd),
        .mem_read_ex(id_ex_mem_read),
        .stall(stall)
    );

    // ID/EX Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc <= 0;
            id_ex_predict_taken <= 0;
            id_ex_predict_target <= 0;
            id_ex_rs1_data <= 0;
            id_ex_rs2_data <= 0;
            id_ex_imm <= 0;
            id_ex_rs1 <= 0;
            id_ex_rs2 <= 0;
            id_ex_rd <= 0;
            id_ex_funct3 <= 0;
            id_ex_funct7 <= 0;
            // Control
            id_ex_branch <= 0;
            id_ex_jump <= 0;
            id_ex_mem_read <= 0;
            id_ex_mem_to_reg <= 0;
            id_ex_alu_op <= 0;
            id_ex_mem_write <= 0;
            id_ex_alu_src <= 0;
            id_ex_reg_write <= 0;
            id_ex_alu_src_a <= 0;
            id_ex_csr_we <= 0;
            id_ex_csr_to_reg <= 0;
            id_ex_is_mret <= 0;
            id_ex_is_ecall <= 0;
            id_ex_is_jalr <= 0;
            id_ex_csr_rdata <= 0;
        end else if (flush_branch || flush_jump || flush_trap || stall || stall_if) begin
            // Flush ID/EX (Insert Bubble)
            id_ex_branch <= 0;
            id_ex_jump <= 0;
            id_ex_mem_read <= 0;
            id_ex_mem_write <= 0;
            id_ex_reg_write <= 0;
            id_ex_csr_we <= 0;
            id_ex_is_mret <= 0;
            id_ex_is_ecall <= 0;
            id_ex_is_jalr <= 0;
            
            // Clear prediction info to avoid false mispredicts on bubbles
            id_ex_predict_taken <= 0;
            id_ex_predict_target <= 0;
            id_ex_pc <= 0; 
            
            // Others don't matter if reg_write/mem_write are 0
        end else begin
            id_ex_pc <= if_id_pc;
            id_ex_predict_taken <= if_id_predict_taken;
            id_ex_predict_target <= if_id_predict_target;
            id_ex_rs1_data <= rs1_data_id;
            id_ex_rs2_data <= rs2_data_id;
            id_ex_imm <= imm_id;
            id_ex_rs1 <= rs1_id;
            id_ex_rs2 <= rs2_id;
            id_ex_rd <= rd_id;
            id_ex_funct3 <= funct3;
            id_ex_funct7 <= funct7;
            // Control
            id_ex_branch <= branch_id;
            id_ex_jump <= jump_id;
            id_ex_mem_read <= mem_read_id;
            id_ex_mem_to_reg <= mem_to_reg_id;
            id_ex_alu_op <= alu_op_id;
            id_ex_mem_write <= mem_write_id;
            id_ex_alu_src <= alu_src_id;
            id_ex_reg_write <= reg_write_id;
            id_ex_alu_src_a <= alu_src_a_id;
            id_ex_csr_we <= csr_we_id;
            id_ex_csr_to_reg <= csr_to_reg_id;
            id_ex_is_mret <= is_mret_id;
            id_ex_is_ecall <= is_ecall_id;
            id_ex_is_jalr <= is_jalr_id;
            id_ex_csr_rdata <= csr_rdata_id;
        end
    end

    // =========================================================================
    // EX Stage
    // =========================================================================

    // Forwarding Unit
    forwarding_unit u_forwarding (
        .rs1_ex(id_ex_rs1),
        .rs2_ex(id_ex_rs2),
        .rd_mem(ex_mem_rd),
        .reg_write_mem(ex_mem_reg_write),
        .rd_wb(mem_wb_rd),
        .reg_write_wb(mem_wb_reg_write),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );

    // ALU Input Muxes (Forwarding)
    assign forward_a_val = (forward_a == 2'b10) ? ex_mem_alu_result :
                           (forward_a == 2'b01) ? wdata_wb :
                           id_ex_rs1_data;

    assign forward_b_val = (forward_b == 2'b10) ? ex_mem_alu_result :
                           (forward_b == 2'b01) ? wdata_wb :
                           id_ex_rs2_data;

    // ALU Source Muxes (Immediate vs Register)
    assign alu_in_a_ex = id_ex_alu_src_a ? id_ex_pc : forward_a_val;
    assign alu_in_b_ex = id_ex_alu_src   ? id_ex_imm : forward_b_val;

    // ALU Control
    alu_control u_alu_control (
        .alu_op(id_ex_alu_op),
        .funct3(id_ex_funct3),
        .funct7(id_ex_funct7),
        .alu_ctrl(alu_ctrl_ex)
    );

    // ALU
    wire [31:0] alu_out_ex;
    alu u_alu (
        .a(alu_in_a_ex),
        .b(alu_in_b_ex),
        .alu_ctrl(alu_ctrl_ex),
        .result(alu_out_ex)
    );

    assign alu_result_ex = id_ex_jump ? (id_ex_pc + 32'd4) : alu_out_ex;

    // Branch Logic
    // Calculate Branch Target
    assign branch_target_ex = id_ex_pc + id_ex_imm;

    // Branch Condition Check
    wire branch_cond;
    branch_unit u_branch_unit (
        .funct3(id_ex_funct3),
        .a(forward_a_val),
        .b(forward_b_val),
        .branch_taken(branch_cond)
    );

    assign branch_taken_ex = (id_ex_branch && branch_cond);
    
    // Jump Logic (JAL/JALR)
    // JAL target = PC + imm (calculated in branch_target_ex)
    // JALR target = (rs1 + imm) & ~1
    assign jalr_target_ex = (forward_a_val + id_ex_imm) & 32'hFFFFFFFE;
    
    // Flush signals
    // Misprediction Logic
    wire actual_taken = branch_taken_ex || id_ex_jump;
    wire [31:0] actual_target = (id_ex_jump && id_ex_is_jalr) ? jalr_target_ex : branch_target_ex;
    wire is_control_ex = id_ex_branch || id_ex_jump;

    wire mispredict = 
        (is_control_ex && (id_ex_predict_taken != actual_taken)) || 
        (is_control_ex && id_ex_predict_taken && (id_ex_predict_target != actual_target)) ||
        (!is_control_ex && id_ex_predict_taken);

    wire [31:0] correct_pc = actual_taken ? actual_target : (id_ex_pc + 4);

    assign flush_branch = mispredict;
    assign flush_jump   = 0; // Handled by mispredict
    assign flush_trap   = interrupt_en || is_ecall_id || is_mret_id; // Flush on trap (from ID)

    // PC Next Logic
    // Priority: Reset > Interrupt > Exception > MRET > Mispredict > Prediction > Next
    assign pc_next = interrupt_en ? mtvec :
                     stall_global ? pc_curr : // Stall: Hold PC
                     is_ecall_id  ? mtvec : // Exception (ECALL)
                     is_mret_id   ? mepc :
                     mispredict ? correct_pc :
                     predict_taken ? predict_target :
                     (pc_curr + 4);

    // EX/MEM Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= 0;
            ex_mem_rs2_data <= 0;
            ex_mem_rd <= 0;
            ex_mem_funct3 <= 0;
            ex_mem_mem_read <= 0;
            ex_mem_mem_to_reg <= 0;
            ex_mem_mem_write <= 0;
            ex_mem_reg_write <= 0;
            ex_mem_csr_to_reg <= 0;
            ex_mem_csr_rdata <= 0;
        end else if (!stall_global) begin
            ex_mem_alu_result <= alu_result_ex;
            ex_mem_rs2_data <= forward_b_val; // Store data (after forwarding)
            ex_mem_rd <= id_ex_rd;
            ex_mem_funct3 <= id_ex_funct3;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_to_reg <= id_ex_mem_to_reg;
            ex_mem_mem_write <= id_ex_mem_write;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_csr_to_reg <= id_ex_csr_to_reg;
            ex_mem_csr_rdata <= id_ex_csr_rdata;
        end
    end

    // =========================================================================
    // MEM Stage
    // =========================================================================

    // Load Store Unit
    load_store_unit u_lsu (
        .addr(ex_mem_alu_result),
        .wdata_in(ex_mem_rs2_data),
        .mem_read(ex_mem_mem_read),
        .mem_write(ex_mem_mem_write),
        .funct3(ex_mem_funct3),
        .dmem_rdata(dmem_rdata_raw),
        .timer_rdata(timer_rdata),
        .dmem_wdata(dmem_wdata),
        .dmem_byte_enable(dmem_byte_enable),
        .dmem_we(dmem_we),
        .uart_we(uart_we),
        .timer_we(timer_we),
        .mem_rdata_final(mem_rdata_final)
    );

    // DMEM Instance
    dmem u_dmem (
        .clk(clk),
        .byte_enable(dmem_byte_enable),
        .addr(ex_mem_alu_result),
        .wdata(dmem_wdata),
        .rdata(dmem_rdata_raw)
    );

    // UART Instance
    uart_sim u_uart_sim (
        .clk(clk),
        .we(uart_we),
        .addr(ex_mem_alu_result),
        .wdata(ex_mem_rs2_data) 
    );

    // Timer Instance
    timer u_timer (
        .clk(clk),
        .rst_n(rst_n),
        .we(timer_we),
        .addr(ex_mem_alu_result),
        .wdata(ex_mem_rs2_data), 
        .rdata(timer_rdata),
        .irq(timer_irq)
    );


    // MEM/WB Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_rdata <= 0;
            mem_wb_alu_result <= 0;
            mem_wb_rd <= 0;
            mem_wb_mem_to_reg <= 0;
            mem_wb_reg_write <= 0;
            mem_wb_csr_to_reg <= 0;
            mem_wb_csr_rdata <= 0;
        end else if (!stall_global) begin
            mem_wb_rdata <= mem_rdata_final;
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
            mem_wb_reg_write <= ex_mem_reg_write;
            mem_wb_csr_to_reg <= ex_mem_csr_to_reg;
            mem_wb_csr_rdata <= ex_mem_csr_rdata;
        end
    end

    // =========================================================================
    // WB Stage
    // =========================================================================

    assign wdata_wb = mem_wb_csr_to_reg ? mem_wb_csr_rdata :
                      mem_wb_mem_to_reg ? mem_wb_rdata : 
                      mem_wb_alu_result;
endmodule