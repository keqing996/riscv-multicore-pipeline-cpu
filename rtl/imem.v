module imem (
    input wire [31:0] addr, // Address from PC
    output wire [31:0] data // Instruction
);

    // Define memory: 4096 words (16KB)
    reg [31:0] memory [0:4095];

    // Read logic (Combinational / Asynchronous read)
    // RISC-V instructions are 4-byte aligned.
    // We use addr[31:2] to index the word array.
    assign data = memory[addr[31:2]];

endmodule
