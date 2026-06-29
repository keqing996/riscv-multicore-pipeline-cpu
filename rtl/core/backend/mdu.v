`timescale 1ns / 1ps

module mdu (
    input wire clk,
    input wire rst_n,

    input wire start,
    input wire [2:0] operation,
    input wire [31:0] operand_a,
    input wire [31:0] operand_b,

    output reg busy,
    output reg ready,
    output reg [31:0] result
);

    localparam OP_MUL    = 3'b000;
    localparam OP_MULH   = 3'b001;
    localparam OP_MULHSU = 3'b010;
    localparam OP_MULHU  = 3'b011;
    localparam OP_DIV    = 3'b100;
    localparam OP_DIVU   = 3'b101;
    localparam OP_REM    = 3'b110;
    localparam OP_REMU   = 3'b111;

    localparam STATE_IDLE = 2'b00;
    localparam STATE_WORK = 2'b01;
    localparam STATE_DONE = 2'b10;

    reg [1:0] state;
    reg [5:0] count;
    reg [2:0] operation_reg;
    reg [31:0] operand_a_reg;
    reg [31:0] operand_b_reg;

    wire signed [63:0] signed_operand_a = {{32{operand_a_reg[31]}}, operand_a_reg};
    wire signed [63:0] signed_operand_b = {{32{operand_b_reg[31]}}, operand_b_reg};
    wire signed [63:0] signed_product = signed_operand_a * signed_operand_b;
    wire signed [63:0] signed_unsigned_product = signed_operand_a * {32'b0, operand_b_reg};
    wire [63:0] unsigned_product = {32'b0, operand_a_reg} * {32'b0, operand_b_reg};

    reg [31:0] calculated_result;

    always @(*) begin
        calculated_result = 32'b0;

        case (operation_reg)
            OP_MUL: begin
                calculated_result = signed_product[31:0];
            end

            OP_MULH: begin
                calculated_result = signed_product[63:32];
            end

            OP_MULHSU: begin
                calculated_result = signed_unsigned_product[63:32];
            end

            OP_MULHU: begin
                calculated_result = unsigned_product[63:32];
            end

            OP_DIV: begin
                if (operand_b_reg == 32'b0) begin
                    calculated_result = 32'hFFFFFFFF;
                end else if (operand_a_reg == 32'h80000000 && operand_b_reg == 32'hFFFFFFFF) begin
                    calculated_result = 32'h80000000;
                end else begin
                    calculated_result = $signed(operand_a_reg) / $signed(operand_b_reg);
                end
            end

            OP_DIVU: begin
                if (operand_b_reg == 32'b0) begin
                    calculated_result = 32'hFFFFFFFF;
                end else begin
                    calculated_result = operand_a_reg / operand_b_reg;
                end
            end

            OP_REM: begin
                if (operand_b_reg == 32'b0) begin
                    calculated_result = operand_a_reg;
                end else if (operand_a_reg == 32'h80000000 && operand_b_reg == 32'hFFFFFFFF) begin
                    calculated_result = 32'b0;
                end else begin
                    calculated_result = $signed(operand_a_reg) % $signed(operand_b_reg);
                end
            end

            OP_REMU: begin
                if (operand_b_reg == 32'b0) begin
                    calculated_result = operand_a_reg;
                end else begin
                    calculated_result = operand_a_reg % operand_b_reg;
                end
            end

            default: begin
                calculated_result = 32'b0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            busy <= 1'b0;
            ready <= 1'b0;
            result <= 32'b0;
            count <= 6'b0;
            operation_reg <= OP_MUL;
            operand_a_reg <= 32'b0;
            operand_b_reg <= 32'b0;
        end else begin
            ready <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    busy <= 1'b0;
                    count <= 6'b0;

                    if (start) begin
                        operation_reg <= operation;
                        operand_a_reg <= operand_a;
                        operand_b_reg <= operand_b;
                        busy <= 1'b1;
                        state <= STATE_WORK;
                    end
                end

                STATE_WORK: begin
                    busy <= 1'b1;

                    if (count == 6'd31) begin
                        state <= STATE_DONE;
                    end else begin
                        count <= count + 6'd1;
                    end
                end

                STATE_DONE: begin
                    busy <= 1'b0;
                    ready <= 1'b1;
                    result <= calculated_result;
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                    busy <= 1'b0;
                    ready <= 1'b0;
                    count <= 6'b0;
                end
            endcase
        end
    end

endmodule
