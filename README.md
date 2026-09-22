# rhbyv CPU

`rhbyv-cpu-forlinux` 是一个使用 SystemVerilog 编写的单发射、顺序执行 RISC-V
处理器项目，采用六级流水线：

```text
IF → D1 → D2 → EX → MEM → WB
```

构建时可选择 RV32 或 RV64，已实现整数基础指令、M 乘除扩展、六种 Zicsr 指令、
ECALL/EBREAK/MRET、机器模式精确同步异常，以及 BTB + 非推测 GShare。
Core 使用独立的指令和数据 ready/valid 接口，不直接实例化 FPGA BRAM。

## 当前状态

- RV32IM/RV64IM 六级流水、GPR/CSR 前递、load-use 检测和存储器反压。
- 单条在途多周期 MDU：统一握手与取消；三种乘法、两种除法可选，默认 DSP 推断乘法 + 移位除法（most easy）。
- JAL 在 D1 解析；条件分支与 JALR 在 EX 解析。
- CSR 在 EX 完成读改写与 WARL，WB 执行架构提交。
- Verilator 纯 SystemVerilog 测试，不使用 Cocotb。
- RV32/RV64 各 38 项单元测试，包含六种 MDU 组合与小位宽穷举；13 项整核定向流程中各 12 PASS、1 非适用位宽 SKIP。
- 适用的 riscv-tests：RV32 `58/58`，RV64 `78/78`，包括全部 8/13 项 UM；
  Zifencei 与未对齐直接完成用例明确 SKIP。
- CoreMark 1.0 performance/validation CRC 均通过；当前默认 MDU 配置的 RV32 为
  `2.471246 CoreMark/MHz`，RV64 为 `2.231733 CoreMark/MHz`。

当前完成的 M 扩展。下一步预计接入zynq7020与盘古676，同时添加uart等必要的rtl设计。
未来目标：异步中断、总线与总线挂载、Cache、C扩展、S-mode 与 MMU。
很可能干的事情：根据上板时序评估加深流水，修改重复信号。

## 快速验证

从仓库根目录运行：

```bash
make test XLEN=32
make test XLEN=64
make riscv-tests XLEN=32
make riscv-tests XLEN=64
make benchmark-smoke XLEN=32
make benchmark-smoke XLEN=64
make coremark XLEN=32
make coremark XLEN=64
make mdu-backends XLEN=32
make mdu-backends XLEN=64
```

`MUL_IMPL=0/1/2` 选择 DSP 、Booth-Wallace、移位乘法；`DIV_IMPL=0/1` 选择
移位除法、Radix-4 SRT。例如 `make test XLEN=64 MUL_IMPL=1 DIV_IMPL=1`。

RISC-V 工具链默认位于 `/opt/riscv/bin`。`make test` 包含 lint、单元测试和
整核定向测试，但不自动包含 `make riscv-tests`。生成物不跟踪。

## 目录入口

- `vsrc/core/`：与平台无关的可综合 Core。
- `vsrc/sim_cpu/`：不可综合的仿真存储器和通用仿真顶层。
- `vsrc/cpu/`：FPGA wrapper 框架，后续适配两个平台。
- `tb/`：单元、整核和上游 riscv-tests 适配测试。
- `scripts/`：Verilator、工具链和 Vivado Tcl 工作流。
- `benchmark/`：裸机 BSP、C 冒烟程序、固定 CoreMark 源码和本地 port。

## 文档

- [项目目录说明](docs/PROJECT_STRUCTURE.md)
- [硬件目标与阶段规划](docs/HARDWARE_ROADMAP.md)
- [仿真与 FPGA 工作](docs/SIMULATION_AND_FPGA.md)
- [双 FPGA 平台适配](docs/PLATFORM_ADAPTATION.md)
