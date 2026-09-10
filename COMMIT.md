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

## 2026-09-04（Asia/Shanghai）— A0 合并到 A1

### 合并处理

- 保留 A1 的 IF–D1–D2–EX–MEM–WB 数据通路，不回退为 A0 空框架。
- 同步 A0 审核后的 `sys_op_e`、特权/非特权 package 分层和异常类型归属。
- Decoder 与立即数生成器改为导入 `riscv_unpriv_pkg`。
- 保留已审核的中文学习注释，并保留 A1 的参数断言综合保护。

### 验证

- `make lint XLEN=32` 和 `make lint XLEN=64` 通过。
- `make unit XLEN=32` 和 `make unit XLEN=64` 的全部模块测试通过。
- `make directed XLEN=32` 通过，`tb_core_rv32i` 用 33 个周期完成。
- A1 的 directed test 明确限定 `XLEN=32`；RV64 整核指令行为由 A2 验收。

## 2026-09-10（Asia/Shanghai）— A1 审核改革固化

### 关键修改

- 将流水级控制统一为 `pipeline_actions_t`，按级表达推进、保持和清空，消除旧的分散 `hold/flush/bubble` 组合。
- 重构 IF 请求、响应与单项缓冲；重定向可以杀死在途错误路径响应，并保留后压下的有效指令。
- 将 load 请求发射与返回解耦：MEM 只负责请求，WB 等待响应并在返回后提交，流水线仅在真实内存等待时停顿。
- 按功能拆分核心模块中的组合逻辑和时序逻辑，保留并补充关键中文注释。
- 统一测试时序、具名指令编码和 PASS 判定，新增 IF、MEM、WB、流水线控制、存储握手、cache wait 与 load 流水验证。
- 新增仓库内 `AGENTS.md` 和 `MEMORY_HANDSHAKE.md`，固化代码分块、注释保护和回归规则。

### 验证

- `make lint XLEN=32`、`make lint XLEN=64` 通过。
- `make unit XLEN=32`、`make unit XLEN=64` 各 17 项全部通过。
- `make directed XLEN=32` 通过：cache wait 11 周期、load pipeline 18 周期、RV32I 32 周期。
- A1 仍是 RV32I 阶段，RV64 整核测试在 A2 功能合入后执行。

## 2026-09-10（Asia/Shanghai）— A1/A2 合入 A3

### 合并原则

- 以已审核 A1 的注释、功能分块、IF/MEM ready-valid 握手和 `pipeline_actions_t` 为基线，人工移植 A2/A3 功能。
- 保留 `riscv_unpriv_pkg` 与 `riscv_priv_pkg` 分层，不恢复旧 `riscv_isa_pkg`。
- A3 已包含 A2 历史，因此只将 A1 固化提交合入 A3，避免重复合并 A2。

### 关键修改

- 加入 RV64I 的 LD、SD、LWU、XLEN 位移和 W 类算术/移位，W 类结果统一符号扩展。
- 为 RV64 编码补充带上下文的 funct3/funct6 常量及 `enc_ld`、`enc_addiw`、`enc_addw` 等具名测试编码。
- 接入直接映射 BTB、非推测 GShare 和预测更新仲裁；只有流水级真正推进时才训练预测器。
- JAL/JALR 只更新 BTB，不进入 GHR；条件分支使用取指时保存的 PHT 索引训练。
- BTB miss 输出确定的空目标/类型，避免无效表项数据传播；同索引不同标签按直接映射规则替换。
- 预测器 RTL 按查表、训练计算和时序写入分块，并保留、补充必要中文注释。

### 验证

- `make lint XLEN=32`、`make lint XLEN=64` 通过。
- `make unit XLEN=32`、`make unit XLEN=64` 各 21 项全部通过。
- 两种位宽的 cache wait 均为 11 周期，load pipeline 均为 18 周期。
- 两种位宽的预测整核测试均执行 21 次分支、产生 7 次重定向。
- RV32I 整核测试 32 周期通过；RV64I 整核测试 28 周期通过，非适用位宽均明确报告 SKIP。
