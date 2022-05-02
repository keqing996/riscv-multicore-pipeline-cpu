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
    wire [2:0] alu_op;
    wire mem_write;
    wire alu_src;
    wire alu_src_a;
    // wire reg_write; // Removed duplicate declaration
    
    // CSR Signals
    wire csr_we;
    wire csr_to_reg;
    wire is_mret;
    wire is_ecall;
    wire [31:0] csr_rdata;
    wire [31:0] mtvec;
    wire [31:0] mepc;
    wire interrupt_en; // From CSR File
    wire timer_irq;    // From Timer

    wire [31:0] imm;
    wire [31:0] dmem_rdata;
    wire [31:0] timer_rdata;

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
        .funct3(funct3),
        .rs1_addr(rs1), // Pass rs1 address
        .branch(branch),
        .jump(jump),
        .mem_read(mem_read),
        .mem_to_reg(mem_to_reg),
        .alu_op(alu_op),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .reg_write(reg_write),
        .alu_src_a(alu_src_a),
        .csr_we(csr_we),
        .csr_to_reg(csr_to_reg),
        .is_mret(is_mret),
        .is_ecall(is_ecall)
    );

    // Instantiate CSR File
    // CSR Address is in imm[11:0] (which corresponds to instr[31:20])
    wire [11:0] csr_addr = instr[31:20];
    
    // Exception Logic (Simplified)
    // Trigger exception on ECALL
    // ECALL opcode is SYSTEM (1110011) and funct3=0 and imm=0
    wire exception_en = (opcode == 7'b1110011) && (funct3 == 3'b000) && (instr[31:20] == 12'b0);
    wire mret_en      = (opcode == 7'b1110011) && (funct3 == 3'b000) && (instr[31:20] == 12'h302);

    csr_file u_csr_file (
        .clk(clk),
        .rst_n(rst_n),
        .csr_addr(csr_addr),
        .csr_we(csr_we),
        .csr_wdata(rs1_data), // CSRRW writes rs1 to CSR
        .csr_rdata(csr_rdata),
        .exception_en(exception_en),
        .exception_pc(pc_curr),
        .exception_cause(32'd11), // Environment call from M-mode
        .mret_en(mret_en),
        .timer_irq(timer_irq),
        .mtvec_out(mtvec),
        .mepc_out(mepc),
        .interrupt_en(interrupt_en)
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

    // MUX for ALU operand A
    wire [31:0] alu_src_a_val = alu_src_a ? pc_curr : rs1_data;

    // Instantiate ALU
    alu u_alu (
        .a(alu_src_a_val),
        .b(alu_src_b), 
        .alu_ctrl(alu_ctrl),
        .result(alu_result),
        .zero(zero_flag)
    );

    // Memory Address Decoding
    // DMEM: 0x0000_0000 - 0x01FF_FFFF (32MB)
    // UART: 0x4000_0000
    // Timer: 0x4000_4000 - 0x4000_400C
    
    wire is_uart_addr = (alu_result == 32'h40000000);
    wire is_timer_addr = (alu_result >= 32'h40004000 && alu_result <= 32'h4000400C);
    wire is_dmem_addr = (alu_result < 32'h02000000); // 32MB DMEM

    wire dmem_we = mem_write && is_dmem_addr;
    wire uart_we = mem_write && is_uart_addr;
    wire timer_we = mem_write && is_timer_addr;

    // LSU Logic
    wire [1:0] addr_offset = alu_result[1:0];
    reg [3:0] dmem_byte_enable;
    reg [31:0] dmem_wdata;
    reg [31:0] dmem_rdata_aligned;
    wire [31:0] dmem_rdata_raw;

    // Write Data Alignment & Byte Enable
    always @(*) begin
        dmem_byte_enable = 4'b0000;
        dmem_wdata = 32'b0;
        
        if (dmem_we) begin
            case (funct3)
                3'b000: begin // SB
                    dmem_wdata = {4{rs2_data[7:0]}};
                    dmem_byte_enable = 4'b0001 << addr_offset;
                end
                3'b001: begin // SH
                    dmem_wdata = {2{rs2_data[15:0]}};
                    dmem_byte_enable = 4'b0011 << addr_offset;
                end
                3'b010: begin // SW
                    dmem_wdata = rs2_data;
                    dmem_byte_enable = 4'b1111;
                end
                default: begin // Default to SW
                    dmem_wdata = rs2_data;
                    dmem_byte_enable = 4'b1111;
                end
            endcase
        end
    end

    // Read Data Alignment
    always @(*) begin
        case (funct3)
            3'b000: begin // LB
                case (addr_offset)
                    2'b00: dmem_rdata_aligned = {{24{dmem_rdata_raw[7]}}, dmem_rdata_raw[7:0]};
                    2'b01: dmem_rdata_aligned = {{24{dmem_rdata_raw[15]}}, dmem_rdata_raw[15:8]};
                    2'b10: dmem_rdata_aligned = {{24{dmem_rdata_raw[23]}}, dmem_rdata_raw[23:16]};
                    2'b11: dmem_rdata_aligned = {{24{dmem_rdata_raw[31]}}, dmem_rdata_raw[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned = {{16{dmem_rdata_raw[15]}}, dmem_rdata_raw[15:0]};
                    1'b1: dmem_rdata_aligned = {{16{dmem_rdata_raw[31]}}, dmem_rdata_raw[31:16]};
                endcase
            end
            3'b010: begin // LW
                dmem_rdata_aligned = dmem_rdata_raw;
            end
            3'b100: begin // LBU
                case (addr_offset)
                    2'b00: dmem_rdata_aligned = {24'b0, dmem_rdata_raw[7:0]};
                    2'b01: dmem_rdata_aligned = {24'b0, dmem_rdata_raw[15:8]};
                    2'b10: dmem_rdata_aligned = {24'b0, dmem_rdata_raw[23:16]};
                    2'b11: dmem_rdata_aligned = {24'b0, dmem_rdata_raw[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned = {16'b0, dmem_rdata_raw[15:0]};
                    1'b1: dmem_rdata_aligned = {16'b0, dmem_rdata_raw[31:16]};
                endcase
            end
            default: dmem_rdata_aligned = dmem_rdata_raw;
        endcase
    end

    assign dmem_rdata = dmem_rdata_aligned;

    // Instantiate Data Memory
    dmem u_dmem (
        .clk(clk),
        .byte_enable(dmem_byte_enable),
        .addr(alu_result),
        .wdata(dmem_wdata),
        .rdata(dmem_rdata_raw)
    );

    // Instantiate UART Simulation Model
    uart_sim u_uart_sim (
        .clk(clk),
        .we(uart_we),
        .addr(alu_result),
        .wdata(rs2_data)
    );

    // Instantiate Timer
    timer u_timer (
        .clk(clk),
        .rst_n(rst_n),
        .we(timer_we),
        .addr(alu_result),
        .wdata(rs2_data),
        .rdata(timer_rdata),
        .irq(timer_irq)
    );

    // Write back data MUX
    // JAL and JALR both write PC+4 to rd
    wire [31:0] mem_rdata_mux = is_timer_addr ? timer_rdata : dmem_rdata;

    assign wdata = csr_to_reg ? csr_rdata :
                   mem_to_reg ? mem_rdata_mux : 
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
    // Priority: Reset > Interrupt > Exception > MRET > JALR > JAL > Branch > Next
    // Note: We need a signal to distinguish JAL and JALR.
    // Currently 'jump' is high for JAL. We need to update Control Unit or Decoder.
    // Let's use opcode check for JALR here for simplicity, or update decoder.
    wire is_jalr = (opcode == 7'b1100111);

    assign pc_next = interrupt_en ? mtvec :       // Trap to Handler (Interrupt)
                     exception_en ? mtvec :       // Trap to Handler (Exception)
                     mret_en      ? mepc :        // Return from Handler
                     is_jalr      ? jalr_target :
                     jump         ? (pc_curr + imm) : 
                     branch_taken ? (pc_curr + imm) : 
                     (pc_curr + 32'd4);

    // Output current PC to IMEM
    assign pc_addr = pc_curr;

endmodule
