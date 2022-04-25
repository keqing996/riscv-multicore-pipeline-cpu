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

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Run simulation for a few cycles
        #1000000;
        $finish;
    end

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
