`timescale 1ns / 1ps

module simple_tb;

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
        $dumpfile("simple_wave.vcd");
        $dumpvars(0, simple_tb);

        // Load program into IMEM
        $readmemh("program.hex", u_imem.memory);

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Run for a few cycles
        #200;
        
        // Verification
        if (u_core.u_regfile.regs[3] === 32'd30) begin
            $display("[PASS]");
        end else begin
            $display("[FAIL] x3 = %d (Expected 30)", u_core.u_regfile.regs[3]);
        end
        
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (rst_n) begin
            $display("Time: %0t | PC: %h | Instr: %h | Stall: %b | Op: %b | RD: %d | Res: %h | RegWrite: %b", 
                     $time, u_core.pc_curr, instr, u_core.stall, u_core.opcode, u_core.mem_wb_rd, u_core.wdata_wb, u_core.mem_wb_reg_write);
        end
    end

endmodule
