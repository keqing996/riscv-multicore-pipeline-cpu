`timescale 1ns / 1ps

module l2_cache (
    input wire clk,
    input wire rst_n,

    // Bus Slave Interface
    input wire [31:0] s_addr,
    input wire [31:0] s_wdata,
    input wire [3:0]  s_be,
    input wire        s_we,
    input wire        s_en,
    output reg [31:0] s_rdata,
    output reg        s_ready,

    // Memory Interface
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    output reg [3:0]  mem_be,
    output reg        mem_we,
    output reg        mem_req,
    input wire [31:0] mem_rdata,
    input wire        mem_ready
);

    // Parameters
    parameter NUM_SETS = 1024; // 16KB / 16B
    parameter INDEX_BITS = 10; // log2(1024)
    parameter OFFSET_BITS = 4; // 16 bytes
    parameter TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS; // 18 bits

    // Cache Storage
    reg valid [0:NUM_SETS-1];
    reg [TAG_BITS-1:0] tag_array [0:NUM_SETS-1];
    reg [127:0] data_array [0:NUM_SETS-1]; // 16 bytes per block

    // Address Decomposition
    wire [INDEX_BITS-1:0] index = s_addr[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    wire [TAG_BITS-1:0] tag = s_addr[31 : 31-TAG_BITS+1];
    wire [1:0] word_offset = s_addr[3:2];

    // Hit Detection
    wire valid_bit = valid[index];
    wire [TAG_BITS-1:0] stored_tag = tag_array[index];
    wire hit = valid_bit && (stored_tag == tag);

    // Read Data Extraction
    wire [127:0] block_data = data_array[index];
    reg [31:0] hit_data;

    always @(*) begin
        case (word_offset)
            2'b00: hit_data = block_data[31:0];
            2'b01: hit_data = block_data[63:32];
            2'b10: hit_data = block_data[95:64];
            2'b11: hit_data = block_data[127:96];
        endcase
    end

    // FSM State
    localparam STATE_IDLE = 3'd0;
    localparam STATE_FETCH_0 = 3'd1;
    localparam STATE_FETCH_1 = 3'd2;
    localparam STATE_FETCH_2 = 3'd3;
    localparam STATE_FETCH_3 = 3'd4;
    localparam STATE_UPDATE = 3'd5;
    localparam STATE_WRITE  = 3'd6;

    reg [2:0] state, next_state;
    reg [127:0] refill_buffer;
    reg [127:0] next_refill_buffer;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            refill_buffer <= 0;
        end else begin
            state <= next_state;
            refill_buffer <= next_refill_buffer;
            if (s_en || state != STATE_IDLE) begin
                 $display("%m: state=%d addr=%h we=%b hit=%b mem_ready=%b mem_rdata=%h s_ready=%b s_rdata=%h time=%t", 
                          state, s_addr, s_we, hit, mem_ready, mem_rdata, s_ready, s_rdata, $time);
            end
        end
    end

    // Initialization for simulation
    integer i;
    initial begin
        for (i = 0; i < NUM_SETS; i = i + 1) begin
            valid[i] = 0;
            tag_array[i] = 0;
            data_array[i] = 0;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        next_refill_buffer = refill_buffer;
        
        s_ready = 0;
        s_rdata = 0;
        
        mem_req = 0;
        mem_addr = 0;
        mem_wdata = 0;
        mem_be = 0;
        mem_we = 0;

        case (state)
            STATE_IDLE: begin
                if (s_en && !s_we) begin // Read
                    if (hit) begin
                        s_ready = 1;
                        s_rdata = hit_data;
                    end else begin
                        s_ready = 0; // Stall
                        next_state = STATE_FETCH_0;
                    end
                end else if (s_en && s_we) begin // Write
                    s_ready = 0; // Stall for write-through
                    next_state = STATE_WRITE;
                end
            end

            STATE_FETCH_0: begin
                mem_req = 1;
                mem_we = 0;
                mem_addr = {s_addr[31:4], 4'b0000}; // Word 0
                if (mem_ready) begin
                    next_refill_buffer[31:0] = mem_rdata;
                    next_state = STATE_FETCH_1;
                end
            end

            STATE_FETCH_1: begin
                mem_req = 1;
                mem_we = 0;
                mem_addr = {s_addr[31:4], 4'b0100}; // Word 1
                if (mem_ready) begin
                    next_refill_buffer[63:32] = mem_rdata;
                    next_state = STATE_FETCH_2;
                end
            end

            STATE_FETCH_2: begin
                mem_req = 1;
                mem_we = 0;
                mem_addr = {s_addr[31:4], 4'b1000}; // Word 2
                if (mem_ready) begin
                    next_refill_buffer[95:64] = mem_rdata;
                    next_state = STATE_FETCH_3;
                end
            end

            STATE_FETCH_3: begin
                mem_req = 1;
                mem_we = 0;
                mem_addr = {s_addr[31:4], 4'b1100}; // Word 3
                if (mem_ready) begin
                    next_refill_buffer[127:96] = mem_rdata;
                    next_state = STATE_UPDATE;
                end
            end

            STATE_UPDATE: begin
                // Update Cache
                next_state = STATE_IDLE;
            end

            STATE_WRITE: begin
                // Write-through to memory
                mem_req = 1;
                mem_we = 1;
                mem_addr = s_addr;
                mem_wdata = s_wdata;
                mem_be = s_be;
                
                if (mem_ready) begin
                    s_ready = 1; // Done
                    next_state = STATE_IDLE;
                end
            end
        endcase
    end

    // Cache Update Logic (Sequential)
    always @(posedge clk) begin
        if (state == STATE_UPDATE) begin
            valid[index] <= 1;
            tag_array[index] <= tag;
            data_array[index] <= refill_buffer;
        end else if (state == STATE_WRITE && mem_ready) begin
            // Update cache on write hit (Write-Update / Write-Through)
            if (hit) begin

                if (word_offset == 2'b00) begin
                    if (s_be[0]) data_array[index][7:0]   <= s_wdata[7:0];
                    if (s_be[1]) data_array[index][15:8]  <= s_wdata[15:8];
                    if (s_be[2]) data_array[index][23:16] <= s_wdata[23:16];
                    if (s_be[3]) data_array[index][31:24] <= s_wdata[31:24];
                end else if (word_offset == 2'b01) begin
                    if (s_be[0]) data_array[index][39:32] <= s_wdata[7:0];
                    if (s_be[1]) data_array[index][47:40] <= s_wdata[15:8];
                    if (s_be[2]) data_array[index][55:48] <= s_wdata[23:16];
                    if (s_be[3]) data_array[index][63:56] <= s_wdata[31:24];
                end else if (word_offset == 2'b10) begin
                    if (s_be[0]) data_array[index][71:64] <= s_wdata[7:0];
                    if (s_be[1]) data_array[index][79:72] <= s_wdata[15:8];
                    if (s_be[2]) data_array[index][87:80] <= s_wdata[23:16];
                    if (s_be[3]) data_array[index][95:88] <= s_wdata[31:24];
                end else if (word_offset == 2'b11) begin
                    if (s_be[0]) data_array[index][103:96] <= s_wdata[7:0];
                    if (s_be[1]) data_array[index][111:104] <= s_wdata[15:8];
                    if (s_be[2]) data_array[index][119:112] <= s_wdata[23:16];
                    if (s_be[3]) data_array[index][127:120] <= s_wdata[31:24];
                end
            end
        end
    end

endmodule
