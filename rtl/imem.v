module imem (
    input wire [31:0] addr, // Address from PC
    output wire [31:0] data // Instruction
);

    // Define memory: 1024 words (4KB)
    reg [31:0] memory [0:1023];

    // Initialize memory from file
    initial begin
        // Load hex file into memory. 
        // Ensure "program.hex" exists in the simulation directory.
        $readmemh("program.hex", memory);
    end

    // Read logic (Combinational / Asynchronous read)
    // RISC-V instructions are 4-byte aligned.
    // We use addr[31:2] to index the word array.
    assign data = memory[addr[31:2]];

endmodule
