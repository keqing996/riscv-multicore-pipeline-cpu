# Design Notes

## UART Simulation (MMIO)

To enable console output without a physical UART, we implemented a Memory-Mapped I/O (MMIO) simulation model.

### Hardware Implementation
*   **Module**: `rtl/uart_sim.v`
*   **Mechanism**: Monitors write operations to a specific address.
*   **Behavior**: When `we` is high and `addr == 0x40000000`, the least significant byte of `wdata` is printed to stdout using Verilog system task `$write`.

### Memory Map
*   **DMEM**: `0x00000000` - `0x00000FFF` (4KB Data Memory)
*   **UART**: `0x40000000` (Write-only Transmit Register)

### Core Integration
*   Modified `rtl/core.v` to decode addresses.
*   **Address Decoding**:
    *   If `alu_result == 0x40000000`, enable `uart_we`.
    *   If `alu_result < 0x1000`, enable `dmem_we`.

### Software Driver
*   Defined `UART_TX_ADDR` as `0x40000000`.
*   Implemented `putchar(char c)` to write to this volatile address.
*   Standard `printf` functionality is built on top of this primitive.
