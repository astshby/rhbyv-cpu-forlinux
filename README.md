# rhbyv CPU

`rhbyv-cpu-forlinux` 是一个使用 SystemVerilog 编写的单发射、顺序执行 RISC-V
处理器项目，采用六级流水线：

```text
IF → D1 → D2 → EX → MEM → WB
```

构建时可选择 RV32 或 RV64，已实现整数基础指令、M 乘除扩展、六种 Zicsr 指令、
ECALL/EBREAK/MRET、机器模式精确同步异常，以及 BTB + 非推测 GShare。
Core 使用独立的指令和数据 ready/valid 接口，不直接实例化 FPGA BRAM。

## 功能与方向

现有 RV32IM/RV64IM Core 支持 GPR/CSR 前递、load-use 检测、访存反压和可选乘除
后端；M 运算结果在 EX/MEM 边界与指令元数据汇合。Verilator 测试覆盖单元、整核、
riscv-tests 和 CoreMark。当前没有完成 FPGA 上板或真实 Cache/TCM。

后续先面向盘古 676-200K Pro 设计可综合存储器、TCM/Cache、DMA 与系统互连，
再适配 Zynq-7020；平台无关 Core 保持独立。具体方案见文档。

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

- `vsrc/core/`：与平台无关的可综合 Core；`vsrc/pkg/` 保存共享类型和配置。
- `vsrc/sim_cpu/`：不可综合的仿真存储器和通用仿真顶层。
- `vsrc/cpu/`：FPGA wrapper 框架，后续适配两个平台。
- `tb/`：单元、整核和上游 riscv-tests 适配测试。
- `scripts/`：Verilator、工具链和 Vivado Tcl 工作流。
- `benchmark/`：裸机 BSP、C 冒烟程序、固定 CoreMark 源码和本地 port。

## 文档

- [项目目录说明](docs/PROJECT_STRUCTURE.md)
- [硬件目标与阶段规划](docs/HARDWARE_ROADMAP.md)
- [仿真与 FPGA 工作](docs/SIMULATION_AND_FPGA.md)
- [Cache、TCM、DMA 与总线设计草案](thinking.md)
- [双 FPGA 平台适配](docs/PLATFORM_ADAPTATION.md)
