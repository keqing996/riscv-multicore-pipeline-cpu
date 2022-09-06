module regfile (
    input wire clk,
    input wire write_enable,
    input wire [4:0] rs1_index,
    input wire [4:0] rs2_index,
    input wire [4:0] rd_index,
    input wire [31:0] write_data,
    output wire [31:0] rs1_read_data,
    output wire [31:0] rs2_read_data
);

    // 32 registers of 32-bit width
    reg [31:0] regs [0:31];

    integer i;

    // Initialize registers to 0
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 32'h0;
        end
        regs[2] = 32'h02000000; // Initialize SP to 32MB
    end

    // Write operation (Synchronous)
    // Note: x0 is hardwired to 0, so we never write to it.
    always @(posedge clk) begin
        if (write_enable && (rd_index != 5'b00000)) begin
            regs[rd_index] <= write_data;
        end
    end

    // Read operation (Asynchronous) with Write-Through Forwarding
    assign rs1_read_data = (rs1_index == 5'b0) ? 32'b0 :
                           (write_enable && (rs1_index == rd_index)) ? write_data : // Forwarding from WB
                           regs[rs1_index];

    assign rs2_read_data = (rs2_index == 5'b0) ? 32'b0 :
                           (write_enable && (rs2_index == rd_index)) ? write_data : // Forwarding from WB
                           regs[rs2_index];

endmodule
