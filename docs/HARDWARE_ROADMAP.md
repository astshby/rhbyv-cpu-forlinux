# 硬件目标与阶段规划

## 总体目标

项目目标是构建一个使用 SystemVerilog 强类型 RTL 的单发射、顺序执行 RISC-V
Core。当前基线为六级流水，RV32/RV64 在构建时选择：

```text
IF → D1 → D2 → EX → MEM → WB
```

架构应能沿着 `RV32I/RV64I + Zicsr → M → C → F 或更深流水` 演进。Core 与
具体 FPGA BRAM、UART 和板级 IO 解耦，Verilator 与 FPGA wrapper 共享同一套
ready-valid 存储器协议。

## 当前 A4 架构

- IF 查询一套 BTB + 非推测 GShare，并随指令保存预测 metadata。
- D1 完成译码、立即数、非法/SYSTEM 分类、早期异常和 JAL 解析。
- D2 读取双端口 GPR，并准备执行操作数。
- EX 统一处理 GPR/CSR 前递、ALU、分支、JALR、CSR 读改写和动态异常。
- MEM 发射一次 Load/Store 请求；未 ready 时保持流水。
- WB 接收 Load 响应，作为 GPR/CSR、计数器和 Trap 的架构提交点。
- 同步异常在发现时清除年轻指令，携带 metadata 到 WB 后精确提交。
- JAL 只训练 BTB；JALR 训练 BTB；条件分支训练 BTB、PHT 和 GHR。

当前支持 RV32I/RV64I、六种 Zicsr、ECALL、EBREAK、MRET、机器模式同步异常、
`mstatus/misa/mtvec/mscratch/mepc/mcause/mtval/mcycle/minstret`。FENCE 在当前
单核无 Cache 平台中按无副作用指令处理；FENCE.I 尚无真实 I/D 同步结构。

## SystemVerilog 规则

- 使用 `logic`，不用混杂的 `wire/reg` 风格。
- 组合逻辑使用 `always_comb`、blocking `=`，并先给默认值以避免 latch。
- 时序逻辑使用 `always_ff`、nonblocking `<=`；同一寄存器只由一个时序块驱动。
- 使用 `package/import`、`localparam`、`typedef enum logic` 和显式类型转换。
- 流水边界、重定向和前递使用 `typedef struct packed`，避免大量散乱控制线。
- `_t` 表示类型，`_e` 表示枚举，`_q` 表示寄存器当前状态，`_d` 表示下一状态。
- 空流水槽使用 `valid=0`；所有存储器、GPR、CSR 和预测更新副作用都受 valid/commit 门控。
- XLEN 数据使用 `xlen_t`，禁止硬编码 32 位零扩展或固定四字节写掩码。
- 可综合 RTL 不放 `timescale`；TB 使用 `timeunit 1ns/timeprecision 1ps`。
- reset 优先清除 valid、FSM 和必要架构状态，不依赖无效 packet 的 payload 值。

## 模块职责约束

| 模块 | 稳定职责 |
|---|---|
| `if_stage` | PC、取指握手、响应缓冲、预测 next PC、redirect/kill |
| `predictor` | BTB/GShare 查询与训练，不决定架构正确性 |
| `d1_stage` | 译码组织、JAL 控制和 D1 异常序列化请求 |
| `d1_exception_check` | 指令地址、非法指令、ECALL/EBREAK、JAL 目标检查 |
| `d2_stage` | GPR 读取结果与 uOp 打包 |
| `gpr_bypass`/`csr_bypass` | `MEM > WB > committed/original` 数据选择 |
| `ex_stage` | ALU/BRU/CSR 执行、分支验证和 EX 输出打包 |
| `ex_exception_check` | 继承异常、CSR 权限、访存与控制目标对齐检查 |
| `mem_stage` | 请求侧握手和 MEM 前递，不等待 Load 返回 |
| `wb_stage` | 响应侧握手、写回数据和真实 commit 许可 |
| `trap_controller` | 由最老 commit 产生 Trap/MRET 状态与重定向 |
| `hazard_unit` | 判断数据尚不可用的 load-use 依赖 |
| `pipeline_ctrl` | 按指令年龄仲裁 HOLD/CLEAR/ADVANCE 和 redirect |
| `serialize_controller` | 异常/MRET 从发现到 WB 重定向期间停止年轻取指 |
| `core` | 模块连接和级间寄存器，不吸收功能单元实现 |

## 阶段 A

