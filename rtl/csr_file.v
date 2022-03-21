module csr_file (
    input wire clk,
    input wire rst_n,
    
    // Read/Write ports
    input wire [11:0] csr_addr,
    input wire csr_we,
    input wire [31:0] csr_wdata,
    output reg [31:0] csr_rdata,

    // Exception/Interrupt signals
    input wire exception_en,      // Trigger exception
    input wire [31:0] exception_pc, // PC where exception happened
    input wire [31:0] exception_cause, // Cause code
    input wire mret_en,           // Return from exception (MRET instruction)
    
    output wire [31:0] mtvec_out, // Trap Vector Base Address
    output wire [31:0] mepc_out   // Exception PC (for MRET)
);

    // CSR Addresses (Machine Mode)
    localparam CSR_MSTATUS = 12'h300;
    localparam CSR_MTVEC   = 12'h305;
    localparam CSR_MEPC    = 12'h341;
    localparam CSR_MCAUSE  = 12'h342;

    // Registers
    reg [31:0] mstatus;
    reg [31:0] mtvec;
    reg [31:0] mepc;
    reg [31:0] mcause;

    // Read Logic
    always @(*) begin
        case (csr_addr)
            CSR_MSTATUS: csr_rdata = mstatus;
            CSR_MTVEC:   csr_rdata = mtvec;
            CSR_MEPC:    csr_rdata = mepc;
            CSR_MCAUSE:  csr_rdata = mcause;
            default:     csr_rdata = 32'b0;
        endcase
    end

    // Write Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 32'b0;
            mtvec   <= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
        end else begin
            // Exception Handling (Hardware update)
            if (exception_en) begin
                mepc   <= exception_pc;
                mcause <= exception_cause;
                // In a real CPU, we would also update mstatus (MPIE, MIE, etc.)
            end 
            // Software Write (CSR Instructions)
            else if (csr_we) begin
                case (csr_addr)
                    CSR_MSTATUS: mstatus <= csr_wdata;
                    CSR_MTVEC:   mtvec   <= csr_wdata;
                    CSR_MEPC:    mepc    <= csr_wdata;
                    CSR_MCAUSE:  mcause  <= csr_wdata;
                endcase
            end
        end
    end

    // Outputs for Control Logic
    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

endmodule
