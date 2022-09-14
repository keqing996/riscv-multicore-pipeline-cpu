module data_memory (
    input wire clk,
    input wire [3:0] byte_enable,
    input wire [31:0] address,
    input wire [31:0] write_data,
    output wire [31:0] read_data
);

    // 32MB Memory
    reg [31:0] memory [0:8388607];

    integer i;
    initial begin
        for (i = 0; i < 8388608; i = i + 1) begin
            memory[i] = 0;
        end
    end

    wire [22:0] word_addr = address[24:2];

    // Write (Synchronous)
    always @(posedge clk) begin
        if (byte_enable[0]) memory[word_addr][7:0]   <= write_data[7:0];
        if (byte_enable[1]) memory[word_addr][15:8]  <= write_data[15:8];
        if (byte_enable[2]) memory[word_addr][23:16] <= write_data[23:16];
        if (byte_enable[3]) memory[word_addr][31:24] <= write_data[31:24];
    end

    // Read (Asynchronous/Combinational)
    assign read_data = memory[word_addr];

endmodule
