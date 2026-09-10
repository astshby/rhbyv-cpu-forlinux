# Repository Guidelines

## Project Structure & Module Organization

SystemVerilog RTL lives in `vsrc/`. Keep synthesizable CPU logic in `vsrc/core/`, the FPGA-facing wrapper in `vsrc/cpu/`, simulation-only memory and top modules in `vsrc/sim_cpu/`, and shared definitions in `vsrc/pkg/`. Module tests belong in `tb/unit/`; full-core directed tests belong in `tb/core/`. Source lists and Verilator runners are maintained under `scripts/`. `benchmark/` is reserved for later software workloads and may remain empty.

## Build, Test, and Development Commands

Run commands from the repository root:

- `make lint XLEN=32` checks all synthesizable and simulation tops.
- `make unit XLEN=32` runs every `tb/unit/tb_*.sv` test.
- `make directed XLEN=32` runs full-core tests under `tb/core/`.
- Repeat the three commands with `XLEN=64` after width-dependent changes.
- `make test XLEN=32` performs the complete lint, unit, and directed sequence.

Verilator is the primary simulator; do not introduce Cocotb. Vivado work is deferred unless explicitly requested.

## Coding Style & Naming Conventions

Use four-space indentation, lowercase module/file names, explicit port connections, `always_comb` for combinational logic, and `always_ff` with nonblocking assignments for sequential logic. Separate unrelated combinational and sequential behavior into functional blocks. Prefix each block with a short comment explaining its purpose. Preserve module-header descriptions and existing useful comments; move or adapt them when code moves, but do not silently delete them. Prefer context-specific architectural constants from `riscv_unpriv_pkg` or `riscv_priv_pkg` over unexplained literals.

## Testing & Change Control

Every RTL change requires a focused module test followed by the complete applicable regression. Tests must use deterministic clock-edge stimulus, declare `timeunit`/`timeprecision`, and print an unambiguous `PASS` marker. Record stage-level changes and exact test results in `COMMIT.md`.

Treat reviewed stage branches and `main` as protected baselines. Explain the proposed scope before changing completed stages. Never discard user changes, remove comments, mix unrelated files into a commit, or delete a stage branch until its history is reachable from the target and all regressions pass.
