module bus_interconnect (
    // Master Interface (CPU/LSU)
    input wire [31:0] m_addr,
    input wire [31:0] m_wdata,
    input wire [3:0]  m_wstrb,
    input wire        m_write,
    input wire        m_enable,
    output reg [31:0] m_rdata,
    output reg        m_ready,

    // Slave 0 Interface (Data Cache / RAM)
    // Address Range: 0x0000_0000 - 0x3FFF_FFFF
    output wire [31:0] s0_addr,
    output wire [31:0] s0_wdata,
    output wire [3:0]  s0_wstrb,
    output wire        s0_write,
    output wire        s0_enable,
    input wire [31:0]  s0_rdata,
    input wire         s0_ready,

    // Slave 1 Interface (UART)
    // Address Range: 0x4000_0000 - 0x4000_3FFF
    output wire [31:0] s1_addr,
    output wire [31:0] s1_wdata,
    output wire [3:0]  s1_wstrb,
    output wire        s1_write,
    output wire        s1_enable,
    input wire [31:0]  s1_rdata,
    input wire         s1_ready,

    // Slave 2 Interface (Timer)
    // Address Range: 0x4000_4000 - 0x4000_7FFF
    output wire [31:0] s2_addr,
    output wire [31:0] s2_wdata,
    output wire [3:0]  s2_wstrb,
    output wire        s2_write,
    output wire        s2_enable,
    input wire [31:0]  s2_rdata,
    input wire         s2_ready
);

    // Address Decoding
    // 0: RAM  (Default)
    // 1: UART (0x4000_0000)
    // 2: Timer (0x4000_4000)
    
    reg [1:0] slave_sel;

    always @(*) begin
        if (m_addr[31:16] == 16'h4000) begin
            if (m_addr[15:14] == 2'b01) begin // 0x4000_4xxx -> Timer
                slave_sel = 2'd2;
            end else begin // 0x4000_0xxx -> UART (Simplified)
                slave_sel = 2'd1;
            end
        end else begin
            slave_sel = 2'd0; // RAM
        end
    end

    // Muxing Master Outputs to Slaves
    // Common signals
    assign s0_addr = m_addr;
    assign s0_wdata = m_wdata;
    assign s0_wstrb = m_wstrb;
    assign s0_write = m_write;
    
    assign s1_addr = m_addr;
    assign s1_wdata = m_wdata;
    assign s1_wstrb = m_wstrb;
    assign s1_write = m_write;

    assign s2_addr = m_addr;
    assign s2_wdata = m_wdata;
    assign s2_wstrb = m_wstrb;
    assign s2_write = m_write;

    // Enable signals based on selection
    assign s0_enable = m_enable && (slave_sel == 2'd0);
    assign s1_enable = m_enable && (slave_sel == 2'd1);
    assign s2_enable = m_enable && (slave_sel == 2'd2);

    // Muxing Slave Inputs to Master
    always @(*) begin
        case (slave_sel)
            2'd0: begin
                m_rdata = s0_rdata;
                m_ready = s0_ready;
            end
            2'd1: begin
                m_rdata = s1_rdata;
                m_ready = s1_ready;
            end
            2'd2: begin
                m_rdata = s2_rdata;
                m_ready = s2_ready;
            end
            default: begin
                m_rdata = 32'b0;
                m_ready = 1'b1; // Error response?
            end
        endcase
    end

endmodule
