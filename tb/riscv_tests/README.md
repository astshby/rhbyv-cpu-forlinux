# A4 riscv-tests Validation

This flow compiles upstream sources from `riscv-tests/isa/rv32mi` and
`riscv-tests/isa/rv64mi` without modifying that nested checkout. A local
M-mode environment replaces only reset, linking, memory-image generation, and
MMIO PASS/FAIL reporting so the tests match the A4 core boundary.

Run from the repository root:

```bash
make riscv-tests XLEN=32
make riscv-tests XLEN=64
```

The selected set covers Zicsr operations, machine CSR identification,
ECALL/EBREAK, illegal instructions, `mret`, counter writes, and all implemented
misalignment traps. Generated ELF files, dumps, memory images, and logs stay
under ignored `build/` and `logs/` directories.

Tests requiring features beyond A4 are intentionally excluded: debug triggers
(`breakpoint`), writable `misa`/C (`ma_fetch`), PMP, U/S modes, and Zicntr user
aliases (`cycle`/`instret`). RV32 `instret_overflow` also requires the unplanned
`minstreth` CSR; the applicable RV64 form is included.

A4 currently handles synchronous machine-mode exceptions only. `mie`/`mip` and
external, timer, or software interrupt delivery remain reserved for the later
interrupt stage even though their architectural encodings already exist in
`riscv_priv_pkg`.
