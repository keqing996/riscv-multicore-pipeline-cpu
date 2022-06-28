`timescale 1ns / 1ps

module core_tb;

    reg clk;
    reg rst_n;
    wire [31:0] instr;
    wire [31:0] pc_addr;

    // Instantiate Core
    core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .instr(instr),
        .pc_addr(pc_addr)
    );

    // Instantiate IMEM
    imem u_imem (
        .addr(pc_addr),
        .data(instr)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test logic
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, core_tb);

        // Load program into IMEM
        $readmemh("program.hex", u_imem.memory);

        // Load program into DMEM (for .rodata and .data)
        $readmemh("program.hex", u_core.u_dmem.memory);

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Debug: Print instructions around failure
        $display("Instr at 770: %h", u_imem.memory[32'h770 >> 2]);
        $display("Instr at 774: %h", u_imem.memory[32'h774 >> 2]);
        $display("Instr at 778: %h", u_imem.memory[32'h778 >> 2]);
        $display("Instr at 77C: %h", u_imem.memory[32'h77C >> 2]);
        $display("Instr at 780: %h", u_imem.memory[32'h780 >> 2]);
        $display("Instr at 784: %h", u_imem.memory[32'h784 >> 2]);
        $display("Instr at 788: %h", u_imem.memory[32'h788 >> 2]);
        $display("Instr at 78C: %h", u_imem.memory[32'h78C >> 2]);
        $display("Instr at 790: %h", u_imem.memory[32'h790 >> 2]);
        $display("Instr at 794: %h", u_imem.memory[32'h794 >> 2]);

        // Run simulation for a few cycles
        #5000000;
        $finish;
    end

    // Monitor for X in PC
    always @(posedge clk) begin
        if ((^u_core.pc_curr === 1'bx) && rst_n) begin
            $display("Time: %0t | ERROR: PC became X!", $time);
            $finish; 
        end
    end

    // Trace
    always @(posedge clk) begin
        // Trace around the area of interest (PC 0x770)
        if (u_core.id_ex_pc >= 32'h760 && u_core.id_ex_pc <= 32'h7A0) begin
             $display("Time: %0t | PC_EX: %h | Op: %b | Stall: %b | MemRead_EX: %b | RD_EX: %d | RS1_ID: %d | RS2_ID: %d | FwdA: %b | FwdB: %b | Res: %h", 
                      $time, u_core.id_ex_pc, u_core.opcode, u_core.stall, u_core.id_ex_mem_read, u_core.id_ex_rd, u_core.rs1_id, u_core.rs2_id, u_core.forward_a, u_core.forward_b, u_core.alu_result_ex);
        end
    end

    // Simple Trace
    // always @(posedge clk) begin
    //     if (rst_n) begin
    //         $display("Time: %0t | PC_IF: %h | Instr: %h | Stall: %b | Flush: %b", 
    //                  $time, u_core.pc_curr, instr, u_core.stall, u_core.flush_branch);
    //     end
    // end


    // Debug Monitor
    // always @(posedge clk) begin
    //     if (u_core.pc_curr >= 32'h00000f90 && u_core.pc_curr <= 32'h00001060) begin
    //          $display("Time: %t, PC: %h, Instr: %h", $time, u_core.pc_curr, instr);
    //     end
    // end

    // Monitor
    // initial begin
    //     $monitor("Time=%0t | PC=%h | Instr=%h | Op=%b | rd=%d | rs1_d=%h | imm=%h | alu_res=%h | we=%b | wd=%h", 
    //              $time, pc_addr, instr, u_core.opcode, u_core.rd, u_core.rs1_data, u_core.imm, u_core.alu_result, u_core.reg_write, u_core.wdata);
    // end

    // Debug Monitor for Fibonacci
    // always @(posedge clk) begin
    //     if (u_core.pc_curr == 32'h00000360 || u_core.pc_curr == 32'h00000368) begin
    //          $display("Time: %t, PC: %h, s5=%h, s11=%h, Res=%h, WData=%h, RD=%d, WE=%b", 
    //                   $time, u_core.pc_curr, u_core.u_regfile.regs[21], u_core.u_regfile.regs[27], 
    //                   u_core.alu_result, u_core.wdata, u_core.rd, u_core.reg_write);
    //     end
    // end

endmodule
