module mdu (
    input wire clk,
    input wire rst_n,
    
    input wire start,              // Start signal from Control Unit
    input wire [2:0] operation,    // funct3 from instruction
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,
    
    output reg busy,               // MDU is working, stall pipeline
    output reg ready,              // Result is ready
    output reg [31:0] result
);

    // Operations
    localparam OP_MUL    = 3'b000;
    localparam OP_MULH   = 3'b001;
    localparam OP_MULHSU = 3'b010;
    localparam OP_MULHU  = 3'b011;
    localparam OP_DIV    = 3'b100;
    localparam OP_DIVU   = 3'b101;
    localparam OP_REM    = 3'b110;
    localparam OP_REMU   = 3'b111;

    // States
    localparam STATE_IDLE = 2'b00;
    localparam STATE_WORK = 2'b01;
    localparam STATE_DONE = 2'b10;

    reg [1:0] state;
    reg [5:0] count; // 0 to 32
    
    // Internal Registers for Calculation
    reg [63:0] reg_pa; // Product/Remainder(High) + Multiplicand/Quotient(Low)
    reg [31:0] reg_b;  // Divisor / Multiplier
    reg sign_a;
    reg sign_b;
    reg is_div;
    reg is_rem;
    reg negate_result;

    wire is_mul_op = (operation[2] == 1'b0);
    wire is_div_op = (operation[2] == 1'b1);

    // Temporary variables
    reg sign_a_local;
    reg sign_b_local;
    reg [32:0] sum;
    reg [63:0] shifted;
    reg [32:0] diff;
    reg [63:0] final_prod;
    reg [31:0] final_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            busy <= 0;
            ready <= 0;
            result <= 0;
            count <= 0;
            reg_pa <= 0;
            reg_b <= 0;
            sign_a <= 0;
            sign_b <= 0;
            is_div <= 0;
            is_rem <= 0;
            negate_result <= 0;
            // Initialize temps to avoid latches
            sign_a_local = 0;
            sign_b_local = 0;
            sum = 0;
            shifted = 0;
            diff = 0;
            final_prod = 0;
            final_val = 0;
        end else begin
            // Default assignments for temps to avoid latches
            sign_a_local = 0;
            sign_b_local = 0;
            sum = 0;
            shifted = 0;
            diff = 0;
            final_prod = 0;
            final_val = 0;

            case (state)
                STATE_IDLE: begin
                    ready <= 0;
                    if (start) begin
                        state <= STATE_WORK;
                        busy <= 1;
                        count <= 0;
                        
                        // Pre-processing
                        is_div <= is_div_op;
                        
                        if (is_mul_op) begin
                            if (operation == OP_MULH) begin
                                sign_a_local = operand_a[31];
                                sign_b_local = operand_b[31];
                            end else if (operation == OP_MULHSU) begin
                                sign_a_local = operand_a[31];
                                sign_b_local = 0;
                            end else if (operation == OP_MULHU) begin
                                sign_a_local = 0;
                                sign_b_local = 0;
                            end else begin // MUL
                                sign_a_local = 0; 
                                sign_b_local = 0;
                            end

                            // Abs values
                            reg_pa <= {32'b0, (sign_a_local && operand_a[31]) ? (-operand_a) : operand_a};
                            reg_b  <= (sign_b_local && operand_b[31]) ? (-operand_b) : operand_b;
                            
                            // Determine result sign for High part
                            negate_result <= sign_a_local ^ sign_b_local;
                            
                        end else begin
                            // Division Setup
                            sign_a_local = (operation == OP_DIV || operation == OP_REM) ? operand_a[31] : 0;
                            sign_b_local = (operation == OP_DIV || operation == OP_REM) ? operand_b[31] : 0;
                            
                            reg_pa <= {32'b0, (sign_a_local) ? (-operand_a) : operand_a};
                            reg_b <= (sign_b_local) ? (-operand_b) : operand_b;
                            
                            if (operation == OP_REM || operation == OP_REMU) begin
                                negate_result <= sign_a_local;
                                is_rem <= 1;
                            end else begin
                                negate_result <= sign_a_local ^ sign_b_local;
                                is_rem <= 0;
                            end
                        end
                    end
                end

                STATE_WORK: begin
                    count <= count + 1;
                    
                    if (is_mul_op) begin
                        // Multiplication Step (Shift and Add)
                        if (reg_pa[0]) begin
                            sum = reg_pa[63:32] + reg_b;
                        end else begin
                            sum = {1'b0, reg_pa[63:32]};
                        end
                        reg_pa <= {sum, reg_pa[31:1]};
                    end else begin
                        // Division Step (Restoring)
                        shifted = {reg_pa[62:0], 1'b0};
                        diff = {1'b0, shifted[63:32]} - {1'b0, reg_b};
                        
                        if (diff[32]) begin // Negative result
                            reg_pa <= shifted; // Q[0] remains 0
                        end else begin // Positive result
                            reg_pa <= {diff[31:0], shifted[31:1], 1'b1}; // Update P, set Q[0] = 1
                        end
                    end

                    if (count == 31) begin
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    busy <= 0;
                    ready <= 1;
                    state <= STATE_IDLE;
                    
                    if (is_mul_op) begin
                        final_prod = (negate_result) ? (-reg_pa) : reg_pa;
                        
                        case (operation)
                            OP_MUL:    result <= final_prod[31:0];
                            OP_MULH:   result <= final_prod[63:32];
                            OP_MULHSU: result <= final_prod[63:32];
                            OP_MULHU:  result <= reg_pa[63:32];
                            default:   result <= final_prod[31:0];
                        endcase
                    end else begin
                        if (is_rem) begin
                            final_val = reg_pa[63:32];
                        end else begin
                            final_val = reg_pa[31:0];
                        end
                        
                        if (reg_b == 0) begin
                            if (is_rem) result <= operand_a;
                            else result <= 32'hFFFFFFFF;
                        end else begin
                            result <= (negate_result) ? (-final_val) : final_val;
                        end
                    end
                end
            endcase
        end
    end

endmodule
