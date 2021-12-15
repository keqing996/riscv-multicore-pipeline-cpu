`timescale 1ns / 1ps

module imem_tb;

    reg [31:0] addr;
    wire [31:0] data;

    imem u_imem (
        .addr(addr),
        .data(data)
    );

    initial begin
        $dumpfile("sim/wave.vcd");
        $dumpvars(0, imem_tb);

        // Test cases
        // Note: We need a "program.hex" file in the sim folder for this to work
        
        // Read address 0
        addr = 32'h00000000;
        #10;
        if (data !== 32'hdeadbeef) $display("Error at addr 0: %h", data);
        else $display("Addr 0: %h (OK)", data);

        // Read address 4
        addr = 32'h00000004;
        #10;
        if (data !== 32'hcafebabe) $display("Error at addr 4: %h", data);
        else $display("Addr 4: %h (OK)", data);

        // Read address 8
        addr = 32'h00000008;
        #10;

        $finish;
    end

endmodule
