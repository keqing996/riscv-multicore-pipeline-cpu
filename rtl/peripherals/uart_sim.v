module uart_simulator (
    input wire clk,
    input wire write_enable,
    input wire [31:0] address,
    input wire [31:0] write_data
);

    // Simple UART simulation model
    // Writes to 0x40000000 will be printed to stdout
    
    always @(posedge clk) begin
        if (write_enable && address == 32'h40000000) begin
            $write("%c", write_data[7:0]);
        end
    end

endmodule
