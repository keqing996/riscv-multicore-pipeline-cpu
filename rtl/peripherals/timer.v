module timer (
    input wire clk,
    input wire rst_n,
    input wire we,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata,
    output reg irq
);

    // Memory Map
    // 0x40004000: mtime (Low)
    // 0x40004004: mtime (High)
    // 0x40004008: mtimecmp (Low)
    // 0x4000400C: mtimecmp (High)

    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mtime <= 64'd0;
            mtimecmp <= 64'hFFFFFFFFFFFFFFFF; // Max value to prevent immediate interrupt
        end else begin
            // Increment timer
            mtime <= mtime + 1;

            // Write Logic
            if (we) begin
                case (addr)
                    32'h40004000: mtime[31:0]  <= wdata;
                    32'h40004004: mtime[63:32] <= wdata;
                    32'h40004008: mtimecmp[31:0]  <= wdata;
                    32'h4000400C: mtimecmp[63:32] <= wdata;
                endcase
            end
        end
    end

    // Read Logic
    always @(*) begin
        case (addr)
            32'h40004000: rdata = mtime[31:0];
            32'h40004004: rdata = mtime[63:32];
            32'h40004008: rdata = mtimecmp[31:0];
            32'h4000400C: rdata = mtimecmp[63:32];
            default:      rdata = 32'b0;
        endcase
    end

    // Interrupt Logic
    always @(*) begin
        if (mtime >= mtimecmp) begin
            irq = 1'b1;
        end else begin
            irq = 1'b0;
        end
    end

endmodule
