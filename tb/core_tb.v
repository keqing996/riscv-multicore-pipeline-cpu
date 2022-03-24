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

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Run simulation for a few cycles
        #50000;
        $finish;
    end

    // Monitor
    // initial begin
    //     $monitor("Time=%0t | PC=%h | Instr=%h | Op=%b | rd=%d | rs1_d=%h | imm=%h | alu_res=%h | we=%b | wd=%h", 
    //              $time, pc_addr, instr, u_core.opcode, u_core.rd, u_core.rs1_data, u_core.imm, u_core.alu_result, u_core.reg_write, u_core.wdata);
    // end

endmodule
