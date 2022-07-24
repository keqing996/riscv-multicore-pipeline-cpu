module pc (
    input wire clk,
    input wire rst_n,      // Active low reset
    input wire [31:0] din, // Next PC value
    output reg [31:0] dout // Current PC value
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= 32'h00000000; // Reset address
        end else begin
            dout <= din;
        end
    end

endmodule
