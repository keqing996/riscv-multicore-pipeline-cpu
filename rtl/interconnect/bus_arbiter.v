`timescale 1ns / 1ps

module bus_arbiter (
    input wire clk,
    input wire rst_n,

    // Master 0 Interface
    input wire [31:0] m0_addr,
    input wire [31:0] m0_wdata,
    input wire [3:0]  m0_wstrb,
    input wire        m0_write,
    input wire        m0_enable,
    output reg [31:0] m0_rdata,
    output reg        m0_ready,

    // Master 1 Interface
    input wire [31:0] m1_addr,
    input wire [31:0] m1_wdata,
    input wire [3:0]  m1_wstrb,
    input wire        m1_write,
    input wire        m1_enable,
    output reg [31:0] m1_rdata,
    output reg        m1_ready,

    // Downstream Interface (to Bus Interconnect)
    output reg [31:0] bus_addr,
    output reg [31:0] bus_wdata,
    output reg [3:0]  bus_wstrb,
    output reg        bus_write,
    output reg        bus_enable,
    input wire [31:0] bus_rdata,
    input wire        bus_ready
);

    // State Definition
    localparam OWNER_NONE = 2'd0;
    localparam OWNER_M0   = 2'd1;
    localparam OWNER_M1   = 2'd2;

    reg [1:0] current_owner;
    reg       priority_m1; // 0: M0 has priority, 1: M1 has priority

    // Next State Logic
    reg [1:0] next_owner;
    reg [1:0] winner;
    
    always @(*) begin
        next_owner = current_owner;
        winner = OWNER_NONE;
        
        case (current_owner)
            OWNER_NONE: begin
                // Determine who would win arbitration in this cycle
                if (m0_enable && m1_enable) begin
                    winner = priority_m1 ? OWNER_M1 : OWNER_M0;
                end else if (m0_enable) begin
                    winner = OWNER_M0;
                end else if (m1_enable) begin
                    winner = OWNER_M1;
                end
                
                // If the winner finishes immediately (ready=1), we need to decide next_owner for NEXT cycle.
                if (bus_ready && winner != OWNER_NONE) begin
                    // If winner was M0, next preference is M1.
                    if (winner == OWNER_M0) begin
                        if (m1_enable) next_owner = OWNER_M1;
                        else if (m0_enable) next_owner = OWNER_M0;
                        else next_owner = OWNER_NONE;
                    end else begin // Winner was M1
                        if (m0_enable) next_owner = OWNER_M0;
                        else if (m1_enable) next_owner = OWNER_M1;
                        else next_owner = OWNER_NONE;
                    end
                end else begin
                    // Winner didn't finish, or no winner.
                    // If winner exists, they become the owner.
                    next_owner = winner;
                end
            end
            
            OWNER_M0: begin
                // If M0 drops enable, release immediately
                if (!m0_enable) begin
                    if (m1_enable) next_owner = OWNER_M1;
                    else next_owner = OWNER_NONE;
                end
                // If transaction finishes (ready=1), we can switch
                else if (bus_ready) begin
                    // Check if M1 wants it (Round Robin)
                    if (m1_enable) begin
                        next_owner = OWNER_M1;
                    end else if (m0_enable) begin
                        next_owner = OWNER_M0; // Keep M0 if M1 doesn't want it
                    end else begin
                        next_owner = OWNER_NONE;
                    end
                end
                // Else keep M0
            end
            
            OWNER_M1: begin
                // If M1 drops enable, release immediately
                if (!m1_enable) begin
                    if (m0_enable) next_owner = OWNER_M0;
                    else next_owner = OWNER_NONE;
                end
                else if (bus_ready) begin
                    // Check if M0 wants it
                    if (m0_enable) begin
                        next_owner = OWNER_M0;
                    end else if (m1_enable) begin
                        next_owner = OWNER_M1;
                    end else begin
                        next_owner = OWNER_NONE;
                    end
                end
            end
        endcase
    end

    // State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_owner <= OWNER_NONE;
            priority_m1 <= 0;
        end else begin
            current_owner <= next_owner;
            // Update priority only when switching owners or completing a transaction
            if (bus_ready && bus_enable) begin
                if (effective_owner == OWNER_M0) priority_m1 <= 1;
                if (effective_owner == OWNER_M1) priority_m1 <= 0;
            end
            
            if (m0_enable || m1_enable || bus_enable) begin
                 $display("BusArbiter: time=%t owner=%d eff=%d addr=%h ready=%b m0_en=%b m1_en=%b", 
                          $time, current_owner, effective_owner, bus_addr, bus_ready, m0_enable, m1_enable);
            end
        end
    end


    // Output Muxing
    // Use registered current_owner to avoid combinational loops.
    // This adds 1 cycle latency for arbitration but ensures stability.
    wire [1:0] effective_owner = current_owner;

    always @(*) begin
        // Defaults
        bus_addr = 0;
        bus_wdata = 0;
        bus_wstrb = 0;
        bus_write = 0;
        bus_enable = 0;
        
        m0_rdata = 0;
        m0_ready = 0;
        m1_rdata = 0;
        m1_ready = 0;

        case (effective_owner)
            OWNER_M0: begin
                bus_addr   = m0_addr;
                bus_wdata  = m0_wdata;
                bus_wstrb  = m0_wstrb;
                bus_write  = m0_write;
                bus_enable = m0_enable;
                
                m0_rdata   = bus_rdata;
                m0_ready   = bus_ready;
            end
            OWNER_M1: begin
                bus_addr   = m1_addr;
                bus_wdata  = m1_wdata;
                bus_wstrb  = m1_wstrb;
                bus_write  = m1_write;
                bus_enable = m1_enable;
                
                m1_rdata   = bus_rdata;
                m1_ready   = bus_ready;
            end
            default: begin
                // No owner
            end
        endcase
    end

endmodule
