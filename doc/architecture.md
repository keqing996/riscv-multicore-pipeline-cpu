# RTL Architecture Documentation

## Table of Contents

- [1. System Overview](#1-system-overview)
- [2. Top-Level Architecture](#2-top-level-architecture)
  - [2.1 Chip Top (`chip_top`)](#21-chip-top-chip_top)
  - [2.2 Core Tile (`core_tile`)](#22-core-tile-core_tile)
- [3. CPU Core](#3-cpu-core)
  - [3.1 Core Top-Level (`core`)](#31-core-top-level-core)
  - [3.2 Frontend — Instruction Fetch Stage](#32-frontend--instruction-fetch-stage)
    - [3.2.1 Program Counter (`program_counter`)](#321-program-counter-program_counter)
    - [3.2.2 Branch Predictor (`branch_predictor`)](#322-branch-predictor-branch_predictor)
    - [3.2.3 Frontend Pipeline Logic (`frontend`)](#323-frontend-pipeline-logic-frontend)
  - [3.3 Backend — Decode, Execute, Memory, Writeback](#33-backend--decode-execute-memory-writeback)
    - [3.3.1 Instruction Decoder (`instruction_decoder`)](#331-instruction-decoder-instruction_decoder)
    - [3.3.2 Control Unit (`control_unit`)](#332-control-unit-control_unit)
    - [3.3.3 Register File (`regfile`)](#333-register-file-regfile)
    - [3.3.4 Immediate Generator (`immediate_generator`)](#334-immediate-generator-immediate_generator)
    - [3.3.5 ALU (`alu`)](#335-alu-alu)
    - [3.3.6 ALU Control Unit (`alu_control_unit`)](#336-alu-control-unit-alu_control_unit)
    - [3.3.7 Multiply/Divide Unit (`mdu`)](#337-multiplydivide-unit-mdu)
    - [3.3.8 Branch Unit (`branch_unit`)](#338-branch-unit-branch_unit)
    - [3.3.9 Load/Store Unit (`load_store_unit`)](#339-loadstore-unit-load_store_unit)
    - [3.3.10 Forwarding Unit (`forwarding_unit`)](#3310-forwarding-unit-forwarding_unit)
    - [3.3.11 Hazard Detection Unit (`hazard_detection_unit`)](#3311-hazard-detection-unit-hazard_detection_unit)
    - [3.3.12 Control and Status Register File (`control_status_register_file`)](#3312-control-and-status-register-file-control_status_register_file)
    - [3.3.13 Backend Pipeline Logic (`backend`)](#3313-backend-pipeline-logic-backend)
- [4. Cache Hierarchy](#4-cache-hierarchy)
  - [4.1 L1 Instruction Cache (`l1_inst_cache`)](#41-l1-instruction-cache-l1_inst_cache)
  - [4.2 L1 Data Cache (`l1_data_cache`)](#42-l1-data-cache-l1_data_cache)
  - [4.3 L1 Arbiter (`l1_arbiter`)](#43-l1-arbiter-l1_arbiter)
  - [4.4 L2 Cache (`l2_cache`)](#44-l2-cache-l2_cache)
- [5. Bus Interconnect](#5-bus-interconnect)
  - [5.1 Bus Arbiter (`bus_arbiter`)](#51-bus-arbiter-bus_arbiter)
  - [5.2 Bus Interconnect (`bus_interconnect`)](#52-bus-interconnect-bus_interconnect)
- [6. Memory Subsystem](#6-memory-subsystem)
  - [6.1 Main Memory (`main_memory`)](#61-main-memory-main_memory)
  - [6.2 Memory Subsystem Wrapper (`memory_subsystem`)](#62-memory-subsystem-wrapper-memory_subsystem)
- [7. Peripherals](#7-peripherals)
  - [7.1 Timer (`timer`)](#71-timer-timer)
  - [7.2 UART Simulator (`uart_simulator`)](#72-uart-simulator-uart_simulator)
- [8. Address Map](#8-address-map)
- [9. Pipeline Hazard Handling Summary](#9-pipeline-hazard-handling-summary)
- [10. RTL Source File Index](#10-rtl-source-file-index)

---

## 1. System Overview

This project implements a **dual-core, 5-stage pipelined RISC-V (RV32IM) CPU** in synthesizable Verilog. The system features:

- **Two independent CPU cores** (Hart 0 and Hart 1), each with private L1 instruction and data caches.
- A **shared L2 cache** backed by a 64 KB main memory.
- A **bus interconnect** with round-robin arbitration to manage shared resource access between the two cores.
- **Peripherals**: a memory-mapped timer (with interrupt support) and a simulated UART for console output.
- A **5-stage pipeline** (IF → ID → EX → MEM → WB) with branch prediction, data forwarding, hazard detection, and full trap/interrupt support.

The design targets simulation via Verilator and is structured to be educational, modular, and extensible.

---

## 2. Top-Level Architecture

### 2.1 Chip Top (`chip_top`)

**File:** `rtl/system/chip_top.v`

`chip_top` is the top-level module that instantiates and connects all major subsystems:

```
┌──────────────────────────────────────────────────────────────────┐
│                          chip_top                                │
│                                                                  │
│  ┌────────────┐   ┌────────────┐                                │
│  │ Core Tile 0│   │ Core Tile 1│   (Hart 0 & Hart 1)            │
│  │ (L1I+L1D)  │   │ (L1I+L1D)  │                                │
│  └─────┬──────┘   └──────┬─────┘                                │
│        │                  │                                      │
│        └────────┬─────────┘                                      │
│                 │                                                 │
│        ┌────────▼─────────┐                                      │
│        │ Bus Interconnect  │   (Arbiter + Address Decoder)       │
│        └──┬──────┬──────┬─┘                                      │
│           │      │      │                                        │
│     ┌─────▼──┐ ┌─▼───┐ ┌▼─────┐                                │
│     │L2 Cache│ │UART  │ │Timer │                                │
│     └────┬───┘ └──────┘ └──────┘                                │
│          │                                                       │
│     ┌────▼──────────────┐                                        │
│     │ Memory Subsystem   │                                       │
│     │ (64 KB Main Memory)│                                       │
│     └───────────────────┘                                        │
└──────────────────────────────────────────────────────────────────┘
```

**Ports:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low synchronous reset |
| `pc_out` | Output | 32 | Program counter of Hart 0 (debug) |
| `instr_out` | Output | 32 | Current instruction of Hart 0 (debug) |
| `alu_res_out` | Output | 32 | ALU result of Hart 0 (debug) |

**Key connections:**
- Each core tile connects to the bus interconnect as a bus master (master 0 and master 1).
- The bus interconnect routes requests to one of three slaves: the L2 cache, the UART simulator, or the timer.
- The L2 cache connects to the memory subsystem (main memory with latency modeling).
- The timer's interrupt request signal is broadcast to both core tiles.

### 2.2 Core Tile (`core_tile`)

**File:** `rtl/core/core_tile.v`

A `core_tile` packages a single CPU core together with its private L1 caches and an arbiter into a self-contained unit.

```
┌────────────────────────────────────────┐
│              core_tile                  │
│                                        │
│  ┌──────────────┐                      │
│  │     core      │  (5-stage pipeline) │
│  └──┬────────┬──┘                      │
│     │ instr  │ data                    │
│  ┌──▼──┐  ┌──▼──┐                      │
│  │L1 I $│  │L1 D $│  (private caches)  │
│  └──┬───┘  └──┬───┘                    │
│     └────┬────┘                        │
│     ┌────▼────┐                        │
│     │L1 Arbiter│  (D-Cache priority)   │
│     └────┬────┘                        │
│          │ → to system bus             │
└──────────┼─────────────────────────────┘
           ▼
```

**Ports:**
| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `clk`, `rst_n` | Input | 1 | Clock and reset |
| `hart_id` | Input | 32 | Hardware thread ID (0 or 1) |
| `bus_addr` | Output | 32 | Bus request address |
| `bus_wdata` | Output | 32 | Bus write data |
| `bus_be` | Output | 4 | Bus byte enables |
| `bus_we` | Output | 1 | Bus write enable |
| `bus_req` | Output | 1 | Bus request enable |
| `bus_rdata` | Input | 32 | Bus read data |
| `bus_ready` | Input | 1 | Bus ready/acknowledge |
| `timer_irq` | Input | 1 | Timer interrupt request |

The L1 arbiter prioritizes data cache requests over instruction cache requests to minimize pipeline stalls on load/store operations. An `instruction_grant` signal is registered to break combinational loops between the cache and core logic.

---

## 3. CPU Core

### 3.1 Core Top-Level (`core`)

**File:** `rtl/core/core.v`

The `core` module is the top-level CPU pipeline, wiring together the **frontend** (instruction fetch + branch prediction) and the **backend** (decode, execute, memory access, writeback). It manages control-flow signals (flushes due to branches, jumps, and traps) and stall propagation between the two halves.

**Key interfaces:**
- Instruction fetch interface: `program_counter_address` (output) and `instruction` / `instruction_grant` (inputs from I-Cache).
- Data bus interface: `bus_address`, `bus_write_data`, `bus_byte_enable`, `bus_write_enable`, `bus_read_enable` (outputs) and `bus_read_data`, `bus_busy` (inputs from D-Cache).
- Interrupt input: `timer_interrupt_request`.

### 3.2 Frontend — Instruction Fetch Stage

#### 3.2.1 Program Counter (`program_counter`)

**File:** `rtl/core/frontend/program_counter.v`

A simple 32-bit register that holds the current program counter value. It resets to `0x00000000` and updates to the value on `data_in` on every rising clock edge.

#### 3.2.2 Branch Predictor (`branch_predictor`)

**File:** `rtl/core/frontend/branch_predictor.v`

A **Branch Target Buffer (BTB)** combined with a **Branch History Table (BHT)** using 2-bit saturating counters.

| Parameter | Value | Description |
|-----------|-------|-------------|
| `ENTRIES` | 64 | Number of BTB/BHT entries |
| `INDEX_BITS` | 6 | Bits used to index into the tables |

**Prediction logic (IF stage):**
1. The lower bits of the fetch PC index into the BTB and BHT.
2. A prediction of "taken" is made when the entry is valid, the stored tag matches the upper PC bits, and the 2-bit counter value is ≥ 2 (weakly taken or strongly taken).
3. On a taken prediction, the predicted target address is read from the BTB.

**Update logic (EX stage feedback):**
- When a branch or jump completes in the execute stage, the BTB entry is updated with the actual target and the BHT counter is incremented (taken) or decremented (not taken).
- Jump instructions always set the counter to "strongly taken" (3).

**2-bit counter states:**
| Value | State | Prediction |
|-------|-------|------------|
| 0 | Strongly Not Taken | Not Taken |
| 1 | Weakly Not Taken | Not Taken |
| 2 | Weakly Taken | Taken |
| 3 | Strongly Taken | Taken |

#### 3.2.3 Frontend Pipeline Logic (`frontend`)

**File:** `rtl/core/frontend/frontend.v`

The frontend manages the IF stage and the **IF/ID pipeline register**. It determines the next PC value based on the following priority:

1. **Trap** (highest priority): If `flush_due_to_trap` is asserted, the next PC is set to `trap_pc` (the trap vector or return address).
2. **Branch/Jump misprediction**: If `flush_due_to_branch` or `flush_due_to_jump` is asserted, the next PC is set to `correct_pc`.
3. **Stall**: If the backend requests a stall (`stall_backend`) or the instruction cache has not granted the instruction yet, the PC and IF/ID register hold their current values.
4. **Branch prediction taken**: If the predictor indicates taken, the next PC is set to `prediction_target`.
5. **Sequential**: Otherwise, the next PC is `current_pc + 4`.

On a flush, the IF/ID pipeline register is cleared (instruction set to NOP `0x00000013`). Prediction metadata (`prediction_taken`, `prediction_target`) is passed through the IF/ID register to enable misprediction detection in the execute stage.

---

### 3.3 Backend — Decode, Execute, Memory, Writeback

#### 3.3.1 Instruction Decoder (`instruction_decoder`)

**File:** `rtl/core/backend/instruction_decoder.v`

Pure combinational logic that extracts standard RISC-V instruction fields from a 32-bit instruction word:

| Field | Bits | Description |
|-------|------|-------------|
| `opcode` | `[6:0]` | Operation code |
| `rd` | `[11:7]` | Destination register |
| `function_3` | `[14:12]` | Function code (sub-operation) |
| `rs1` | `[19:15]` | Source register 1 |
| `rs2` | `[24:20]` | Source register 2 |
| `function_7` | `[31:25]` | Extended function code |

#### 3.3.2 Control Unit (`control_unit`)

**File:** `rtl/core/backend/control_unit.v`

Combinational control signal generator driven by the opcode, funct3, and funct7 fields. Produces the following control signals:

| Signal | Description |
|--------|-------------|
| `branch` | Instruction is a conditional branch |
| `jump` | Instruction is JAL or JALR |
| `memory_read_enable` | Load instruction |
| `memory_write_enable` | Store instruction |
| `memory_to_register_select` | Writeback data comes from memory (vs. ALU) |
| `alu_operation_code` | 3-bit ALU operation category |
| `alu_source_select` | ALU operand B: register or immediate |
| `alu_source_a_select` | ALU operand A: register or PC |
| `register_write_enable` | Write result to register file |
| `csr_write_enable` | CSR write operation |
| `csr_to_register_select` | Writeback data comes from CSR |
| `is_machine_return` | MRET instruction |
| `is_environment_call` | ECALL instruction |
| `is_mdu_operation` | Multiply/divide instruction (M extension) |

Supported instruction types: R-type, I-type (arithmetic + loads), S-type (stores), B-type (branches), U-type (LUI, AUIPC), J-type (JAL, JALR), and System (CSR, ECALL, MRET).

#### 3.3.3 Register File (`regfile`)

**File:** `rtl/core/backend/regfile.v`

A standard 32-entry × 32-bit register file with:
- **Two asynchronous read ports** (`rs1`, `rs2`).
- **One synchronous write port** (`rd`), writing on the rising clock edge.
- **Write-through forwarding**: if the same register is being written and read in the same cycle, the new value is forwarded to the read output.
- **x0 hardwired to zero**: reads from register 0 always return 0; writes to register 0 are ignored.
- **Stack pointer initialization**: register x2 (`sp`) is initialized to `0x02000000` (32 MB) on reset.

#### 3.3.4 Immediate Generator (`immediate_generator`)

**File:** `rtl/core/backend/immediate_generator.v`

Combinational logic that extracts and sign-extends the immediate value from RISC-V instructions based on the opcode (instruction format type):

| Format | Opcode Pattern | Immediate Bits |
|--------|---------------|----------------|
| I-type | Load, ALU-imm, JALR | `inst[31:20]` sign-extended |
| S-type | Store | `{inst[31:25], inst[11:7]}` sign-extended |
| B-type | Branch | `{inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}` sign-extended |
| U-type | LUI, AUIPC | `{inst[31:12], 12'b0}` |
| J-type | JAL | `{inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}` sign-extended |
| System | CSR | `{27'b0, inst[19:15]}` zero-extended (CSR immediate) |

#### 3.3.5 ALU (`alu`)

**File:** `rtl/core/backend/alu.v`

A purely combinational 32-bit Arithmetic Logic Unit supporting 11 operations:

| Control Code | Operation | Description |
|-------------|-----------|-------------|
| `4'b0000` | ADD | `a + b` |
| `4'b1000` | SUB | `a - b` |
| `4'b0001` | SLL | `a << b[4:0]` (logical left shift) |
| `4'b0010` | SLT | Signed compare: `(a < b) ? 1 : 0` |
| `4'b0011` | SLTU | Unsigned compare: `(a < b) ? 1 : 0` |
| `4'b0100` | XOR | `a ^ b` |
| `4'b0101` | SRL | `a >> b[4:0]` (logical right shift) |
| `4'b1101` | SRA | `a >>> b[4:0]` (arithmetic right shift) |
| `4'b0110` | OR | `a \| b` |
| `4'b0111` | AND | `a & b` |
| `4'b1001` | LUI | Pass-through `b` (for LUI instructions) |

#### 3.3.6 ALU Control Unit (`alu_control_unit`)

**File:** `rtl/core/backend/alu_control_unit.v`

Translates the 3-bit `alu_operation_code` from the control unit, combined with `function_3` and `function_7`, into the 4-bit ALU control code:

| ALU Op Code | Meaning | Result |
|-------------|---------|--------|
| `3'b000` | Load/Store/AUIPC | Always ADD |
| `3'b001` | Branch | SUB, SLT, or SLTU depending on funct3 |
| `3'b010` | R-type | Determined by funct3 + funct7[5] |
| `3'b011` | I-type | Determined by funct3 (funct7 only for shifts) |
| `3'b100` | LUI | LUI pass-through |

#### 3.3.7 Multiply/Divide Unit (`mdu`)

**File:** `rtl/core/backend/mdu.v`

A multi-cycle multiply/divide unit implementing the RISC-V M extension. It uses a 3-state FSM:

| State | Description |
|-------|-------------|
| `IDLE` | Waiting for a `start` signal |
| `WORK` | Performing shift-and-add (multiply) or restoring division over 32 cycles |
| `DONE` | Result available; asserts `ready` for one cycle |

**Supported operations (3-bit `operation` input):**

| Code | Operation | Description |
|------|-----------|-------------|
| `000` | MUL | Lower 32 bits of signed × signed |
| `001` | MULH | Upper 32 bits of signed × signed |
| `010` | MULHSU | Upper 32 bits of signed × unsigned |
| `011` | MULHU | Upper 32 bits of unsigned × unsigned |
| `100` | DIV | Signed division |
| `101` | DIVU | Unsigned division |
| `110` | REM | Signed remainder |
| `111` | REMU | Unsigned remainder |

Division by zero returns `0xFFFFFFFF` (DIV/DIVU) or the dividend (REM/REMU), consistent with the RISC-V specification. The unit asserts `busy` during computation, which stalls the pipeline.

#### 3.3.8 Branch Unit (`branch_unit`)

**File:** `rtl/core/backend/branch_unit.v`

Combinational comparator that evaluates branch conditions in the execute stage:

| funct3 | Instruction | Condition |
|--------|-------------|-----------|
| `000` | BEQ | `a == b` |
| `001` | BNE | `a != b` |
| `100` | BLT | `a < b` (signed) |
| `101` | BGE | `a >= b` (signed) |
| `110` | BLTU | `a < b` (unsigned) |
| `111` | BGEU | `a >= b` (unsigned) |

#### 3.3.9 Load/Store Unit (`load_store_unit`)

**File:** `rtl/core/backend/load_store_unit.v`

Handles sub-word memory alignment for load and store operations:

**Stores:** Generates byte-enable masks and shifts write data based on the address offset (`address[1:0]`) and funct3 (SB, SH, SW).

**Loads:** Extracts the correct byte/halfword from the 32-bit read data, performs sign-extension (LB, LH) or zero-extension (LBU, LHU) as appropriate.

| funct3 | Operation | Width | Extension |
|--------|-----------|-------|-----------|
| `000` | LB / SB | 8-bit | Sign |
| `001` | LH / SH | 16-bit | Sign |
| `010` | LW / SW | 32-bit | — |
| `100` | LBU | 8-bit | Zero |
| `101` | LHU | 16-bit | Zero |

#### 3.3.10 Forwarding Unit (`forwarding_unit`)

**File:** `rtl/core/backend/forwarding_unit.v`

Resolves **data hazards** by detecting when an instruction in the execute stage depends on the result of an instruction in the memory or writeback stage. It outputs 2-bit mux select signals for ALU operands A and B:

| Select | Source |
|--------|--------|
| `2'b00` | Register file (no hazard) |
| `2'b01` | Forwarded from MEM stage |
| `2'b10` | Forwarded from WB stage |

**Priority:** MEM stage forwarding takes precedence over WB stage forwarding (most recent result wins). Forwarding to x0 is suppressed.

#### 3.3.11 Hazard Detection Unit (`hazard_detection_unit`)

**File:** `rtl/core/backend/hazard_detection_unit.v`

Detects **load-use hazards** that cannot be resolved by forwarding alone. When an instruction in the execute stage is a load (`memory_read_enable_execute` is set) and its destination register matches a source register of the instruction in the decode stage, the pipeline is stalled for one cycle (inserting a bubble).

#### 3.3.12 Control and Status Register File (`control_status_register_file`)

**File:** `rtl/core/backend/control_status_register_file.v`

Implements the machine-mode CSRs required for trap and interrupt handling:

| CSR | Address | Description |
|-----|---------|-------------|
| `mstatus` | `0x300` | Machine status (MIE, MPIE fields) |
| `mie` | `0x304` | Machine interrupt enable (MTIE bit) |
| `mtvec` | `0x305` | Machine trap vector base address |
| `mepc` | `0x341` | Machine exception program counter |
| `mcause` | `0x342` | Machine exception cause |
| `mip` | `0x344` | Machine interrupt pending (MTIP bit) |
| `mhartid` | `0xF14` | Hardware thread ID (read-only) |

**CSR operations (via `csr_op`):**
| csr_op (funct3) | Operation | Description |
|---------|-----------|-------------|
| `001` | CSRRW | Atomic read/write |
| `010` | CSRRS | Atomic read and set bits |
| `011` | CSRRC | Atomic read and clear bits |
| `101` | CSRRWI | Immediate read/write |
| `110` | CSRRSI | Immediate read and set bits |
| `111` | CSRRCI | Immediate read and clear bits |

**Exception handling:**
- On `exception_enable`, the CSR file saves the current PC to `mepc`, records the cause in `mcause`, clears MIE in `mstatus` (disabling interrupts), and saves the previous MIE to MPIE.
- On `machine_return_enable` (MRET), `mstatus.MIE` is restored from `mstatus.MPIE`.

**Interrupt detection:**
- A timer interrupt is recognized when `mstatus.MIE` (global interrupt enable), `mie.MTIE` (timer interrupt enable), and `mip.MTIP` (timer interrupt pending) are all set.
- The `mip.MTIP` bit reflects the external `timer_interrupt_request` input.

#### 3.3.13 Backend Pipeline Logic (`backend`)

**File:** `rtl/core/backend/backend.v`

The backend is the largest module, implementing the ID, EX, MEM, and WB pipeline stages with all inter-stage registers and control logic.

**ID (Decode) Stage:**
- Decodes the instruction from the IF/ID register using the instruction decoder and control unit.
- Reads source operands from the register file.
- Generates the immediate value.
- Checks for load-use hazards via the hazard detection unit.
- Reads CSR values for system instructions.
- Detects interrupts and ECALL exceptions; generates trap signals.

**EX (Execute) Stage:**
- Selects ALU operands via forwarding muxes (forwarding unit output).
- Executes the ALU operation, or starts the MDU for multiply/divide instructions.
- Evaluates branch conditions (branch unit) and computes branch targets.
- Detects branch/jump mispredictions by comparing the actual outcome with the IF-stage prediction.
- On misprediction, asserts `flush_due_to_branch` or `flush_due_to_jump` and provides the `correct_pc`.
- Provides branch resolution feedback to the branch predictor.

**MEM (Memory Access) Stage:**
- Drives the load/store unit for memory read/write operations.
- The bus interface stalls the pipeline (`bus_busy`) while waiting for memory responses.

**WB (Writeback) Stage:**
- Writes the result (from ALU, memory, or CSR) back to the register file.
- Selects the write data source based on control signals (`memory_to_register_select`, `csr_to_register_select`).

**Pipeline flush priority:**
1. Trap (exception or interrupt) — highest priority
2. Branch misprediction
3. Jump misprediction

On any flush, the affected pipeline stage registers are cleared to NOP.

---

## 4. Cache Hierarchy

The system employs a two-level cache hierarchy with write-through policies at both levels.

### 4.1 L1 Instruction Cache (`l1_inst_cache`)

**File:** `rtl/cache/l1_inst_cache.v`

| Parameter | Value | Description |
|-----------|-------|-------------|
| `NUM_SETS` | 256 | Number of cache sets |
| `INDEX_BITS` | 8 | Bits for set indexing |
| `OFFSET_BITS` | 4 | Bits for block offset (16-byte blocks) |
| `TAG_BITS` | 20 | Bits for tag comparison |

**Organization:** 4 KB direct-mapped cache (256 sets × 16 bytes/block = 4 KB). Each block holds 4 words (128 bits).

**State machine (5 states):**
| State | Description |
|-------|-------------|
| `IDLE` | Serve hits; on miss, latch address and start refill |
| `FETCH_0..3` | Fetch 4 words sequentially from lower-level memory |
| `UPDATE` | Write the complete block to cache, return to IDLE |

On a hit, the requested word is returned in the same cycle and `stall_cpu` remains deasserted. On a miss, `stall_cpu` is asserted while the 4-word refill completes.

### 4.2 L1 Data Cache (`l1_data_cache`)

**File:** `rtl/cache/l1_data_cache.v`

Same parameters as the L1 instruction cache (4 KB, direct-mapped, 16-byte blocks).

**Policies:**
- **Write-through**: All writes propagate to the next level immediately.
- **No-write-allocate**: A write miss does not trigger a cache line fill; the write goes directly to lower memory.

**State machine (7 states):**
| State | Description |
|-------|-------------|
| `IDLE` | Serve read hits and process writes |
| `WRITE_THROUGH` | Forward write to lower-level memory |
| `READ_MISS_0..3` | Fetch 4 words on a read miss |
| `READ_UPDATE` | Install the fetched block and return data |

On a read hit, data is returned immediately. On a read miss, the pipeline stalls while 4 words are fetched. Writes update the cache (if hit) and always write through to lower memory.

### 4.3 L1 Arbiter (`l1_arbiter`)

**File:** `rtl/cache/l1_arbiter.v`

Multiplexes the L1 instruction cache and L1 data cache onto a single bus port toward the L2 cache. Uses a 3-state FSM (IDLE, ICACHE, DCACHE).

**Priority:** The data cache is given higher priority than the instruction cache when both request simultaneously. This minimizes pipeline stalls caused by load/store operations, as instruction fetches can tolerate slightly higher latency (the pipeline can stall gracefully via the `stall_cpu` signal from the I-Cache).

### 4.4 L2 Cache (`l2_cache`)

**File:** `rtl/cache/l2_cache.v`

| Parameter | Value | Description |
|-----------|-------|-------------|
| `NUM_SETS` | 1024 | Number of cache sets |
| `INDEX_BITS` | 10 | Bits for set indexing |
| `OFFSET_BITS` | 4 | Bits for block offset (16-byte blocks) |
| `TAG_BITS` | 18 | Bits for tag comparison |

**Organization:** 16 KB direct-mapped cache (1024 sets × 16 bytes/block = 16 KB). Shared between both cores.

**Policies:** Write-through with a refill state machine similar to the L1 caches (6 states for 4-word sequential refill on read miss).

---

## 5. Bus Interconnect

### 5.1 Bus Arbiter (`bus_arbiter`)

**File:** `rtl/interconnect/bus_arbiter.v`

A **round-robin arbiter** that manages access from two bus masters (Core Tile 0 and Core Tile 1) to the shared bus.

**State machine:**
| State | Description |
|-------|-------------|
| `OWNER_NONE` | Bus is idle; grant to any requesting master |
| `OWNER_M0` | Master 0 owns the bus until transaction completes |
| `OWNER_M1` | Master 1 owns the bus until transaction completes |

**Fairness:** A `priority_m1` flag alternates after each completed transaction, ensuring that when both masters request simultaneously, they are served in alternating order. When only one master requests, it is granted immediately.

### 5.2 Bus Interconnect (`bus_interconnect`)

**File:** `rtl/interconnect/bus_interconnect.v`

Wraps the bus arbiter and adds **address decoding** to route the winning master's request to the correct slave:

| Address Range | Slave | Description |
|--------------|-------|-------------|
| `0x00000000` – `0x3FFFFFFF` | Slave 0 (L2 Cache → Main Memory) | RAM region |
| `0x40000000` – `0x40003FFF` | Slave 1 (UART Simulator) | UART TX register |
| `0x40004000` – `0x40007FFF` | Slave 2 (Timer) | Timer registers |

The interconnect generates per-slave enable signals based on address bits `[31:16]` and `[15:14]`, and multiplexes the read data and ready signals back to the winning master.

---

## 6. Memory Subsystem

### 6.1 Main Memory (`main_memory`)

**File:** `rtl/memory/main_memory.v`

A **64 KB dual-port SRAM** (16,384 × 32-bit words).

| Port | Access | Purpose |
|------|--------|---------|
| Port A | Asynchronous read-only | Instruction fetch (from L2 cache) |
| Port B | Synchronous write + asynchronous read | Data read/write (from L2 cache) |

**Byte-enable support:** Port B supports per-byte write enables (`byte_enable_b[3:0]`), allowing byte and halfword store operations.

Word addressing is derived by right-shifting the byte address by 2 (`address[15:2]`).

### 6.2 Memory Subsystem Wrapper (`memory_subsystem`)

**File:** `rtl/system/memory_subsystem.v`

Wraps the main memory and introduces a **2-cycle access latency** on both ports. This models realistic memory timing:

- When a request arrives, a counter starts from 0.
- The `ready` signal is asserted after 2 clock cycles.
- Once ready, the counter resets and waits for the next request.

This latency is critical for exercising the cache miss penalty path in simulation.

---

## 7. Peripherals

### 7.1 Timer (`timer`)

**File:** `rtl/peripherals/timer.v`

A RISC-V standard machine-mode timer implementing two 64-bit memory-mapped registers:

| Register | Address | Description |
|----------|---------|-------------|
| `mtime` (low) | `0x40004000` | Current timer value (lower 32 bits) |
| `mtime` (high) | `0x40004004` | Current timer value (upper 32 bits) |
| `mtimecmp` (low) | `0x40004008` | Timer compare value (lower 32 bits) |
| `mtimecmp` (high) | `0x4000400C` | Timer compare value (upper 32 bits) |

`mtime` increments by 1 every clock cycle. When `mtime >= mtimecmp`, the `interrupt_request` output is asserted. Software clears the interrupt by writing a new value to `mtimecmp` that is greater than the current `mtime`.

### 7.2 UART Simulator (`uart_simulator`)

**File:** `rtl/peripherals/uart_simulator.v`

A minimal simulation-only UART stub. When a write occurs to address `0x40000000`, the lower 8 bits of the write data are printed to the simulation console via the Verilog `$write` system task. This enables software running on the CPU to produce console output without a real UART peripheral.

---

## 8. Address Map

| Start Address | End Address | Size | Peripheral | Access |
|--------------|-------------|------|------------|--------|
| `0x00000000` | `0x0000FFFF` | 64 KB | Main Memory (RAM) | Read/Write |
| `0x40000000` | `0x40000003` | 4 B | UART TX Register | Write-only |
| `0x40004000` | `0x4000400F` | 16 B | Timer Registers | Read/Write |

---

## 9. Pipeline Hazard Handling Summary

| Hazard Type | Detection | Resolution |
|-------------|-----------|------------|
| **RAW (Read After Write)** — register | Forwarding unit detects EX/MEM/WB → EX dependency | Forward data from MEM or WB stage to EX stage inputs |
| **Load-use** — register depends on prior load | Hazard detection unit detects load in EX + source match in ID | Stall pipeline for 1 cycle (insert bubble), then forward |
| **Control** — branch/jump misprediction | Branch unit evaluates condition in EX; compare with prediction | Flush IF and ID stages; redirect PC to correct target |
| **MDU busy** | MDU asserts `busy` during multi-cycle operations | Stall pipeline until MDU asserts `ready` |
| **Memory stall** | Bus asserts `busy` during cache miss handling | Stall pipeline until bus transaction completes |
| **Trap/Interrupt** | CSR file detects enabled interrupt or ECALL | Flush pipeline; redirect PC to `mtvec` |

---

## 10. RTL Source File Index

| File | Module | Category | Description |
|------|--------|----------|-------------|
| `rtl/system/chip_top.v` | `chip_top` | System | Top-level SoC |
| `rtl/system/memory_subsystem.v` | `memory_subsystem` | System | Memory with 2-cycle latency |
| `rtl/core/core.v` | `core` | Core | CPU pipeline top-level |
| `rtl/core/core_tile.v` | `core_tile` | Core | Core + L1 caches + arbiter |
| `rtl/core/frontend/frontend.v` | `frontend` | Core/Frontend | IF stage + branch prediction |
| `rtl/core/frontend/program_counter.v` | `program_counter` | Core/Frontend | PC register |
| `rtl/core/frontend/branch_predictor.v` | `branch_predictor` | Core/Frontend | BTB + 2-bit BHT |
| `rtl/core/backend/backend.v` | `backend` | Core/Backend | ID/EX/MEM/WB pipeline |
| `rtl/core/backend/instruction_decoder.v` | `instruction_decoder` | Core/Backend | Instruction field extraction |
| `rtl/core/backend/control_unit.v` | `control_unit` | Core/Backend | Control signal generation |
| `rtl/core/backend/regfile.v` | `regfile` | Core/Backend | 32×32 register file |
| `rtl/core/backend/immediate_generator.v` | `immediate_generator` | Core/Backend | Immediate extraction |
| `rtl/core/backend/alu.v` | `alu` | Core/Backend | Arithmetic logic unit |
| `rtl/core/backend/alu_control_unit.v` | `alu_control_unit` | Core/Backend | ALU operation decoder |
| `rtl/core/backend/mdu.v` | `mdu` | Core/Backend | Multiply/divide unit |
| `rtl/core/backend/branch_unit.v` | `branch_unit` | Core/Backend | Branch condition evaluator |
| `rtl/core/backend/load_store_unit.v` | `load_store_unit` | Core/Backend | Sub-word memory access |
| `rtl/core/backend/forwarding_unit.v` | `forwarding_unit` | Core/Backend | Data hazard forwarding |
| `rtl/core/backend/hazard_detection_unit.v` | `hazard_detection_unit` | Core/Backend | Load-use hazard detection |
| `rtl/core/backend/control_status_register_file.v` | `control_status_register_file` | Core/Backend | CSR file + trap logic |
| `rtl/cache/l1_inst_cache.v` | `l1_inst_cache` | Cache | 4 KB L1 instruction cache |
| `rtl/cache/l1_data_cache.v` | `l1_data_cache` | Cache | 4 KB L1 data cache |
| `rtl/cache/l1_arbiter.v` | `l1_arbiter` | Cache | I/D-cache bus arbiter |
| `rtl/cache/l2_cache.v` | `l2_cache` | Cache | 16 KB shared L2 cache |
| `rtl/interconnect/bus_interconnect.v` | `bus_interconnect` | Interconnect | Address decoder + slave mux |
| `rtl/interconnect/bus_arbiter.v` | `bus_arbiter` | Interconnect | Round-robin bus arbiter |
| `rtl/memory/main_memory.v` | `main_memory` | Memory | 64 KB dual-port SRAM |
| `rtl/peripherals/timer.v` | `timer` | Peripheral | RISC-V machine timer |
| `rtl/peripherals/uart_simulator.v` | `uart_simulator` | Peripheral | Simulated UART output |
