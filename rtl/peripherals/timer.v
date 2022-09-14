module timer (
    input wire clk,
    input wire rst_n,
    input wire write_enable,
    input wire [31:0] address,
    input wire [31:0] write_data,
    output reg [31:0] read_data,
    output reg interrupt_request
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
            if (write_enable) begin
                case (address)
                    32'h40004000: mtime[31:0]  <= write_data;
                    32'h40004004: mtime[63:32] <= write_data;
                    32'h40004008: mtimecmp[31:0]  <= write_data;
                    32'h4000400C: mtimecmp[63:32] <= write_data;
                endcase
            end
        end
    end

    // Read Logic
    always @(*) begin
        case (address)
            32'h40004000: read_data = mtime[31:0];
            32'h40004004: read_data = mtime[63:32];
            32'h40004008: read_data = mtimecmp[31:0];
            32'h4000400C: read_data = mtimecmp[63:32];
            default:      read_data = 32'b0;
        endcase
    end

    // Interrupt Logic
    always @(*) begin
        if (mtime >= mtimecmp) begin
            interrupt_request = 1'b1;
        end else begin
            interrupt_request = 1'b0;
        end
    end

endmodule
