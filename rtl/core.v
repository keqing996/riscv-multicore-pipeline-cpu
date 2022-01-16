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

    // ImmGen signals
    wire [31:0] imm;

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
        .is_j_type(is_j_type)
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

    // ALU Source B MUX
    // If I-type, S-type, U-type, J-type (basically anything not R-type or Branch), use Immediate
    // Note: Branch comparison uses registers, so it needs rs2.
    // For now, let's simplify: if is_i_type, use imm.
    assign alu_src_b = (is_i_type || is_s_type || is_u_type || is_j_type) ? imm : rs2_data;

    // Instantiate ALU
    alu u_alu (
        .a(rs1_data),
        .b(alu_src_b), 
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(zero_flag)
    );

    // Temporary Control Logic (Will be moved to Control Unit later)
    // For now, we only write back for R-type and I-type instructions
    assign reg_write = is_r_type || is_i_type || is_u_type || is_j_type;

    // Temporary ALU Control Logic
    // For now, we just force ADD (0000) to test data path
    assign alu_ctrl = 4'b0000; 

    // Write Back Logic
    // Now we write back the ALU result!
    assign wdata = alu_result;

    // Output current PC to IMEM
    assign pc_addr = pc_curr;

    // Simple PC + 4 logic (Fetch next instruction)
    // This will be replaced by a MUX later for branches/jumps
    assign pc_next = pc_curr + 32'd4;

endmodule
