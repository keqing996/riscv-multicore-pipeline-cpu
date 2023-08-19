module l1_inst_cache (
    input wire clk,
    input wire rst_n,
    input wire [31:0] hart_id, // Debug

    // CPU Interface
    input wire [31:0] program_counter_address,
    output reg [31:0] instruction,
    output reg stall_cpu, // 1 if miss (stall CPU), 0 if hit

    // Memory Interface (32-bit)
    output reg [31:0] instruction_memory_address,
    output reg instruction_memory_request,
    input wire [31:0] instruction_memory_read_data,
    input wire instruction_memory_ready
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

    // Address Decomposition - use current PC in IDLE, latched address during fill
    wire [INDEX_BITS-1:0] index = program_counter_address[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    wire [TAG_BITS-1:0] tag = program_counter_address[31 : 31-TAG_BITS+1];
    wire [1:0] word_offset = program_counter_address[3:2];

    // Hit Detection - always use current PC for hit checking
    wire valid_bit = valid[index];
    wire [TAG_BITS-1:0] stored_tag = tag_array[index];
    wire hit = valid_bit && (stored_tag == tag);

    // Read Data Extraction - use current PC in IDLE, latched during fill
    wire [127:0] block_data = data_array[active_index];
    reg [31:0] hit_data;

    always @(*) begin
        case (active_word_offset)
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

    reg [2:0] state, next_state;
    reg [127:0] refill_buffer;
    reg [127:0] next_refill_buffer;
    
    // Latch the PC address during a miss to maintain consistent index/tag during fill
    reg [31:0] miss_address;
    reg [31:0] next_miss_address;
    
    // Use latched address during fill, current address when IDLE
    wire [31:0] active_address = (state == STATE_IDLE) ? program_counter_address : miss_address;
    wire [INDEX_BITS-1:0] active_index = active_address[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    wire [TAG_BITS-1:0] active_tag = active_address[31 : 31-TAG_BITS+1];
    wire [1:0] active_word_offset = active_address[3:2];

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            refill_buffer <= 0;
            miss_address <= 0;
        end else begin
            state <= next_state;
            refill_buffer <= next_refill_buffer;
            miss_address <= next_miss_address;
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
        next_miss_address = miss_address;
        
        stall_cpu = 0;
        instruction = 0;
        instruction_memory_request = 0;
        instruction_memory_address = 0;

        case (state)
            STATE_IDLE: begin
                if (hit) begin
                    stall_cpu = 0;
                    instruction = hit_data;
                end else begin
                    stall_cpu = 1; // Stall!
                    next_miss_address = program_counter_address; // Latch the miss address
                    next_state = STATE_FETCH_0;
                end
            end

            STATE_FETCH_0: begin
                stall_cpu = 1;
                instruction_memory_request = 1;
                instruction_memory_address = {active_address[31:4], 4'b0000}; // Word 0
                if (instruction_memory_ready) begin
                    next_refill_buffer[31:0] = instruction_memory_read_data;
                    next_state = STATE_FETCH_1;
                end
            end

            STATE_FETCH_1: begin
                stall_cpu = 1;
                instruction_memory_request = 1;
                instruction_memory_address = {active_address[31:4], 4'b0100}; // Word 1
                if (instruction_memory_ready) begin
                    next_refill_buffer[63:32] = instruction_memory_read_data;
                    next_state = STATE_FETCH_2;
                end
            end

            STATE_FETCH_2: begin
                stall_cpu = 1;
                instruction_memory_request = 1;
                instruction_memory_address = {active_address[31:4], 4'b1000}; // Word 2
                if (instruction_memory_ready) begin
                    next_refill_buffer[95:64] = instruction_memory_read_data;
                    next_state = STATE_FETCH_3;
                end
            end

            STATE_FETCH_3: begin
                stall_cpu = 1;
                instruction_memory_request = 1;
                instruction_memory_address = {active_address[31:4], 4'b1100}; // Word 3
                if (instruction_memory_ready) begin
                    next_refill_buffer[127:96] = instruction_memory_read_data;
                    next_state = STATE_UPDATE;
                end
            end

            STATE_UPDATE: begin
                stall_cpu = 1;
                next_state = STATE_IDLE;
            end
        endcase
    end

    // Cache Update Logic
    always @(posedge clk) begin
        if (state == STATE_UPDATE) begin
            valid[active_index] <= 1;
            tag_array[active_index] <= active_tag;
            data_array[active_index] <= refill_buffer;
        end
    end

endmodule
