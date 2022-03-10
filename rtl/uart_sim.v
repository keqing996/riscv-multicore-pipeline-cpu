module uart_sim (
    input wire clk,
    input wire we,
    input wire [31:0] addr,
    input wire [31:0] wdata
);

    // Simple UART simulation model
    // Writes to 0x40000000 will be printed to stdout
    
    always @(posedge clk) begin
        if (we && addr == 32'h40000000) begin
            $write("%c", wdata[7:0]);
        end
    end

endmodule
