module bus_interconnect (
    input wire clk,
    input wire rst_n,

    // Master 0 Interface (Core 0)
    input wire [31:0] m0_addr,
    input wire [31:0] m0_wdata,
    input wire [3:0]  m0_wstrb,
    input wire        m0_write,
    input wire        m0_enable,
    output wire [31:0] m0_rdata,
    output wire       m0_ready,

    // Master 1 Interface (Core 1)
    input wire [31:0] m1_addr,
    input wire [31:0] m1_wdata,
    input wire [3:0]  m1_wstrb,
    input wire        m1_write,
    input wire        m1_enable,
    output wire [31:0] m1_rdata,
    output wire       m1_ready,

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

    // Internal Bus Signals (Output of Arbiter)
    wire [31:0] bus_addr;
    wire [31:0] bus_wdata;
    wire [3:0]  bus_wstrb;
    wire        bus_write;
    wire        bus_enable;
    reg [31:0]  bus_rdata;
    reg         bus_ready;

    // Instantiate Arbiter
    bus_arbiter u_bus_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        // Master 0
        .m0_addr(m0_addr),
        .m0_wdata(m0_wdata),
        .m0_wstrb(m0_wstrb),
        .m0_write(m0_write),
        .m0_enable(m0_enable),
        .m0_rdata(m0_rdata),
        .m0_ready(m0_ready),
        // Master 1
        .m1_addr(m1_addr),
        .m1_wdata(m1_wdata),
        .m1_wstrb(m1_wstrb),
        .m1_write(m1_write),
        .m1_enable(m1_enable),
        .m1_rdata(m1_rdata),
        .m1_ready(m1_ready),
        // Downstream
        .bus_addr(bus_addr),
        .bus_wdata(bus_wdata),
        .bus_wstrb(bus_wstrb),
        .bus_write(bus_write),
        .bus_enable(bus_enable),
        .bus_rdata(bus_rdata),
        .bus_ready(bus_ready)
    );

    // Address Decoding
    // 0: RAM  (Default)
    // 1: UART (0x4000_0000)
    // 2: Timer (0x4000_4000)
    
    reg [1:0] slave_sel;

    always @(*) begin
        if (bus_addr[31:16] == 16'h4000) begin
            if (bus_addr[15:14] == 2'b01) begin // 0x4000_4xxx -> Timer
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
    assign s0_addr = bus_addr;
    assign s0_wdata = bus_wdata;
    assign s0_wstrb = bus_wstrb;
    assign s0_write = bus_write;
    
    assign s1_addr = bus_addr;
    assign s1_wdata = bus_wdata;
    assign s1_wstrb = bus_wstrb;
    assign s1_write = bus_write;

    assign s2_addr = bus_addr;
    assign s2_wdata = bus_wdata;
    assign s2_wstrb = bus_wstrb;
    assign s2_write = bus_write;

    // Enable signals based on selection
    assign s0_enable = bus_enable && (slave_sel == 2'd0);
    assign s1_enable = bus_enable && (slave_sel == 2'd1);
    assign s2_enable = bus_enable && (slave_sel == 2'd2);

    // Muxing Slave Inputs to Master
    always @(*) begin
        case (slave_sel)
            2'd0: begin
                bus_rdata = s0_rdata;
                bus_ready = s0_ready;
            end
            2'd1: begin
                bus_rdata = s1_rdata;
                bus_ready = s1_ready;
            end
            2'd2: begin
                bus_rdata = s2_rdata;
                bus_ready = s2_ready;
            end
            default: begin
                bus_rdata = 32'b0;
                bus_ready = 1'b1; // Error response?
            end
        endcase
    end

endmodule
