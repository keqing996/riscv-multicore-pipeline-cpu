module load_store_unit (
    // Inputs from Pipeline
    input wire [31:0] address,          // ALU Result (Memory Address)
    input wire [31:0] write_data_in,      // Store Data (RS2)
    input wire memory_read_enable,             // (Optional, used for validation if needed)
    input wire memory_write_enable,
    input wire [2:0] function_3,         // Data Size/Sign (LB, LH, LW, etc.)
    
    // Inputs from Peripherals/Memory
    input wire [31:0] data_memory_read_data,    // Raw data from DMEM
    input wire [31:0] timer_read_data,   // Data from Timer
    
    // Outputs to Peripherals/Memory
    output reg [31:0] data_memory_write_data,    // Aligned write data
    output reg [3:0]  data_memory_byte_enable,
    output wire data_memory_write_enable,
    output wire uart_write_enable,
    output wire timer_write_enable,
    
    // Output to Pipeline
    output wire [31:0] memory_read_data_final
);

    // Address Decoding
    wire is_uart_addr = (address == 32'h40000000);
    wire is_timer_addr = (address >= 32'h40004000 && address <= 32'h4000400C);
    
    assign data_memory_write_enable = memory_write_enable && !is_uart_addr && !is_timer_addr;
    assign uart_write_enable = memory_write_enable && is_uart_addr;
    assign timer_write_enable = memory_write_enable && is_timer_addr;

    // Store Data Alignment
    wire [1:0] addr_offset = address[1:0];
    
    always @(*) begin
        data_memory_write_data = write_data_in;
        data_memory_byte_enable = 4'b0000;
        
        if (memory_write_enable) begin
            case (function_3)
                3'b000: begin // SB
                    data_memory_write_data = {4{write_data_in[7:0]}};
                    data_memory_byte_enable = 4'b0001 << addr_offset;
                end
                3'b001: begin // SH
                    data_memory_write_data = {2{write_data_in[15:0]}};
                    data_memory_byte_enable = 4'b0011 << addr_offset;
                end
                default: begin // SW
                    data_memory_write_data = write_data_in;
                    data_memory_byte_enable = 4'b1111;
                end
            endcase
        end
    end

    // Load Data Alignment
    reg [31:0] dmem_rdata_aligned;
    always @(*) begin
        case (function_3)
            3'b000: begin // LB
                case (addr_offset)
                    2'b00: dmem_rdata_aligned = {{24{data_memory_read_data[7]}}, data_memory_read_data[7:0]};
                    2'b01: dmem_rdata_aligned = {{24{data_memory_read_data[15]}}, data_memory_read_data[15:8]};
                    2'b10: dmem_rdata_aligned = {{24{data_memory_read_data[23]}}, data_memory_read_data[23:16]};
                    2'b11: dmem_rdata_aligned = {{24{data_memory_read_data[31]}}, data_memory_read_data[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned = {{16{data_memory_read_data[15]}}, data_memory_read_data[15:0]};
                    1'b1: dmem_rdata_aligned = {{16{data_memory_read_data[31]}}, data_memory_read_data[31:16]};
                endcase
            end
            3'b010: begin // LW
                dmem_rdata_aligned = data_memory_read_data;
            end
            3'b100: begin // LBU
                case (addr_offset)
                    2'b00: dmem_rdata_aligned = {24'b0, data_memory_read_data[7:0]};
                    2'b01: dmem_rdata_aligned = {24'b0, data_memory_read_data[15:8]};
                    2'b10: dmem_rdata_aligned = {24'b0, data_memory_read_data[23:16]};
                    2'b11: dmem_rdata_aligned = {24'b0, data_memory_read_data[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned = {16'b0, data_memory_read_data[15:0]};
                    1'b1: dmem_rdata_aligned = {16'b0, data_memory_read_data[31:16]};
                endcase
            end
            default: dmem_rdata_aligned = data_memory_read_data;
        endcase
    end

    // Mux for Read Data (Timer vs DMEM)
    assign memory_read_data_final = is_timer_addr ? timer_read_data : dmem_rdata_aligned;

endmodule
