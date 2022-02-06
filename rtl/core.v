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

    // DMEM signals
    wire [31:0] dmem_rdata;
    wire mem_write;
    wire mem_to_reg;

    // ImmGen signals
    wire [31:0] imm;

    // Control signals
    wire [1:0] alu_op;

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
    // I-type/S-type/U-type/J-type use Immediate
    assign alu_src_b = (is_i_type || is_s_type || is_u_type || is_j_type) ? imm : rs2_data;

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

    // Control Logic (temporary)
    assign reg_write = is_r_type || is_i_type || is_u_type || is_j_type; // Load is I-type
    assign mem_write = is_store;
    assign mem_to_reg = is_load;

    // Generate ALU Op (temporary)
    // 00: LW/SW, 01: Branch, 10: R-type, 11: I-type
    assign alu_op[1] = is_r_type || (is_i_type && !is_load); // Don't use I-type ALU logic for Load (use Add)
    assign alu_op[0] = is_b_type || (is_i_type && !is_load);

    // Write back data MUX
    assign wdata = mem_to_reg ? dmem_rdata : 
                   is_j_type ? (pc_curr + 32'd4) : // JAL/JALR write PC+4 to rd
                   alu_result;

    // Branch/Jump Logic
    wire branch_taken = is_b_type && zero_flag; // BEQ: take branch if Zero (TODO: support BNE, BLT etc)
    wire jump_taken   = is_j_type; // JAL

    // PC Next MUX
    // Priority: Jump > Branch > Next
    assign pc_next = jump_taken   ? (pc_curr + imm) : // JAL target = PC + offset
                     branch_taken ? (pc_curr + imm) : // Branch target = PC + offset
                     (pc_curr + 32'd4);               // Default next instruction

    // Output current PC to IMEM
    assign pc_addr = pc_curr;

endmodule
