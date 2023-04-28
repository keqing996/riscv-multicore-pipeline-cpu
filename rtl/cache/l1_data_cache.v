module l1_data_cache (
    input wire clk,
    input wire rst_n,

    // CPU Interface
    input wire [31:0] cpu_address,
    input wire [31:0] cpu_write_data,
    input wire [3:0]  cpu_byte_enable,
    input wire        cpu_write_enable,
    input wire        cpu_read_enable, 
    output reg [31:0] cpu_read_data,
    output reg        stall_cpu,

    // Memory Interface
    output reg [31:0] mem_address,
    output reg [31:0] mem_write_data,
    output reg [3:0]  mem_byte_enable,
    output reg        mem_write_enable,
    output reg        mem_request,
    input wire [31:0] mem_read_data,
    input wire        mem_ready
);

    // Parameters
    parameter NUM_SETS = 256; // 4KB / 16B
    parameter INDEX_BITS = 8; // log2(256)
    parameter OFFSET_BITS = 4; // 16 bytes
    parameter TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS; // 20 bits

    // Cache Storage
    reg valid [0:NUM_SETS-1];
    reg [TAG_BITS-1:0] tag_array [0:NUM_SETS-1];
    reg [127:0] data_array [0:NUM_SETS-1]; // 16 bytes per block

    // Address Decomposition
    wire [INDEX_BITS-1:0] index = cpu_address[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    wire [TAG_BITS-1:0] tag = cpu_address[31 : 31-TAG_BITS+1];
    wire [1:0] word_offset = cpu_address[3:2];

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
    localparam STATE_ACCESS_DONE = 3'd7;

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
            if (cpu_read_enable || cpu_write_enable || state != STATE_IDLE) begin
                 $display("%m: state=%d, addr=%h, we=%b, re=%b, hit=%b, mem_ready=%b, mem_rdata=%h, cpu_rdata=%h", 
                          state, cpu_address, cpu_write_enable, cpu_read_enable, hit, mem_ready, mem_read_data, cpu_read_data);
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
        
        stall_cpu = 0;
        cpu_read_data = 0;
        
        mem_request = 0;
        mem_address = 0;
        mem_write_data = 0;
        mem_byte_enable = 0;
        mem_write_enable = 0;

        case (state)
            STATE_IDLE: begin
                if (cpu_read_enable) begin
                    if (hit) begin
                        stall_cpu = 0;
                        cpu_read_data = hit_data;
                    end else begin
                        stall_cpu = 1; // Stall!
                        next_state = STATE_FETCH_0;
                    end
                end else if (cpu_write_enable) begin
                    stall_cpu = 1; // Stall for write-through
                    next_state = STATE_WRITE;
                end
            end

            STATE_FETCH_0: begin
                stall_cpu = 1;
                mem_request = 1;
                mem_write_enable = 0;
                mem_address = {cpu_address[31:4], 4'b0000}; // Word 0
                if (mem_ready) begin
                    next_refill_buffer[31:0] = mem_read_data;
                    next_state = STATE_FETCH_1;
                end
            end

            STATE_FETCH_1: begin
                stall_cpu = 1;
                mem_request = 1;
                mem_write_enable = 0;
                mem_address = {cpu_address[31:4], 4'b0100}; // Word 1
                if (mem_ready) begin
                    next_refill_buffer[63:32] = mem_read_data;
                    next_state = STATE_FETCH_2;
                end
            end

            STATE_FETCH_2: begin
                stall_cpu = 1;
                mem_request = 1;
                mem_write_enable = 0;
                mem_address = {cpu_address[31:4], 4'b1000}; // Word 2
                if (mem_ready) begin
                    next_refill_buffer[95:64] = mem_read_data;
                    next_state = STATE_FETCH_3;
                end
            end

            STATE_FETCH_3: begin
                stall_cpu = 1;
                mem_request = 1;
                mem_write_enable = 0;
                mem_address = {cpu_address[31:4], 4'b1100}; // Word 3
                if (mem_ready) begin
                    next_refill_buffer[127:96] = mem_read_data;
                    next_state = STATE_UPDATE;
                end
            end

            STATE_UPDATE: begin
                stall_cpu = 1;
                next_state = STATE_IDLE;
            end

            STATE_WRITE: begin
                stall_cpu = 1;
                mem_request = 1;
                mem_write_enable = 1;
                mem_address = cpu_address;
                mem_write_data = cpu_write_data;
                mem_byte_enable = cpu_byte_enable;
                
                if (mem_ready) begin
                    next_state = STATE_ACCESS_DONE;
                end
            end

            STATE_ACCESS_DONE: begin
                stall_cpu = 0;
                next_state = STATE_IDLE;
            end
        endcase
    end

    // Cache Update Logic (Synchronous)
    always @(posedge clk) begin
        if (state == STATE_UPDATE) begin
            valid[index] <= 1;
            tag_array[index] <= tag;
            data_array[index] <= refill_buffer;
        end else if (state == STATE_WRITE && mem_ready) begin
            // Write-Through: If it was a hit, we must update the cache too!
            // If it was a miss, we don't allocate (No-Write-Allocate), so we don't touch cache.
            if (hit) begin
                case (word_offset)
                    2'b00: begin
                        if (cpu_byte_enable[0]) data_array[index][7:0]   <= cpu_write_data[7:0];
                        if (cpu_byte_enable[1]) data_array[index][15:8]  <= cpu_write_data[15:8];
                        if (cpu_byte_enable[2]) data_array[index][23:16] <= cpu_write_data[23:16];
                        if (cpu_byte_enable[3]) data_array[index][31:24] <= cpu_write_data[31:24];
                    end
                    2'b01: begin
                        if (cpu_byte_enable[0]) data_array[index][39:32] <= cpu_write_data[7:0];
                        if (cpu_byte_enable[1]) data_array[index][47:40] <= cpu_write_data[15:8];
                        if (cpu_byte_enable[2]) data_array[index][55:48] <= cpu_write_data[23:16];
                        if (cpu_byte_enable[3]) data_array[index][63:56] <= cpu_write_data[31:24];
                    end
                    2'b10: begin
                        if (cpu_byte_enable[0]) data_array[index][71:64] <= cpu_write_data[7:0];
                        if (cpu_byte_enable[1]) data_array[index][79:72] <= cpu_write_data[15:8];
                        if (cpu_byte_enable[2]) data_array[index][87:80] <= cpu_write_data[23:16];
                        if (cpu_byte_enable[3]) data_array[index][95:88] <= cpu_write_data[31:24];
                    end
                    2'b11: begin
                        if (cpu_byte_enable[0]) data_array[index][103:96]  <= cpu_write_data[7:0];
                        if (cpu_byte_enable[1]) data_array[index][111:104] <= cpu_write_data[15:8];
                        if (cpu_byte_enable[2]) data_array[index][119:112] <= cpu_write_data[23:16];
                        if (cpu_byte_enable[3]) data_array[index][127:120] <= cpu_write_data[31:24];
                    end
                endcase
            end
        end
    end

endmodule
