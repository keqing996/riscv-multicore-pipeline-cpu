`timescale 1ns / 1ps

module pc_tb;

    // Signal definition
    reg clk;
    reg rst_n;
    reg [31:0] din;
    wire [31:0] dout;

    // Instantiate DUT
    pc u_pc (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .dout(dout)
    );

    // Clock generation (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test logic
    initial begin
        // 1. Initialize and generate wave file
        $dumpfile("wave.vcd"); // Output path
        $dumpvars(0, pc_tb);       // Dump all signals

        // 2. Reset test
        rst_n = 0;
        din = 32'h0;
        #20;
        rst_n = 1;

        // 3. Input data test
        #10 din = 32'h00000004; // PC + 4
        #10 din = 32'h00000008;
        #10 din = 32'h0000000C;
        #10 din = 32'h80000000; // Jump

        // 4. End simulation
        #50;
        $finish;
    end

    // Monitor output
    initial begin
        $monitor("Time=%0t | rst_n=%b | din=%h | dout=%h", $time, rst_n, din, dout);
    end

endmodule
