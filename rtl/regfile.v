module regfile (
    input wire clk,
    input wire we,            // Write Enable
    input wire [4:0] rs1_addr, // Read Address 1
    input wire [4:0] rs2_addr, // Read Address 2
    input wire [4:0] rd_addr,  // Write Address
    input wire [31:0] wdata,   // Write Data
    output wire [31:0] rs1_data, // Read Data 1
    output wire [31:0] rs2_data  // Read Data 2
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
        if (we && (rd_addr != 5'b00000)) begin
            regs[rd_addr] <= wdata;
        end
    end

    // Read operation (Asynchronous) with Write-Through Forwarding
    assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 :
                      (we && (rs1_addr == rd_addr)) ? wdata : // Forwarding from WB
                      regs[rs1_addr];

    assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 :
                      (we && (rs2_addr == rd_addr)) ? wdata : // Forwarding from WB
                      regs[rs2_addr];

endmodule
