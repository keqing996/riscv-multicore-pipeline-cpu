# Software Simulation Workflow

## The Flow (Cross-Compilation)

Build on macOS (Host) but target RISC-V. The entire process is automated by CMake.

1.  **Compile (.c/.S -> .elf)**
    *   Tool: `clang` (LLVM)
    *   We compile `main.c` and `start.S` together.
    *   Flags: `-nostdlib` (no standard library), `-ffreestanding`.
2.  **Extract Binary (.elf -> .bin)**
    *   Tool: `llvm-objcopy`
    *   Strips ELF headers to get raw machine code.
3.  **Hex Conversion (.bin -> .hex)**
    *   Tool: `make_hex.py`
    *   Converts binary to 32-bit ASCII Hex format.
    *   This is required for Verilog's `$readmemh`.
4.  **Simulation**
    *   Verilog testbench loads the `.hex` file into Instruction Memory.
    *   CPU executes the instructions.

## File Descriptions (`software/`)

*   **`start.S`**
    *   **The Bootloader.**
    *   The CPU starts here (Address 0).
    *   **Crucial Job:** Sets up the Stack Pointer (`sp`). C code *cannot* run without a stack!
    *   Jumps to `main` after setup.

*   **`link.ld`**
    *   **The Map.**
    *   Tells the linker how to layout memory.
    *   Map everything starting at `0x00000000` (IMEM base).

*   **`main.c`**
    *   **The Logic.**
    *   Standard C code.
    *   *Note:* No `printf` here! We write results to specific memory addresses (e.g., `0x100`) and check them in the waveform viewer.

*   **`make_hex.py`**
    *   **The Translator.**
    *   Simple Python script.
    *   Reads raw binary bytes and prints them as 8-digit hex strings (e.g., `00000013`) for the hardware simulation.
