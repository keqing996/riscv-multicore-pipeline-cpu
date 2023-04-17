module load_store_unit (
    // Inputs from Pipeline
    input wire [31:0] address,          // ALU Result (Memory Address)
    input wire [31:0] write_data_in,      // Store Data (RS2)
    input wire memory_read_enable,             // (Optional, used for validation if needed)
    input wire memory_write_enable,
    input wire [2:0] function_3,         // Data Size/Sign (LB, LH, LW, etc.)
    
    // Bus Interface
    output wire [31:0] bus_address,
    output wire [31:0] bus_write_data,
    output wire [3:0]  bus_byte_enable,
    output wire        bus_write_enable,
    output wire        bus_read_enable,
    input  wire [31:0] bus_read_data,
    
    // Output to Pipeline
    output wire [31:0] memory_read_data_final
);

    // Bus Assignments
    assign bus_address = address;
    assign bus_write_enable = memory_write_enable;
    assign bus_read_enable = memory_read_enable;

    // Store Data Alignment
    wire [1:0] addr_offset = address[1:0];
    
    reg [31:0] aligned_write_data;
    reg [3:0]  aligned_byte_enable;

    always @(*) begin
        aligned_write_data = write_data_in;
        aligned_byte_enable = 4'b0000;
        
        if (memory_write_enable) begin
            case (function_3)
                3'b000: begin // SB
                    aligned_write_data = {4{write_data_in[7:0]}};
                    aligned_byte_enable = 4'b0001 << addr_offset;
                end
                3'b001: begin // SH
                    aligned_write_data = {2{write_data_in[15:0]}};
                    aligned_byte_enable = 4'b0011 << addr_offset;
                end
                default: begin // SW
                    aligned_write_data = write_data_in;
                    aligned_byte_enable = 4'b1111;
                end
            endcase
        end
    end

    assign bus_write_data = aligned_write_data;
    assign bus_byte_enable = aligned_byte_enable;

    // Load Data Alignment
    reg [31:0] dmem_rdata_aligned;
    always @(*) begin
        case (function_3)
            3'b000: begin // LB
                case (addr_offset)
                    2'b00: dmem_rdata_aligned = {{24{bus_read_data[7]}}, bus_read_data[7:0]};
                    2'b01: dmem_rdata_aligned = {{24{bus_read_data[15]}}, bus_read_data[15:8]};
                    2'b10: dmem_rdata_aligned = {{24{bus_read_data[23]}}, bus_read_data[23:16]};
                    2'b11: dmem_rdata_aligned = {{24{bus_read_data[31]}}, bus_read_data[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned = {{16{bus_read_data[15]}}, bus_read_data[15:0]};
                    1'b1: dmem_rdata_aligned = {{16{bus_read_data[31]}}, bus_read_data[31:16]};
                endcase
            end
            3'b010: begin // LW
                dmem_rdata_aligned = bus_read_data;
            end
            3'b100: begin // LBU
                case (addr_offset)
                    2'b00: dmem_rdata_aligned = {24'b0, bus_read_data[7:0]};
                    2'b01: dmem_rdata_aligned = {24'b0, bus_read_data[15:8]};
                    2'b10: dmem_rdata_aligned = {24'b0, bus_read_data[23:16]};
                    2'b11: dmem_rdata_aligned = {24'b0, bus_read_data[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned = {16'b0, bus_read_data[15:0]};
                    1'b1: dmem_rdata_aligned = {16'b0, bus_read_data[31:16]};
                endcase
            end
            default: dmem_rdata_aligned = bus_read_data;
        endcase
    end

    assign memory_read_data_final = dmem_rdata_aligned;

endmodule