| 阶段 | 内容 | 当前状态 |
|---|---|---|
| A0 | 目录、Package、双 XLEN 构建和空顶层 | 已完成 |
| A1 | 六级 RV32I、前递、冒险、JAL/Branch/JALR | 已完成 |
| A2 | RV64I、W 操作、LD/SD/LWU、64 位总线 | 已完成 |
| A3 | BTB、GShare、预测 metadata 和更新仲裁 | 已完成 |
| A4 | 完整 Zicsr、M-mode 同步异常、MRET、riscv-tests | 已完成并回归 |
| A5 | CoreMark v1.0 仿真、BSP、计时和长程序验证 | 未开始 |
| A6 | Zynq-7020 BRAM、UART、XDC、综合、实现和上板 | 未开始 |

### A5：CoreMark 仿真

CoreMark 可以在没有 M 扩展时运行，但必须使用 `-march=rv32i_zicsr` 或
`rv64i_zicsr`，乘除由软件 helper 完成。需要新增：

- `benchmark/coremark/` 中固定版本的 CoreMark v1.0 源码；
- `benchmark/bsp/crt0.S`、链接脚本、栈、`.data/.bss` 初始化；
- CoreMark `core_portme.c/.h` 和裸机输出接口；
- 基于 `mcycle` 的 `start_time/stop_time/get_time`；
- RV32 软件乘除 helper，或能提供对应 multilib 且与当前 `-march` 匹配的 `libgcc`；
- `tohost`/仿真输出、PASS/FAIL 与超时机制；
- ELF、IMem/DMem 镜像和 `make coremark XLEN=...` 流程；
- 检查程序、数据、堆栈是否超过当前 16 KiB IMem、RV32 16 KiB/RV64 32 KiB DMem。

RV32 当前只有低 XLEN 的 `mcycle`，长时间计时需要限制迭代数、软件处理回绕，
或以后实现高半计数器。本机工具链目前只报告默认 multilib，A5 不能假定 RV32
`libgcc` helper 已经存在。A5 的成绩主要验证 C 工具链、长程序、栈、存储器和计时
稳定性；加入 M 扩展后必须重新测量性能。

### A6：FPGA

- 为固定一拍或可等待 BRAM 建立协议适配器。
- 加入 Instruction/Data BRAM 和 Clock Wizard 配置。
- 建立 PL 侧 UART TX、状态 MMIO 和地址映射。
- 完成 Zynq-7020 XDC、时钟约束和复位同步。
- Tcl 必须能够重建工程、综合、实现、生成 bitstream 和导出报告。
- 上板运行 ISA smoke 与 CoreMark，记录 utilization 和 timing。

## 阶段 B：M 扩展

实现 RV32M/RV64M，包括 MUL/MULH/MULHSU/MULHU、DIV/DIVU、REM/REMU 和 RV64
W 形式。正式启用 `FU_MULDIV`，为多周期除法建立 req/busy/done/result 接口，
由 `pipeline_ctrl` 处理 EX busy。必须验证除零、带符号溢出、全部 M riscv-tests、
A 阶段回归、CoreMark 变化和 FPGA DSP/LUT/时序。

## 阶段 C：C 扩展

Frontend 增加 16/32 位长度检测、半字对齐缓冲、跨 word 拼接和 decompressor，
随后向 D1 提供 canonical 32 位指令。packet 保留 `seq_pc` 并增加压缩指令长度信息；
BTB/PHT 索引纳入 PC[1]，IALIGN 从 32 改为 16。必须分别处理 RV32C/RV64C 编码，
完成 C 测试、压缩 CoreMark 和 FPGA 回归。

## 后续扩展

- F：增加浮点寄存器、FPU、浮点 load/store、转换和 `fflags/frm/fcsr`。
- 深流水：可拆为 IF1/IF2、EX1/EX2 或 MEM1/MEM2；继续让预测与异常 metadata 随指令传播。
- Cache：在现有 ready-valid 边界外实现 I/D Cache；miss 通过 ready/valid 反压，不侵入 Core ISA 逻辑。
- 操作系统硬件基础：机器定时器、`mie/mip`、软件/外部中断和 UART。Linux 还需要
  S/U 特权级、SBI、原子扩展、MMU/TLB、页表 CSR 与平台中断控制器。

## 阶段验收

任何扩展都必须同时满足：新模块测试通过、RV32/RV64 旧回归不退化、适用的
riscv-tests 通过、CoreMark 通过，并在涉及 FPGA 后提供综合、实现和时序报告。
预测状态只允许影响性能，不得影响 ISA 正确性；architectural side effect 必须在
明确 commit 点发生。
