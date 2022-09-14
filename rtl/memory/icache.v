module instruction_cache (
    input wire clk,
    input wire rst_n,

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

    // Address Decomposition
    wire [INDEX_BITS-1:0] index = program_counter_address[INDEX_BITS+OFFSET_BITS-1 : OFFSET_BITS];
    wire [TAG_BITS-1:0] tag = program_counter_address[31 : 31-TAG_BITS+1];
    wire [1:0] word_offset = program_counter_address[3:2];

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
            $display("ICache State: %d, Addr: %h, Stall: %b, Hit: %b, MemReady: %b", state, program_counter_address, stall_cpu, hit, instruction_memory_ready);
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
        instruction = 0;
        instruction_memory_request = 0;
        instruction_memory_address = 0;

        case (state)
            STATE_IDLE: begin
                if (hit) begin
                    stall_cpu = 0;
                    instruction = hit_data;
                end else begin
                    $display("I-Cache Miss at %h", program_counter_address);
                    stall_cpu = 1; // Stall!
                    next_state = STATE_FETCH_0;
                end
            end

            STATE_FETCH_0: begin
                stall_cpu = 1;
                instruction_memory_request = 1;
                instruction_memory_address = {program_counter_address[31:4], 4'b0000}; // Word 0
                if (instruction_memory_ready) begin
                    $display("I-Cache Fetch 0: %h = %h", instruction_memory_address, instruction_memory_read_data);
                    next_refill_buffer[31:0] = instruction_memory_read_data;
                    next_state = STATE_FETCH_1;
                end
            end

            STATE_FETCH_1: begin
                stall_cpu = 1;
                instruction_memory_request = 1;
                instruction_memory_address = {program_counter_address[31:4], 4'b0100}; // Word 1
                if (instruction_memory_ready) begin
                    next_refill_buffer[63:32] = instruction_memory_read_data;
                    next_state = STATE_FETCH_2;
                end
            end

            STATE_FETCH_2: begin
                stall_cpu = 1;
                instruction_memory_request = 1;
                instruction_memory_address = {program_counter_address[31:4], 4'b1000}; // Word 2
                if (instruction_memory_ready) begin
                    next_refill_buffer[95:64] = instruction_memory_read_data;
                    next_state = STATE_FETCH_3;
                end
            end

            STATE_FETCH_3: begin
                stall_cpu = 1;
                instruction_memory_request = 1;
                instruction_memory_address = {program_counter_address[31:4], 4'b1100}; // Word 3
                if (instruction_memory_ready) begin
                    next_refill_buffer[127:96] = instruction_memory_read_data;
                    next_state = STATE_UPDATE;
                end
            end

            STATE_UPDATE: begin
                stall_cpu = 1;
                // Write to cache
                // We do this in the sequential block or here?
                // Ideally we transition to IDLE and write.
                next_state = STATE_IDLE;
            end
        endcase
    end

    // Cache Update Logic
    always @(posedge clk) begin
        if (state == STATE_UPDATE) begin
            valid[index] <= 1;
            tag_array[index] <= tag;
            data_array[index] <= refill_buffer;
        end
    end

endmodule
