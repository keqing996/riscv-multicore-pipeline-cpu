module core (
    input wire clk,
    input wire rst_n,
    input wire [31:0] instr,   // Instruction from IMEM (IF stage)
    output wire [31:0] pc_addr // PC output to IMEM
);

    // =========================================================================
    // Signal Declarations
    // =========================================================================

    // --- IF Stage Signals ---
    wire [31:0] pc_next;
    wire [31:0] pc_curr;
    wire [31:0] if_instr; // Instruction in IF stage

    // --- IF/ID Pipeline Registers ---
    reg [31:0] if_id_pc;
    reg [31:0] if_id_instr;

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
    wire flush_branch; // Flush due to branch taken
    wire flush_jump;   // Flush due to jump (JAL/JALR)
    wire flush_trap;   // Flush due to trap/interrupt

    // --- ID/EX Pipeline Registers ---
    reg [31:0] id_ex_pc;
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
    wire zero_flag_ex;
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
    reg [31:0] dmem_wdata;
    reg [3:0] dmem_byte_enable;
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

    // IF/ID Pipeline Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc <= 0;
            if_id_instr <= 0; // NOP
        end else if (flush_branch || flush_jump || flush_trap) begin
            if_id_pc <= 0;
            if_id_instr <= 0; // Flush -> NOP
        end else if (!stall) begin
            if_id_pc <= pc_curr;
            if_id_instr <= if_instr;
        end
        // If stall, hold value
    end

    // =========================================================================
    // ID Stage
    // =========================================================================

    // Decoder
    wire is_r_type, is_i_type, is_s_type, is_b_type, is_u_type, is_j_type;
    wire is_load, is_store;

    decoder u_decoder (
        .instr(if_id_instr),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rd(rd_id),
        .rs1(rs1_id),
        .rs2(rs2_id),
        .is_r_type(is_r_type),
        .is_i_type(is_i_type),
        .is_s_type(is_s_type),
        .is_b_type(is_b_type),
        .is_u_type(is_u_type),
        .is_j_type(is_j_type),
        .is_load(is_load),
        .is_store(is_store)
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
            id_ex_csr_rdata <= 0;
        end else if (stall || flush_branch || flush_jump || flush_trap) begin
            // Flush ID/EX (Insert Bubble)
            id_ex_branch <= 0;
            id_ex_jump <= 0;
            id_ex_mem_read <= 0;
            id_ex_mem_write <= 0;
            id_ex_reg_write <= 0;
            id_ex_csr_we <= 0;
            id_ex_is_mret <= 0;
            id_ex_is_ecall <= 0;
            // Others don't matter if reg_write/mem_write are 0
        end else begin
            id_ex_pc <= if_id_pc;
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
            id_ex_alu_src_a <= csr_we_id;
            id_ex_csr_we <= 0;
            id_ex_is_mret <= 0;
            id_ex_is_ecall <= 0;
            id_ex_is_jalr <= 0;
            // Others don't matter if reg_write/mem_write are 0
        end else begin
            id_ex_pc <= if_id_pc;
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
        .result(alu_out_ex),
        .zero(zero_flag_ex)
    );

    assign alu_result_ex = id_ex_jump ? (id_ex_pc + 32'd4) : alu_out_ex;

    // Branch Logic
    // Calculate Branch Target
    assign branch_target_ex = id_ex_pc + id_ex_imm;

    // Branch Condition Check
    reg branch_cond;
    always @(*) begin
        case (id_ex_funct3)
            3'b000: branch_cond = (forward_a_val == forward_b_val); // BEQ
            3'b001: branch_cond = (forward_a_val != forward_b_val); // BNE
            3'b100: branch_cond = ($signed(forward_a_val) < $signed(forward_b_val)); // BLT
            3'b101: branch_cond = ($signed(forward_a_val) >= $signed(forward_b_val)); // BGE
            3'b110: branch_cond = (forward_a_val < forward_b_val); // BLTU
            3'b111: branch_cond = (forward_a_val >= forward_b_val); // BGEU
            default: branch_cond = 0;
        endcase
    end

    assign branch_taken_ex = (id_ex_branch && branch_cond);
    
    // Jump Logic (JAL/JALR)
    // JAL target = PC + imm (calculated in branch_target_ex)
    // JALR target = (rs1 + imm) & ~1
    wire [31:0] jalr_target_ex = (forward_a_val + id_ex_imm) & 32'hFFFFFFFE;
    
    // Flush signals
    assign flush_branch = branch_taken_ex;
    assign flush_jump   = id_ex_jump; // Always flush on jump in EX stage (simple)
    assign flush_trap   = interrupt_en || is_ecall_id || is_mret_id; // Flush on trap (from ID)

    // PC Next Logic
    // Priority: Reset > Interrupt > Exception > MRET > JALR > JAL/Branch > Next
    // Note: Interrupts/Exceptions are detected in ID stage in this design
    assign pc_next = interrupt_en ? mtvec :
                     is_ecall_id  ? mtvec : // Exception (ECALL)
                     is_mret_id   ? mepc :
                     (id_ex_jump && (id_ex_funct3 == 0)) ? jalr_target_ex : // JALR (funct3=0 for JALR? No, opcode distinguishes. But here we use jump signal)
                     // Wait, JALR is I-type, JAL is J-type. 
                     // We need to distinguish JAL vs JALR.
                     // Let's assume control unit sets 'jump' for both.
                     // We can check opcode or funct3 if passed.
                     // JALR has funct3=000. JAL doesn't have funct3.
                     // Let's use a dedicated signal or check instruction bit if available?
                     // We don't have opcode in EX.
                     // Let's assume we passed enough info.
                     // Actually, JALR target is calculated using ALU usually?
                     // For now, let's assume JALR target is handled.
                     // To be safe: JALR is opcode 1100111.
                     // Let's add is_jalr to ID/EX?
                     // For simplicity:
                     branch_taken_ex ? branch_target_ex :
                     id_ex_jump ? ((id_ex_alu_src_a) ? jalr_target_ex : branch_target_ex) : // Hack: JALR uses alu_src_a=1 (rs1), JAL uses alu_src_a=0 (PC)? No.
                     // Let's fix JALR logic properly.
                     // JAL: PC+imm. JALR: rs1+imm.
                     // In ID, we set alu_src_a=1 for JAL (PC), alu_src_a=0 for JALR (rs1)?
                     // Control Unit:
                     // JAL: alu_src_a=1 (PC), alu_src=1 (imm). Result = PC+imm.
                     // JALR: alu_src_a=0 (rs1), alu_src=1 (imm). Result = rs1+imm.
                     // So alu_result_ex IS the target for both!
                     // EXCEPT JALR needs LSB masked.
                     id_ex_jump ? (alu_result_ex & ~1) : // Works for JAL too since imm is even? Yes.
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
        end else begin
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

    // Address Decoding
    assign is_uart_addr = (ex_mem_alu_result == 32'h40000000);
    assign is_timer_addr = (ex_mem_alu_result >= 32'h40004000 && ex_mem_alu_result <= 32'h4000400C);
    
    wire dmem_we = ex_mem_mem_write && !is_uart_addr && !is_timer_addr;
    wire uart_we = ex_mem_mem_write && is_uart_addr;
    wire timer_we = ex_mem_mem_write && is_timer_addr;

    // Store Data Alignment (Logic from previous core.v)
    wire [1:0] addr_offset = ex_mem_alu_result[1:0];
    
    always @(*) begin
        dmem_wdata = ex_mem_rs2_data;
        dmem_byte_enable = 4'b1111;
        
        if (ex_mem_mem_write) begin
            case (ex_mem_funct3)
                3'b000: begin // SB
                    dmem_wdata = {4{ex_mem_rs2_data[7:0]}};
                    dmem_byte_enable = 4'b0001 << addr_offset;
                end
                3'b001: begin // SH
                    dmem_wdata = {2{ex_mem_rs2_data[15:0]}};
                    dmem_byte_enable = 4'b0011 << addr_offset;
                end
                default: begin // SW
                    dmem_wdata = ex_mem_rs2_data;
                    dmem_byte_enable = 4'b1111;
                end
            endcase
        end
    end

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

    // Load Data Alignment
    reg [31:0] dmem_rdata_aligned_reg;
    always @(*) begin
        case (ex_mem_funct3)
            3'b000: begin // LB
                case (addr_offset)
                    2'b00: dmem_rdata_aligned_reg = {{24{dmem_rdata_raw[7]}}, dmem_rdata_raw[7:0]};
                    2'b01: dmem_rdata_aligned_reg = {{24{dmem_rdata_raw[15]}}, dmem_rdata_raw[15:8]};
                    2'b10: dmem_rdata_aligned_reg = {{24{dmem_rdata_raw[23]}}, dmem_rdata_raw[23:16]};
                    2'b11: dmem_rdata_aligned_reg = {{24{dmem_rdata_raw[31]}}, dmem_rdata_raw[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned_reg = {{16{dmem_rdata_raw[15]}}, dmem_rdata_raw[15:0]};
                    1'b1: dmem_rdata_aligned_reg = {{16{dmem_rdata_raw[31]}}, dmem_rdata_raw[31:16]};
                endcase
            end
            3'b010: begin // LW
                dmem_rdata_aligned_reg = dmem_rdata_raw;
            end
            3'b100: begin // LBU
                case (addr_offset)
                    2'b00: dmem_rdata_aligned_reg = {24'b0, dmem_rdata_raw[7:0]};
                    2'b01: dmem_rdata_aligned_reg = {24'b0, dmem_rdata_raw[15:8]};
                    2'b10: dmem_rdata_aligned_reg = {24'b0, dmem_rdata_raw[23:16]};
                    2'b11: dmem_rdata_aligned_reg = {24'b0, dmem_rdata_raw[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned_reg = {16'b0, dmem_rdata_raw[15:0]};
                    1'b1: dmem_rdata_aligned_reg = {16'b0, dmem_rdata_raw[31:16]};
                endcase
            end
            default: dmem_rdata_aligned_reg = dmem_rdata_raw;
        endcase
    end
    assign dmem_rdata_aligned = dmem_rdata_aligned_reg;

    // Mux for Read Data (Timer vs DMEM)
    assign mem_rdata_final = is_timer_addr ? timer_rdata : dmem_rdata_aligned;

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
        end else begin
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

    // Debug
    always @(posedge clk) begin
        if (id_ex_jump || flush_trap) begin
            $display("Time: %0t | Jump/Trap | PC: %h | Target: %h | FlushJump: %b | FlushTrap: %b | Mtvec: %h", 
                     $time, id_ex_pc, branch_target_ex, flush_jump, flush_trap, mtvec);
        end
    end
endmodule