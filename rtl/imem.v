module imem (
    input wire [31:0] addr, // Address from PC
    output wire [31:0] data // Instruction
);

    // Define memory: 8M words (32MB)
    reg [31:0] memory [0:8388607];

    // Read logic (Combinational / Asynchronous read)
    // RISC-V instructions are 4-byte aligned.
    // We use addr[24:2] to index the word array.
    assign data = memory[addr[24:2]];

endmodule
