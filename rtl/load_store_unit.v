module load_store_unit (
    // Inputs from Pipeline
    input wire [31:0] addr,          // ALU Result (Memory Address)
    input wire [31:0] wdata_in,      // Store Data (RS2)
    input wire mem_read,             // (Optional, used for validation if needed)
    input wire mem_write,
    input wire [2:0] funct3,         // Data Size/Sign (LB, LH, LW, etc.)
    
    // Inputs from Peripherals/Memory
    input wire [31:0] dmem_rdata,    // Raw data from DMEM
    input wire [31:0] timer_rdata,   // Data from Timer
    
    // Outputs to Peripherals/Memory
    output reg [31:0] dmem_wdata,    // Aligned write data
    output reg [3:0]  dmem_byte_enable,
    output wire dmem_we,
    output wire uart_we,
    output wire timer_we,
    
    // Output to Pipeline
    output wire [31:0] mem_rdata_final
);

    // Address Decoding
    wire is_uart_addr = (addr == 32'h40000000);
    wire is_timer_addr = (addr >= 32'h40004000 && addr <= 32'h4000400C);
    
    assign dmem_we = mem_write && !is_uart_addr && !is_timer_addr;
    assign uart_we = mem_write && is_uart_addr;
    assign timer_we = mem_write && is_timer_addr;

    // Store Data Alignment
    wire [1:0] addr_offset = addr[1:0];
    
    always @(*) begin
        dmem_wdata = wdata_in;
        dmem_byte_enable = 4'b0000;
        
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB
                    dmem_wdata = {4{wdata_in[7:0]}};
                    dmem_byte_enable = 4'b0001 << addr_offset;
                end
                3'b001: begin // SH
                    dmem_wdata = {2{wdata_in[15:0]}};
                    dmem_byte_enable = 4'b0011 << addr_offset;
                end
                default: begin // SW
                    dmem_wdata = wdata_in;
                    dmem_byte_enable = 4'b1111;
                end
            endcase
        end
    end

    // Load Data Alignment
    reg [31:0] dmem_rdata_aligned;
    always @(*) begin
        case (funct3)
            3'b000: begin // LB
                case (addr_offset)
                    2'b00: dmem_rdata_aligned = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                    2'b01: dmem_rdata_aligned = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: dmem_rdata_aligned = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: dmem_rdata_aligned = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end
            3'b001: begin // LH
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: dmem_rdata_aligned = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end
            3'b010: begin // LW
                dmem_rdata_aligned = dmem_rdata;
            end
            3'b100: begin // LBU
                case (addr_offset)
                    2'b00: dmem_rdata_aligned = {24'b0, dmem_rdata[7:0]};
                    2'b01: dmem_rdata_aligned = {24'b0, dmem_rdata[15:8]};
                    2'b10: dmem_rdata_aligned = {24'b0, dmem_rdata[23:16]};
                    2'b11: dmem_rdata_aligned = {24'b0, dmem_rdata[31:24]};
                endcase
            end
            3'b101: begin // LHU
                case (addr_offset[1])
                    1'b0: dmem_rdata_aligned = {16'b0, dmem_rdata[15:0]};
                    1'b1: dmem_rdata_aligned = {16'b0, dmem_rdata[31:16]};
                endcase
            end
            default: dmem_rdata_aligned = dmem_rdata;
        endcase
    end

    // Mux for Read Data (Timer vs DMEM)
    assign mem_rdata_final = is_timer_addr ? timer_rdata : dmem_rdata_aligned;

endmodule
