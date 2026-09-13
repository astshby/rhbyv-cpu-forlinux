# A4 riscv-tests Validation

This flow compiles the fixed upstream snapshot under
`tb/riscv_tests/vendor/riscv-tests/`. A local M-mode environment supplies reset,
linking, memory-image generation, trap entry, and tohost PASS/FAIL reporting so
the tests match the A4 core boundary.

The optional root `riscv-tests/` clone is ignored and used only for reading or
comparison. A fresh clone of this repository already contains everything needed
for the regression. Put every CPU-specific environment or test-list change in
this directory or `scripts/verilator/`; do not patch vendored upstream files.

Run from the repository root:

```bash
make riscv-tests XLEN=32
make riscv-tests XLEN=64
```

The selected MI set covers Zicsr operations, machine CSR identification,
ECALL/EBREAK, illegal instructions, `mret`, counter writes, and all implemented
misalignment traps. The UI set covers applicable RV32I/RV64I arithmetic,
control-flow, memory, and bypass cases. Generated ELF files, dumps, memory
images, and logs stay under ignored `build/` and `logs/` directories.

Tests requiring features beyond A4 are intentionally excluded: debug triggers
(`breakpoint`), writable `misa`/C (`ma_fetch`), PMP, U/S modes, and Zicntr user
aliases (`cycle`/`instret`). RV32 `instret_overflow` also requires the unplanned
`minstreth` CSR; the applicable RV64 form is included.

The formal regression passes RV32 50/50 (MI 10 + UI 40) and RV64 65/65 (MI 13 +
UI 52). It explicitly skips `fence_i` and `ma_data`, which remain outside the
present Zifencei/Harvard and misaligned-completion policy. See the root
`docs/understand/SOFTWARE_TEST_STACK_GUIDE.md` for the full software-to-hardware path and why
these cases do not block CoreMark.

A4 currently handles synchronous machine-mode exceptions only. `mie`/`mip` and
external, timer, or software interrupt delivery remain reserved for the later
interrupt stage even though their architectural encodings already exist in
`riscv_priv_pkg`.
