`timescale 1ns / 1ps

module l1_arbiter (
    input wire clk,
    input wire rst_n,

    // I-Cache Interface (Read Only)
    input wire [31:0] icache_addr,
    input wire        icache_req,
    output reg [31:0] icache_rdata,
    output reg        icache_ready,

    // D-Cache Interface (Read/Write)
    input wire [31:0] dcache_addr,
    input wire [31:0] dcache_wdata,
    input wire [3:0]  dcache_be,
    input wire        dcache_we,
    input wire        dcache_req,
    output reg [31:0] dcache_rdata,
    output reg        dcache_ready,

    // Master Interface (to System Bus)
    output reg [31:0] m_addr,
    output reg [31:0] m_wdata,
    output reg [3:0]  m_be,
    output reg        m_we,
    output reg        m_req,
    input wire [31:0] m_rdata,
    input wire        m_ready
);

    // State Definition
    localparam STATE_IDLE = 2'd0;
    localparam STATE_ICACHE = 2'd1;
    localparam STATE_DCACHE = 2'd2;

    reg [1:0] state, next_state;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State and Output Logic
    always @(*) begin
        // Default Outputs
        next_state = state;
        
        // Cache Outputs
        icache_ready = 0;
        icache_rdata = 0;
        dcache_ready = 0;
        dcache_rdata = 0;

        // Bus Outputs
        m_addr = 0;
        m_wdata = 0;
        m_be = 0;
        m_we = 0;
        m_req = 0;

        case (state)
            STATE_IDLE: begin
                if (dcache_req) begin
                    // D-Cache has priority
                    next_state = STATE_DCACHE;
                    // Pass through immediately to save a cycle? 
                    // For now, let's register the state transition to be safe and simple.
                    // Or we can do combinational output for request.
                    
                    m_addr = dcache_addr;
                    m_wdata = dcache_wdata;
                    m_be = dcache_be;
                    m_we = dcache_we;
                    m_req = 1;
                end else if (icache_req) begin
                    next_state = STATE_ICACHE;
                    
                    m_addr = icache_addr;
                    m_wdata = 0;
                    m_be = 4'b1111; // Read all bytes
                    m_we = 0;
                    m_req = 1;
                end
            end

            STATE_DCACHE: begin
                // Maintain connection to D-Cache
                m_addr = dcache_addr;
                m_wdata = dcache_wdata;
                m_be = dcache_be;
                m_we = dcache_we;
                m_req = 1; // Keep request high until ready

                if (m_ready) begin
                    dcache_rdata = m_rdata;
                    dcache_ready = 1;
                    next_state = STATE_IDLE;
                end
            end

            STATE_ICACHE: begin
                // Maintain connection to I-Cache
                m_addr = icache_addr;
                m_wdata = 0;
                m_be = 4'b1111;
                m_we = 0;
                m_req = 1;

                if (m_ready) begin
                    icache_rdata = m_rdata;
                    icache_ready = 1;
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end

endmodule
