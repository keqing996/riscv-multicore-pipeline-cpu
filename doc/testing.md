# Testing Architecture Documentation

## Table of Contents

- [1. Overview](#1-overview)
- [2. Technology Stack](#2-technology-stack)
- [3. Build System](#3-build-system)
  - [3.1 Root CMake Configuration](#31-root-cmake-configuration)
  - [3.2 Verilated Libraries](#32-verilated-libraries)
- [4. Common Test Infrastructure](#4-common-test-infrastructure)
  - [4.1 Test Framework — doctest](#41-test-framework--doctest)
  - [4.2 Testbench Base Classes](#42-testbench-base-classes)
- [5. Unit Tests (Hardware)](#5-unit-tests-hardware)
  - [5.1 Structure and Build](#51-structure-and-build)
  - [5.2 Test List](#52-test-list)
  - [5.3 Test Methodology](#53-test-methodology)
  - [5.4 Example: ALU Unit Test](#54-example-alu-unit-test)
  - [5.5 Example: Register File Unit Test](#55-example-register-file-unit-test)
- [6. Integration Tests — Hardware](#6-integration-tests--hardware)
  - [6.1 Structure and Build](#61-structure-and-build)
  - [6.2 Test List](#62-test-list)
  - [6.3 Test Methodology](#63-test-methodology)
  - [6.4 Example: Basic Operations Test](#64-example-basic-operations-test)
  - [6.5 Example: Forwarding Test](#65-example-forwarding-test)
- [7. Integration Tests — Software](#7-integration-tests--software)
  - [7.1 Cross-Compilation Toolchain](#71-cross-compilation-toolchain)
  - [7.2 Linker Script and Memory Layout](#72-linker-script-and-memory-layout)
  - [7.3 Common Software Support Library](#73-common-software-support-library)
  - [7.4 Test List](#74-test-list)
  - [7.5 Test Methodology](#75-test-methodology)
  - [7.6 Example: Fibonacci Test](#76-example-fibonacci-test)
- [8. Test Execution](#8-test-execution)
- [9. Debugging with Waveforms](#9-debugging-with-waveforms)
- [10. Test File Index](#10-test-file-index)

---

## 1. Overview

The test suite employs a **three-tier verification strategy**:

| Tier | Category | Purpose | Count |
|------|----------|---------|-------|
| 1 | **Unit Tests** | Validate individual RTL modules in isolation | 23 |
| 2 | **Hardware Integration Tests** | Validate the full chip (or backend subsystem) executing hand-assembled instruction sequences | 12 |
| 3 | **Software Integration Tests** | Validate the full chip executing real RISC-V programs compiled from C/Assembly | 2 |

All tests run through **Verilator** (a Verilog-to-C++ compiler) and the **doctest** C++ testing framework, orchestrated by **CMake** and **CTest**.

```
┌──────────────────────────────────────────────────────────────┐
│                    Test Architecture                          │
│                                                              │
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Unit Tests   │  │ HW Integration  │  │ SW Integration  │  │
│  │ (23 tests)   │  │ (12 tests)      │  │ (2 tests)       │  │
│  │              │  │                 │  │                 │  │
│  │ Single RTL   │  │ Full chip_top   │  │ Full chip_top + │  │
│  │ module each  │  │ with hand-asm   │  │ compiled RISC-V │  │
│  │              │  │ programs        │  │ C programs      │  │
│  └──────┬───────┘  └───────┬─────────┘  └───────┬─────────┘  │
│         │                  │                     │            │
│         ▼                  ▼                     ▼            │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Verilator (RTL → C++ model) + doctest + CMake/CTest  │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Technology Stack

| Tool | Role | Details |
|------|------|---------|
| **Verilator** | RTL Simulation | Compiles Verilog into C++ cycle-accurate simulation models |
| **doctest** | Test Framework | Lightweight, header-only C++ testing framework (single `doctest.h` header) |
| **CMake** | Build System | Orchestrates Verilator compilation, test binary builds, and CTest registration |
| **CTest** | Test Runner | Discovers and runs all registered tests with timeout and labeling support |
| **Clang/LLVM** | Cross-Compiler | Compiles C/Assembly to RISC-V binaries for software integration tests |
| **llvm-objcopy** | Binary Extraction | Converts ELF executables to raw binary files for memory loading |

---

## 3. Build System

### 3.1 Root CMake Configuration

**File:** `test/CMakeLists.txt`

The root CMake file performs three key tasks:

1. **Creates shared testbench library (`tb_common`):** Compiles the common test infrastructure (`tb_base.cpp`) and makes the `doctest.h` header and `tb_base.h` available to all tests.

2. **Verilates shared RTL targets:** To avoid redundant Verilog compilation, two major targets are pre-compiled once and shared across tests:
   - `verilated_chip_top` — the full system (all 23+ Verilog source files)
   - `verilated_backend` — the backend subsystem only

3. **Adds subdirectories** for unit tests, hardware integration tests, and software integration tests.

### 3.2 Verilated Libraries

**Verilator flags used:**

| Flag | Purpose |
|------|---------|
| `--trace` | Enable VCD waveform tracing |
| `--public` | Expose internal module signals via `rootp` for test access |
| `-O3` | Optimize the generated C++ model |
| `--x-assign fast` | Speed up simulation by treating X values as don't-care |
| `--noassert` | Disable Verilog assertion checking for speed |

The `--public` flag is particularly important: it allows test code to directly read and write internal RTL signals (such as register file contents or memory arrays) through the Verilator-generated `rootp` pointer hierarchy. For example:

```cpp
// Access register x1 in Hart 0's register file
dut->rootp->chip_top__DOT__u_tile_0__DOT__u_core__DOT__u_backend__DOT__u_regfile__DOT__registers[1]

// Access main memory word at address 0x1000
dut->rootp->chip_top__DOT__u_memory_subsystem__DOT__u_main_memory__DOT__memory[0x1000 >> 2]
```

---

## 4. Common Test Infrastructure

### 4.1 Test Framework — doctest

**File:** `test/common/doctest.h`

The project uses [doctest](https://github.com/doctest/doctest), a lightweight C++ testing framework distributed as a single header file. It provides:

- `TEST_CASE("description")` blocks for defining test cases.
- `SUBCASE("description")` blocks for test sub-sections.
- `CHECK(expression)` and `REQUIRE(expression)` assertions.
- Automatic test discovery and registration.

### 4.2 Testbench Base Classes

**Files:** `test/common/tb_base.h`, `test/common/tb_base.cpp`

Two template base classes provide reusable simulation infrastructure:

#### `TestbenchBase<DUT>`

The foundation class for all testbenches:

- **DUT management:** Creates and owns the Verilator-generated DUT instance via `std::unique_ptr`.
- **VCD tracing:** Optionally enables VCD waveform output with configurable trace depth (99 levels by default). Tracing is activated by passing a filename to the constructor.
- **Simulation time:** Maintains a 64-bit simulation time counter, incremented on each `eval()` call.
- **Key methods:**
  - `eval()` — Evaluates the DUT, advances simulation time, and dumps trace data.
  - `get_sim_time()` — Returns the current simulation time.
  - `flush_trace()` — Flushes the VCD trace buffer to disk.

#### `ClockedTestbench<DUT>`

Extends `TestbenchBase` with clock generation:

- **Clock management:** Generates a clock signal with configurable frequency (default: 100 MHz). The clock period is calculated in picoseconds.
- **`tick()` method:** Performs a full clock cycle:
  1. Set clock low → `eval()`
  2. Set clock high → `eval()`
- **`tick(n)` overload:** Performs `n` consecutive clock cycles.
- **Virtual `set_clk()`:** Derived classes override this to connect the clock signal to the correct DUT port.

#### Utility Functions (`tb_util` namespace)

- **`random_uint32()` / `random_int()`**: Random value generation for test stimulus.
- **`ns_to_cycles()`**: Convert nanosecond durations to clock cycle counts.
- **`print_hex()`**: Formatted hexadecimal output for debugging.

---

## 5. Unit Tests (Hardware)

### 5.1 Structure and Build

**Directory:** `test/unit_test/`
**Build file:** `test/unit_test/CMakeLists.txt`

Each unit test targets a **single RTL module** and is compiled independently using a custom CMake function `add_verilog_test()`:

```cmake
add_verilog_test(
    NAME test_alu                    # Test executable name
    SOURCE test_alu.cpp              # C++ test source
    VERILOG_FILE alu.v               # RTL source to verilate
    VERILOG_DIR backend              # Subdirectory under rtl/core/
    LABELS "unit;backend"            # CTest labels
)
```

This function:
1. Verilates the specified Verilog module into a C++ library.
2. Compiles the test C++ source and links it against the verilated library and `tb_common`.
3. Registers the test with CTest under the hierarchical name `unit_test/<name>`.
4. Applies a **60-second timeout** and the `"unit_test"` label.

### 5.2 Test List

| # | Test Name | RTL Module | Category |
|---|-----------|-----------|----------|
| 1 | `test_alu` | `alu.v` | Backend |
| 2 | `test_regfile` | `regfile.v` | Backend |
| 3 | `test_branch_unit` | `branch_unit.v` | Backend |
| 4 | `test_alu_control_unit` | `alu_control_unit.v` | Backend |
| 5 | `test_immediate_generator` | `immediate_generator.v` | Backend |
| 6 | `test_instruction_decoder` | `instruction_decoder.v` | Backend |
| 7 | `test_forwarding_unit` | `forwarding_unit.v` | Backend |
| 8 | `test_hazard_detection_unit` | `hazard_detection_unit.v` | Backend |
| 9 | `test_control_unit` | `control_unit.v` | Backend |
| 10 | `test_load_store_unit` | `load_store_unit.v` | Backend |
| 11 | `test_csr_file` | `control_status_register_file.v` | Backend |
| 12 | `test_mdu` | `mdu.v` | Backend |
| 13 | `test_program_counter` | `program_counter.v` | Frontend |
| 14 | `test_branch_predictor` | `branch_predictor.v` | Frontend |
| 15 | `test_bus_arbiter` | `bus_arbiter.v` | Interconnect |
| 16 | `test_timer` | `timer.v` | Peripheral |
| 17 | `test_main_memory` | `main_memory.v` | Memory |
| 18 | `test_l1_arbiter` | `l1_arbiter.v` | Cache |
| 19 | `test_l1_inst_cache` | `l1_inst_cache.v` | Cache |
| 20 | `test_l1_data_cache` | `l1_data_cache.v` | Cache |
| 21 | `test_l2_cache` | `l2_cache.v` | Cache |
| 22 | `test_memory_subsystem` | `memory_subsystem` (full subsystem) | System |
| 23 | `test_core_tile` | `core_tile` (full tile) | System |

### 5.3 Test Methodology

Unit tests follow a consistent pattern:

1. **Instantiate the testbench:** Create a `TestbenchBase` (combinational modules) or `ClockedTestbench` (sequential modules) wrapping the verilated DUT.

2. **Apply stimulus:** Set input signals on the DUT, then call `eval()` (combinational) or `tick()` (clocked).

3. **Check outputs:** Compare DUT outputs against expected values using doctest assertions (`CHECK`, `REQUIRE`).

4. **Reference models:** Many tests implement a **C++ reference model** of the same function and verify the RTL output matches for both targeted and randomized inputs.

5. **Waveform tracing:** Tests can optionally enable VCD tracing for debugging by passing a filename to the testbench constructor.

### 5.4 Example: ALU Unit Test

**File:** `test/unit_test/test_alu.cpp`

This test validates all 11 ALU operations using:

- **Explicit test vectors:** Known input/output pairs (e.g., `5 + 3 = 8`, `0 - 1 = 0xFFFFFFFF`).
- **Edge cases:** Overflow, shift boundary conditions, signed vs. unsigned comparisons.
- **Reference model validation:** A `model_alu()` function in C++ implements the same ALU operations. The test generates 100 random input pairs for each operation and verifies the RTL output matches the model.

```cpp
// Reference model
uint32_t model_alu(uint32_t a, uint32_t b, uint8_t control) {
    switch (control) {
        case ALU_ADD:  return a + b;
        case ALU_SUB:  return a - b;
        case ALU_SLL:  return a << (b & 0x1F);
        // ... all operations
    }
}

// Test pattern: randomized verification
TEST_CASE("ALU Random Validation") {
    for (int i = 0; i < 100; i++) {
        uint32_t a = random_uint32();
        uint32_t b = random_uint32();
        dut->a = a; dut->b = b; dut->alu_control_code = ALU_ADD;
        tb.eval();
        CHECK(dut->result == model_alu(a, b, ALU_ADD));
    }
}
```

### 5.5 Example: Register File Unit Test

**File:** `test/unit_test/test_regfile.cpp`

This test validates register file behavior including:

- **Basic read/write:** Write a value to a register, tick the clock, read it back.
- **x0 hardwired zero:** Verify that writing to x0 has no effect and reads always return 0.
- **Full register coverage:** Write unique values to all 31 writable registers (x1–x31) and verify all values persist.
- **Dual-port reads:** Simultaneously read two different registers through both read ports.

---

## 6. Integration Tests — Hardware

### 6.1 Structure and Build

**Directory:** `test/integration_test/hardware/`
**Build file:** `test/integration_test/hardware/CMakeLists.txt`

Hardware integration tests execute **hand-assembled RISC-V instruction sequences** on the full `chip_top` system. They use two CMake functions:

**`add_chip_top_integration_test()`** — Links against the pre-compiled `verilated_chip_top` library:
- **120-second timeout** (longer due to full-system simulation complexity).
- Labels: `"integration_test"`, `"integration_test.hardware"`, `"hardware"`.

**`add_backend_integration_test()`** — Links against the pre-compiled `verilated_backend` library:
- Used for backend-specific isolation tests.

### 6.2 Test List

| # | Test Name | Focus Area |
|---|-----------|-----------|
| 1 | `test_basic_ops` | Basic arithmetic and memory operations |
| 2 | `test_arithmetic` | Full arithmetic and logical instruction set |
| 3 | `test_memory_ops` | Load/store variants (byte, halfword, word) |
| 4 | `test_control_flow` | Branches (BEQ, BNE, BLT, BGE, BLTU, BGEU) and jumps (JAL, JALR) |
| 5 | `test_forwarding` | Data forwarding paths (EX→EX, MEM→EX, CSR forwarding) |
| 6 | `test_hazards` | Pipeline stalls and bubble insertion for load-use hazards |
| 7 | `test_mdu` | Multiply and divide operations (M extension) |
| 8 | `test_csr_rw` | CSR read/write instructions (CSRRW, CSRRS, CSRRC) |
| 9 | `test_csr_exception` | ECALL trap handling, exception vector dispatch |
| 10 | `test_csr_interrupt` | Timer interrupt handling (mtvec, mepc, mstatus) |
| 11 | `test_csr_mret` | MRET instruction (machine trap return) |
| 12 | `test_backend` | Backend module in isolation (stall handling, signal propagation) |

### 6.3 Test Methodology

Hardware integration tests follow this workflow:

1. **Program loading (backdoor):** Machine code is loaded directly into main memory through the Verilator `rootp` hierarchy, bypassing normal memory interfaces:

   ```cpp
   auto& mem = dut->rootp->chip_top__DOT__u_memory_subsystem__DOT__u_main_memory__DOT__memory;
   mem[0] = 0x00A00093;  // ADDI x1, x0, 10
   mem[1] = 0x01400113;  // ADDI x2, x0, 20
   // ...
   ```

2. **Execution:** The simulation clock is ticked while monitoring for a termination condition. Most tests detect the `EBREAK` instruction by watching the program counter reach a known address.

3. **Result verification:** After execution completes, the test reads internal signals to verify correctness:
   - **Register values:** Read from `u_regfile__DOT__registers[idx]`
   - **Memory contents:** Read from `u_main_memory__DOT__memory[addr >> 2]`
   - **Pipeline state:** Read PC, instruction, stall, and flush signals at each stage

4. **Debug output:** Tests typically print cycle-by-cycle traces for the first 30+ cycles showing the PC, current instruction, and pipeline status (stalls, flushes, cache misses).

### 6.4 Example: Basic Operations Test

**File:** `test/integration_test/hardware/test_basic_ops.cpp`

Loads a 7-instruction program:

```asm
0x00: ADDI x1, x0, 10      # x1 = 10
0x04: ADDI x2, x0, 20      # x2 = 20
0x08: ADD  x3, x1, x2      # x3 = 30 (tests register forwarding)
0x0C: LUI  x5, 1           # x5 = 0x1000
0x10: SW   x3, 0(x5)       # Mem[0x1000] = 30
0x14: LW   x4, 0(x5)       # x4 = Mem[0x1000] = 30
0x18: EBREAK               # Halt
```

**Verification assertions:**
- `x1 == 10`, `x2 == 20`, `x3 == 30` (arithmetic)
- `x4 == 30` (load from memory)
- `x5 == 0x1000` (LUI)
- `memory[0x1000] == 30` (store to memory)

### 6.5 Example: Forwarding Test

**File:** `test/integration_test/hardware/test_forwarding.cpp`

Tests multiple forwarding scenarios and exception handling:

```asm
# GPR forwarding: EX → EX path
0x00: ADDI x1, x0, 10       # x1 = 10
0x04: ADD  x2, x1, x1       # x2 = 20 (forward x1 from prior ADDI)

# CSR write + trap handling
0x08: ADDI  x3, x0, 0x40    # x3 = 0x40 (trap handler address)
0x0C: CSRRW x0, mtvec, x3   # Set trap vector to 0x40
0x10: ECALL                  # Trigger environment call exception

# Trap handler at 0x40:
0x40: ADDI  x4, x0, 0x80    # x4 = 0x80 (return address)
0x44: CSRRW x0, mepc, x4    # Set return address
0x48: MRET                   # Return to 0x80

# Continuation at 0x80:
0x80: ADDI x10, x0, 1       # x10 = 1 (success marker)
0x84: EBREAK                # Halt
```

**Verification assertions:**
- `x2 == 20` — confirms GPR forwarding from ADDI to ADD
- `x10 == 1` — confirms successful exception → trap handler → MRET → continuation

---

## 7. Integration Tests — Software

### 7.1 Cross-Compilation Toolchain

**Directory:** `test/integration_test/software/`
**Build file:** `test/integration_test/software/CMakeLists.txt`

Software integration tests compile **real RISC-V C/Assembly programs** using Clang/LLVM:

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌───────────────┐
│  C code  │    │ Assembly │    │   ELF    │    │  Raw binary   │
│ (main.c) │───▶│ + C     │───▶│ (.elf)   │───▶│   (.bin)      │
│          │    │ (start.S)│    │          │    │               │
└──────────┘    └──────────┘    └──────────┘    └───────┬───────┘
                                                        │
                                                        ▼
                                              ┌─────────────────┐
                                              │ Loaded into     │
                                              │ Verilator sim   │
                                              │ as byte array   │
                                              └─────────────────┘
```

**Compiler flags:**

| Flag | Purpose |
|------|---------|
| `--target=riscv32` | Target RISC-V 32-bit |
| `-march=rv32i` | Base integer instruction set |
| `-nostdlib` | No standard library |
| `-ffreestanding` | Freestanding environment |
| `-O0` | No optimization (predictable code generation) |

**Binary extraction:**
```bash
llvm-objcopy -O binary program.elf program.bin
```

The raw binary path is passed to the test executable via the `-DPROGRAM_BIN_PATH` compile definition, allowing the test to load it into simulated memory at runtime.

### 7.2 Linker Script and Memory Layout

**File:** `test/integration_test/software/common/link.ld`

```
MEMORY {
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}
```

| Section | Content |
|---------|---------|
| `.text` | Code (instructions) |
| `.rodata` | Read-only data |
| `.data` | Initialized data |
| `.bss` | Zero-initialized data |

The stack pointer is initialized to `0x10000` (top of the 64 KB RAM) in the startup assembly code.

### 7.3 Common Software Support Library

**Files:** `test/integration_test/software/common/common.h`, `common.c`

Provides bare-metal runtime support for RISC-V programs:

| Function | Description |
|----------|-------------|
| `putchar(char c)` | Write a character to UART (`0x40000000`) |
| `print(const char* s)` | Print a null-terminated string |
| `print_hex(uint32_t val)` | Print a 32-bit value in hexadecimal |
| `print_int(int val)` | Print a signed integer in decimal |
| `read_mtime()` | Read the current timer value |
| `write_mtimecmp(uint32_t val)` | Set the timer compare value |
| CSR access macros | Inline assembly for `mstatus`, `mie`, `mtvec`, `mepc`, `mcause` |

**UART output** is implemented as a memory-mapped write:
```c
#define UART_TX_ADDR 0x40000000
void putchar(char c) {
    *(volatile uint32_t*)UART_TX_ADDR = c;
}
```

### 7.4 Test List

| # | Test Name | Program | Description |
|---|-----------|---------|-------------|
| 1 | `test_fibonacci` | `main.c` + `start.S` | Recursive Fibonacci computation |
| 2 | `test_csr` | `main.c` + `start.S` | CSR exception handling verification |

### 7.5 Test Methodology

Software integration tests follow this workflow:

1. **Compile:** CMake invokes Clang to cross-compile the C/Assembly source into a RISC-V ELF binary.

2. **Extract:** `llvm-objcopy` strips the ELF to a raw binary containing only the machine code and data.

3. **Load:** The test executable reads the binary file and loads it byte-by-byte into the simulated main memory.

4. **Execute:** The simulation is clocked, with the CPU starting execution from address `0x00000000`. The startup assembly (`start.S`) initializes the stack pointer and jumps to `main()`.

5. **Detect completion:** The test monitors for the `EBREAK` instruction by watching the program counter or a specific register value.

6. **Verify:** The test checks that specific registers or memory locations contain the expected results after program completion.

### 7.6 Example: Fibonacci Test

**File:** `test/integration_test/software/test_fibonacci/main.c`

The program implements recursive Fibonacci:

```c
int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

int main() {
    int result = fibonacci(10);
    // result stored in x10 (a0 register)
    asm volatile("ebreak");
}
```

**Test verification:**
- The test executes the full chip simulation until EBREAK is detected.
- It then reads register `x10` (the return value register `a0` in the RISC-V calling convention).
- Asserts that `x10 == 55` (the 10th Fibonacci number).

This test exercises the full software stack: function calls, stack operations, recursion, arithmetic, and the complete hardware pipeline including caches and memory.

---

## 8. Test Execution

### Running All Tests

```bash
cd build
cmake ../test
make -j$(nproc)
ctest
```

### Running Tests by Category

```bash
# Unit tests only
ctest -L unit_test

# Hardware integration tests only
ctest -L hardware

# Software integration tests only
ctest -L software
```

### Running a Specific Test

```bash
ctest -R test_alu           # Run just the ALU unit test
ctest -R test_basic_ops     # Run just the basic operations integration test
ctest -R test_fibonacci     # Run just the Fibonacci software test
```

### Verbose Output

```bash
ctest --output-on-failure   # Show output only for failing tests
ctest -V                    # Verbose output for all tests
```

### Test Timeouts

| Test Category | Timeout |
|--------------|---------|
| Unit tests | 60 seconds |
| Hardware integration tests | 120 seconds |
| Software integration tests | 120 seconds |

---

## 9. Debugging with Waveforms

All tests support **VCD (Value Change Dump)** waveform generation through the testbench base classes:

1. **Enable tracing:** Pass a filename to the testbench constructor:
   ```cpp
   ClockedTestbench<Vchip_top> tb("dump.vcd");
   ```

2. **Run the test:** The VCD file is written during simulation.

3. **View waveforms:** Open the `.vcd` file with a waveform viewer such as **GTKWave**:
   ```bash
   gtkwave dump.vcd
   ```

The `--trace` Verilator flag (applied globally) ensures that all internal signals are available in the trace. Combined with `--public`, this provides full visibility into all pipeline stages, cache states, bus transactions, and register values.

---

## 10. Test File Index

| File | Category | Description |
|------|----------|-------------|
| `test/CMakeLists.txt` | Build | Root build configuration; shared verilated libraries |
| `test/common/doctest.h` | Infrastructure | doctest testing framework header |
| `test/common/tb_base.h` | Infrastructure | Testbench base class templates |
| `test/common/tb_base.cpp` | Infrastructure | Random seed initialization |
| `test/unit_test/CMakeLists.txt` | Build | Unit test build definitions |
| `test/unit_test/test_alu.cpp` | Unit Test | ALU operations verification |
| `test/unit_test/test_regfile.cpp` | Unit Test | Register file verification |
| `test/unit_test/test_branch_unit.cpp` | Unit Test | Branch condition evaluation |
| `test/unit_test/test_alu_control_unit.cpp` | Unit Test | ALU control signal decoding |
| `test/unit_test/test_immediate_generator.cpp` | Unit Test | Immediate value extraction |
| `test/unit_test/test_instruction_decoder.cpp` | Unit Test | Instruction field decoding |
| `test/unit_test/test_forwarding_unit.cpp` | Unit Test | Data forwarding logic |
| `test/unit_test/test_hazard_detection_unit.cpp` | Unit Test | Load-use hazard detection |
| `test/unit_test/test_control_unit.cpp` | Unit Test | Control signal generation |
| `test/unit_test/test_load_store_unit.cpp` | Unit Test | Sub-word memory access |
| `test/unit_test/test_csr_file.cpp` | Unit Test | CSR read/write and trap logic |
| `test/unit_test/test_mdu.cpp` | Unit Test | Multiply/divide unit |
| `test/unit_test/test_program_counter.cpp` | Unit Test | PC register |
| `test/unit_test/test_branch_predictor.cpp` | Unit Test | Branch prediction (BTB + BHT) |
| `test/unit_test/test_bus_arbiter.cpp` | Unit Test | Round-robin bus arbitration |
| `test/unit_test/test_timer.cpp` | Unit Test | Timer peripheral |
| `test/unit_test/test_main_memory.cpp` | Unit Test | Dual-port SRAM |
| `test/unit_test/test_l1_arbiter.cpp` | Unit Test | L1 cache arbiter |
| `test/unit_test/test_l1_inst_cache.cpp` | Unit Test | L1 instruction cache |
| `test/unit_test/test_l1_data_cache.cpp` | Unit Test | L1 data cache |
| `test/unit_test/test_l2_cache.cpp` | Unit Test | L2 shared cache |
| `test/unit_test/test_memory_subsystem.cpp` | Unit Test | Memory subsystem with latency |
| `test/unit_test/test_core_tile.cpp` | Unit Test | Core tile (core + caches) |
| `test/integration_test/hardware/CMakeLists.txt` | Build | Hardware integration test definitions |
| `test/integration_test/hardware/test_basic_ops.cpp` | HW Integration | Basic arithmetic + memory |
| `test/integration_test/hardware/test_arithmetic.cpp` | HW Integration | Arithmetic instruction set |
| `test/integration_test/hardware/test_memory_ops.cpp` | HW Integration | Load/store variants |
| `test/integration_test/hardware/test_control_flow.cpp` | HW Integration | Branches and jumps |
| `test/integration_test/hardware/test_forwarding.cpp` | HW Integration | Data forwarding paths |
| `test/integration_test/hardware/test_hazards.cpp` | HW Integration | Pipeline hazard handling |
| `test/integration_test/hardware/test_mdu.cpp` | HW Integration | M extension operations |
| `test/integration_test/hardware/test_csr_rw.cpp` | HW Integration | CSR read/write |
| `test/integration_test/hardware/test_csr_exception.cpp` | HW Integration | ECALL exception handling |
| `test/integration_test/hardware/test_csr_interrupt.cpp` | HW Integration | Timer interrupts |
| `test/integration_test/hardware/test_csr_mret.cpp` | HW Integration | Machine trap return |
| `test/integration_test/hardware/test_backend.cpp` | HW Integration | Backend isolation test |
| `test/integration_test/software/CMakeLists.txt` | Build | Software test build + cross-compilation |
| `test/integration_test/software/common/link.ld` | SW Infrastructure | RISC-V linker script |
| `test/integration_test/software/common/common.h` | SW Infrastructure | Bare-metal runtime header |
| `test/integration_test/software/common/common.c` | SW Infrastructure | Bare-metal runtime implementation |
| `test/integration_test/software/test_fibonacci/main.c` | SW Integration | Recursive Fibonacci |
| `test/integration_test/software/test_fibonacci/start.S` | SW Integration | RISC-V startup assembly |
| `test/integration_test/software/test_csr/main.c` | SW Integration | CSR exception test program |
| `test/integration_test/software/test_csr/start.S` | SW Integration | RISC-V startup assembly |
