module csr_file (
    input wire clk,
    input wire rst_n,
    
    // Read/Write ports
    input wire [11:0] csr_addr,
    input wire csr_we,
    input wire [31:0] csr_wdata,
    output reg [31:0] csr_rdata,

    // Exception/Interrupt signals
    input wire exception_en,      // Trigger exception (e.g. ECALL)
    input wire [31:0] exception_pc, // PC where exception happened
    input wire [31:0] exception_cause, // Cause code
    input wire mret_en,           // Return from exception (MRET instruction)
    input wire timer_irq,         // Timer Interrupt Input
    
    output wire [31:0] mtvec_out, // Trap Vector Base Address
    output wire [31:0] mepc_out,  // Exception PC (for MRET)
    output reg interrupt_en       // Trigger interrupt trap
);

    // CSR Addresses (Machine Mode)
    localparam CSR_MSTATUS = 12'h300;
    localparam CSR_MIE     = 12'h304; // Machine Interrupt Enable
    localparam CSR_MTVEC   = 12'h305;
    localparam CSR_MEPC    = 12'h341;
    localparam CSR_MCAUSE  = 12'h342;
    localparam CSR_MIP     = 12'h344; // Machine Interrupt Pending

    // Registers
    reg [31:0] mstatus; // Bit 3 = MIE (Global Interrupt Enable), Bit 7 = MPIE
    reg [31:0] mie;     // Bit 7 = MTIE (Timer Interrupt Enable)
    reg [31:0] mtvec;
    reg [31:0] mepc;
    reg [31:0] mcause;
    wire [31:0] mip;    // Bit 7 = MTIP (Timer Interrupt Pending)

    // MIP is read-only for software (mostly), reflects hardware signals
    assign mip = {24'b0, timer_irq, 7'b0};

    // Interrupt Logic
    wire global_ie = mstatus[3];
    wire timer_ie  = mie[7];
    wire timer_ip  = mip[7];
    
    // Trigger interrupt if enabled and pending
    // Note: In a real pipeline, we need to be careful about priority vs exception
    // Here we assume check happens at WB or before Fetch next
    wire timer_interrupt_fire = global_ie && timer_ie && timer_ip;

    always @(*) begin
        interrupt_en = timer_interrupt_fire;
    end

    // Read Logic
    always @(*) begin
        case (csr_addr)
            CSR_MSTATUS: csr_rdata = mstatus;
            CSR_MIE:     csr_rdata = mie;
            CSR_MTVEC:   csr_rdata = mtvec;
            CSR_MEPC:    csr_rdata = mepc;
            CSR_MCAUSE:  csr_rdata = mcause;
            CSR_MIP:     csr_rdata = mip;
            default:     csr_rdata = 32'b0;
        endcase
    end

    // Write Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus <= 32'b0;
            mie     <= 32'b0;
            mtvec   <= 32'b0;
            mepc    <= 32'b0;
            mcause  <= 32'b0;
        end else begin
            // Priority: Reset > Exception/Interrupt > Software Write
            
            if (timer_interrupt_fire) begin
                mepc   <= exception_pc; // Save current PC (or next PC depending on arch)
                mcause <= 32'h80000007; // Interrupt bit (31) + Cause 7 (Timer)
                
                // Disable Global Interrupts
                // Save MIE to MPIE (Bit 7)
                mstatus[7] <= mstatus[3];
                // Clear MIE (Bit 3)
                mstatus[3] <= 1'b0;
            end
            else if (exception_en) begin
                mepc   <= exception_pc;
                mcause <= exception_cause;
                // Save MIE to MPIE
                mstatus[7] <= mstatus[3];
                // Clear MIE
                mstatus[3] <= 1'b0;
            end 
            else if (mret_en) begin
                // Restore MIE from MPIE
                mstatus[3] <= mstatus[7];
                // Set MPIE to 1 (standard says 1)
                mstatus[7] <= 1'b1;
            end
            // Software Write (CSR Instructions)
            else if (csr_we) begin
                case (csr_addr)
                    CSR_MSTATUS: mstatus <= csr_wdata;
                    CSR_MIE:     mie     <= csr_wdata;
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
