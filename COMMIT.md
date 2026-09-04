# 设计调整记录

## 2026-09-02（Asia/Shanghai）— SYSTEM uOp 分类

状态：A0 学习分支上的适应性设计调整，尚未替代后续阶段实现。

### 评估结论

`ECALL`、`EBREAK` 和 `MRET` 使用相同的 `SYSTEM` major opcode，但不是普通
Zicsr read-modify-write 指令。三个 `is_*` 控制位允许无效组合，改用互斥的
`sys_op_e` 更适合作为译码结果：

```systemverilog
typedef enum logic [1:0] {
    SYS_NONE, SYS_ECALL, SYS_EBREAK, SYS_MRET
} sys_op_e;
```

`ECALL/EBREAK` 产生同步异常，trap commit 才更新 `mepc/mcause/mtval/mstatus`；
`MRET` 是特权返回指令，在 commit 恢复 `mstatus` 并重定向到 `mepc`。它们均不
应设置 `csr_valid/csr_write`，也不使用 `csr_cmd_e`。

### 本次调整

- 将 `uop_t.is_ecall/is_ebreak/is_mret` 合并为 `uop_t.sys_op`。
- 增加 ECALL、EBREAK、MRET 的完整 32-bit 编码。
- 增加 `tb_core_types`，检查零值 uOp、SYSTEM 分类互斥性和指令编码。

### 后续适配

A1 及以后阶段的 decoder、异常检测和串行化条件需要分别改为比较
`SYS_ECALL`、`SYS_EBREAK`、`SYS_MRET`。未来实现 S-mode/WFI 时再扩宽枚举并
增加 `SYS_SRET`、`SYS_WFI`，不提前把未实现指令声明为可执行功能。

## 2026-09-03（Asia/Shanghai）— 特权架构定义分层

状态：A0 审核后的适应性设计调整，于 2026-09-04 纳入本地提交。

### 评估结论

- `uop_t` 保存译码后的静态执行意图；`exception_t` 是各流水级可更新的动态状态，两者继续分离。
- `FU_LSU` 表示 Load/Store Unit，与 U-type 指令无关；LUI/AUIPC 复用 ALU。
- 指令编码与特权架构定义分层，避免 `pipeline_pkg` 持有 RISC-V 原因编号。

### 本次调整

- 将 `riscv_isa_pkg` 拆分为非特权的 `riscv_unpriv_pkg` 和特权架构的 `riscv_priv_pkg`。
- `ECALL/EBREAK` 归入非特权指令编码，`MRET`、机器级 CSR 与 trap cause 归入特权架构定义。
- 新增 `riscv_priv_pkg`，收纳特权指令、CSR 地址、trap cause 及机器中断字段。
- 增加 `mie/mip`、`MIE/MPIE`、`MSIE/MTIE/MEIE` 和对应 pending bit 的架构常量。
- Core 参数 assertion 在综合时通过 `` `SYNTHESIS `` 关闭，在 Verilator 仿真/lint 时保留。
- 新增 `tb_riscv_unpriv` 和 `tb_riscv_priv`，对 RV32/RV64 下的非特权/特权编码常量做模块级检查。

### 范围边界

本次只建立架构常量，不表示 A0 已实现异步中断。`mtime/mtimecmp`
属于平台级内存映射设备，后续由 interrupt/trap arbitration 消费 `MTIP`。

## 2026-09-04（Asia/Shanghai）— A0 审核完成

- RV32/RV64 的 core、simulation top 与 synthesizable top 均通过 Verilator lint。
- RV32/RV64 的 `tb_core_config`、`tb_core_types`、`tb_riscv_unpriv`、`tb_riscv_priv` 均通过。
- 本提交作为 A0 已审核基线，后续合并到 `stage/a1-rv32i-six-stage`。
