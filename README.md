# RISC-V CPU Implementation

A simple single-cycle RISC-V CPU implementation in Verilog.

## Project Structure

*   `rtl/`: **Register Transfer Level**. Contains the Verilog source code for the CPU core and its submodules (e.g., `pc.v`, `imem.v`).
*   `tb/`: **Testbench**. Contains verification files to simulate and test the RTL modules (e.g., `pc_tb.v`).
*   `sim/`: **Simulation**. Generated directory for simulation artifacts like compiled executables (`.vvp`), waveform dumps (`.vcd`), and memory initialization files (`.hex`).
*   `software/`: **Software**. (Planned) Assembly/C source code and build scripts to generate machine code (`.hex`) for the CPU.
*   `docs/`: **Documentation**. Design notes, diagrams, and references.

## Prerequisites

*   **Icarus Verilog**: Simulator (`brew install icarus-verilog` on macOS).
*   **Make**: Build tool.
*   **Surfer** / **GTKWave**: (Optional) Waveform viewer.

## Build & Run

Run the simulation using the Makefile:

```bash
# Run all simulations
make

# Run specific module simulation
make pc_sim
make imem_sim

# Clean build artifacts
make clean
```

Waveform files (`.vcd`) will be generated in the `sim/` directory.
