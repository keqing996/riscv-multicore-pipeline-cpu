module control_status_register_file (
    input wire clk,
    input wire rst_n,
    
    // Read/Write ports
    input wire [11:0] csr_address,
    input wire csr_write_enable,
    input wire [31:0] csr_write_data,
    input wire [2:0] csr_op, // Added: CSR Operation (funct3)
    output reg [31:0] csr_read_data,

    // Exception/Interrupt signals
    input wire exception_enable,      // Trigger exception (e.g. ECALL)
    input wire [31:0] exception_program_counter, // PC where exception happened
    input wire [31:0] exception_cause, // Cause code
    input wire machine_return_enable,           // Return from exception (MRET instruction)
    input wire timer_interrupt_request,         // Timer Interrupt Input
    
    output wire [31:0] mtvec_out, // Trap Vector Base Address
    output wire [31:0] mepc_out,  // Exception PC (for MRET)
    output reg interrupt_enable,       // Trigger interrupt trap
    output wire [31:0] csr_new_value_out // Forwarding: The value that will be written
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
    assign mip = {24'b0, timer_interrupt_request, 7'b0};

    // Interrupt Logic
    wire global_ie = mstatus[3];
    wire timer_ie  = mie[7];
    wire timer_ip  = mip[7];
    
    // Trigger interrupt if enabled and pending
    // Note: In a real pipeline, we need to be careful about priority vs exception
    // Here we assume check happens at WB or before Fetch next
    wire timer_interrupt_fire = global_ie && timer_ie && timer_ip;

    always @(*) begin
        interrupt_enable = timer_interrupt_fire;
    end

    // Read Logic
    always @(*) begin
        case (csr_address)
            CSR_MSTATUS: csr_read_data = mstatus;
            CSR_MIE:     csr_read_data = mie;
            CSR_MTVEC:   csr_read_data = mtvec;
            CSR_MEPC:    csr_read_data = mepc;
            CSR_MCAUSE:  csr_read_data = mcause;
            CSR_MIP:     csr_read_data = mip;
            default:     csr_read_data = 32'b0;
        endcase
    end

    // CSR Operation Logic
    reg [31:0] new_csr_value;
    always @(*) begin
        case (csr_op[1:0])
            2'b01: new_csr_value = csr_write_data; // CSRRW
            2'b10: new_csr_value = csr_read_data | csr_write_data; // CSRRS
            2'b11: new_csr_value = csr_read_data & ~csr_write_data; // CSRRC
            default: new_csr_value = csr_write_data;
        endcase
    end

    assign csr_new_value_out = new_csr_value;

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
                mepc   <= exception_program_counter; // Save current PC (or next PC depending on arch)
                mcause <= 32'h80000007; // Interrupt bit (31) + Cause 7 (Timer)
                
                // Disable Global Interrupts
                // Save MIE to MPIE (Bit 7)
                mstatus[7] <= mstatus[3];
                // Clear MIE (Bit 3)
                mstatus[3] <= 1'b0;
            end
            else if (exception_enable) begin
                mepc   <= exception_program_counter;
                mcause <= exception_cause;
                // Save MIE to MPIE
                mstatus[7] <= mstatus[3];
                // Clear MIE
                mstatus[3] <= 1'b0;
            end 
            else if (machine_return_enable) begin
                // Restore MIE from MPIE
                mstatus[3] <= mstatus[7];
                // Set MPIE to 1 (standard says 1)
                mstatus[7] <= 1'b1;
            end
            // Software Write (CSR Instructions)
            else if (csr_write_enable) begin
                case (csr_address)
                    CSR_MSTATUS: mstatus <= new_csr_value;
                    CSR_MIE:     mie     <= new_csr_value;
                    CSR_MTVEC:   mtvec   <= new_csr_value;
                    CSR_MEPC:    mepc    <= new_csr_value;
                    CSR_MCAUSE:  mcause  <= new_csr_value;
                endcase
            end
        end
    end

    // Outputs for Control Logic
    assign mtvec_out = mtvec;
    assign mepc_out  = mepc;

endmodule
