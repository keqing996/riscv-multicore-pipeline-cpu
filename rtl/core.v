module core (
    input wire clk,
    input wire rst_n,
    input wire [31:0] instr,   // Instruction from IMEM
    output wire [31:0] pc_addr // PC output to IMEM
);

    wire [31:0] pc_next;
    wire [31:0] pc_curr;

    // Instantiate PC
    pc u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .din(pc_next),
        .dout(pc_curr)
    );

    // Decoder signals
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] rd;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire is_r_type, is_i_type, is_s_type, is_b_type, is_u_type, is_j_type;
    wire is_load, is_store;

    // RegFile signals
    wire reg_write;
    wire [31:0] wdata; // Data to write back to RegFile
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    // ALU signals
    wire [31:0] alu_result;
    wire zero_flag;
    wire [3:0] alu_ctrl;
    wire [31:0] alu_src_b; // MUX output for ALU operand B

    // Control signals
    wire branch;
    wire jump;
    wire mem_read; // Not used yet (for future)
    wire mem_to_reg;
    wire [1:0] alu_op;
    wire mem_write;
    wire alu_src;
    // wire reg_write; // Removed duplicate declaration

    wire [31:0] imm;
    wire [31:0] dmem_rdata;

    // Instantiate Decoder
    decoder u_decoder (
        .instr(instr),
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .is_r_type(is_r_type),
        .is_i_type(is_i_type),
        .is_s_type(is_s_type),
        .is_b_type(is_b_type),
        .is_u_type(is_u_type),
        .is_j_type(is_j_type),
        .is_load(is_load),
        .is_store(is_store)
    );

    // Instantiate Control Unit
    control_unit u_control_unit (
        .opcode(opcode),
        .branch(branch),
        .jump(jump),
        .mem_read(mem_read),
        .mem_to_reg(mem_to_reg),
        .alu_op(alu_op),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .reg_write(reg_write)
    );

    // Instantiate Register File
    regfile u_regfile (
        .clk(clk),
        .we(reg_write),
        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rd_addr(rd),
        .wdata(wdata),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // Instantiate Immediate Generator
    imm_gen u_imm_gen (
        .instr(instr),
        .imm(imm)
    );

    // Instantiate ALU Control
    alu_control u_alu_control (
        .alu_op(alu_op),
        .funct3(funct3),
        .funct7(funct7),
        .alu_ctrl(alu_ctrl)
    );

    // MUX for ALU operand B
    assign alu_src_b = alu_src ? imm : rs2_data;

    // Instantiate ALU
    alu u_alu (
        .a(rs1_data),
        .b(alu_src_b), 
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(zero_flag)
    );

    // Instantiate Data Memory
    dmem u_dmem (
        .clk(clk),
        .we(mem_write),
        .addr(alu_result),
        .wdata(rs2_data),
        .rdata(dmem_rdata)
    );

    // Write back data MUX
    // JAL and JALR both write PC+4 to rd
    assign wdata = mem_to_reg ? dmem_rdata : 
                   jump       ? (pc_curr + 32'd4) : 
                   alu_result;

    // Branch/Jump Logic
    reg branch_condition_met;
    
    always @(*) begin
        case (funct3)
            3'b000: branch_condition_met = zero_flag;          // BEQ
            3'b001: branch_condition_met = !zero_flag;         // BNE
            3'b100: branch_condition_met = (alu_result != 0);  // BLT (ALU does SLT, so result is 1 if a < b)
            3'b101: branch_condition_met = (alu_result == 0);  // BGE (ALU does SLT, so result is 0 if a >= b)
            3'b110: branch_condition_met = (alu_result != 0);  // BLTU (ALU does SLTU)
            3'b111: branch_condition_met = (alu_result == 0);  // BGEU (ALU does SLTU)
            default: branch_condition_met = 0;
        endcase
    end

    wire branch_taken = branch && branch_condition_met;
    
    // JALR Logic
    // JALR target = (rs1 + imm) & ~1
    // Note: In our single cycle implementation, rs1 is available at rs1_data
    // and imm is available at imm.
    // We can reuse the ALU to calculate rs1 + imm if we set alu_src_b = imm and alu_ctrl = ADD.
    // But JALR is an I-type instruction (opcode 1100111).
    // Let's check if we can just use a dedicated adder or reuse ALU.
    // For simplicity, let's use a dedicated calculation here to avoid complex ALU control changes for now.
    wire [31:0] jalr_target = (rs1_data + imm) & 32'hFFFFFFFE;

    // PC Next MUX
    // Priority: JALR > JAL > Branch > Next
    // Note: We need a signal to distinguish JAL and JALR.
    // Currently 'jump' is high for JAL. We need to update Control Unit or Decoder.
    // Let's use opcode check for JALR here for simplicity, or update decoder.
    wire is_jalr = (opcode == 7'b1100111);

    assign pc_next = is_jalr      ? jalr_target :
                     jump         ? (pc_curr + imm) : 
                     branch_taken ? (pc_curr + imm) : 
                     (pc_curr + 32'd4);

    // Output current PC to IMEM
    assign pc_addr = pc_curr;

endmodule
