module dmem (
    input wire clk,
    input wire we,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output wire [31:0] rdata
);

    // 16KB Memory
    reg [31:0] memory [0:4095];

    // Write (Synchronous)
    always @(posedge clk) begin
        if (we) begin
            // Word aligned access, masked to 16KB
            memory[addr[13:2]] <= wdata;
        end
    end

    // Read (Asynchronous/Combinational)
    assign rdata = memory[addr[13:2]];

endmodule
