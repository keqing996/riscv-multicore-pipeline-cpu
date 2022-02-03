module dmem (
    input wire clk,
    input wire we,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output wire [31:0] rdata
);

    // 4KB Memory
    reg [31:0] memory [0:1023];

    // Write (Synchronous)
    always @(posedge clk) begin
        if (we) begin
            // Word aligned access
            memory[addr[31:2]] <= wdata;
        end
    end

    // Read (Asynchronous/Combinational)
    assign rdata = memory[addr[31:2]];

endmodule
