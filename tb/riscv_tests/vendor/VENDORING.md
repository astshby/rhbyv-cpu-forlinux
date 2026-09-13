# Vendored riscv-tests Snapshot

This directory contains an unmodified source snapshot used by the repository's
Verilator ISA regression. It makes the tests reproducible without requiring the
ignored root-level `riscv-tests/` reference clone.

- Upstream: `https://github.com/riscv-software-src/riscv-tests.git`
- riscv-tests commit: `933a897d8631773f385d45938facc466dddc7514`
- env commit: `6de71edb142be36319e380ce782c3d1830c65d68`
- Imported paths: `rv32mi`, `rv64mi`, `rv32ui`, `rv64ui`, `rv64si`, scalar test
  macros, `encoding.h`, and both upstream license files.

Do not edit vendored files to accommodate the CPU. Put environment overrides in
`tb/riscv_tests/env/` and runner policy in `scripts/verilator/`. A snapshot update
must retain license notices, record both new commits, review upstream semantic
changes, and run the complete RV32/RV64 regression.
