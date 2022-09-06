module program_counter (
    input wire clk,
    input wire rst_n,      // Active low reset
    input wire [31:0] data_in, // Next PC value
    output reg [31:0] data_out // Current PC value
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 32'h00000000; // Reset address
        end else begin
            data_out <= data_in;
        end
    end

endmodule
