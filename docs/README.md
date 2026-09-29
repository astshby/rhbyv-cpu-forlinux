# 文档入口与分支范围

本目录的接口说明以 `s5/cache-up` 的源码为参照。切换到较早分支时，先看该分支的 `vsrc/soc/soc_top.sv` 是否存在、实例化了什么，再把本文档当作后续设计的对照。文档齐全并不表示旧分支已经实现最新功能。

| 分支 | 此分支的代码重点 | 阅读时需要注意 |
|---|---|---|
| `main` | RV32/RV64 六级 Core 与 M 扩展 | 没有完整 SoC；从 Core I/D 端口起读 |
| `SOC/tmc-mmio` | ROM、TCM、MMIO、中断 | 没有 S3 DMA/AXI、S4/S5 Cache |
| `soc/s3-axi-dma` | 互连第三主端、DMA 与 AXI 单拍桥 | 没有缓存维护；外存仍需仿真模型 |
| `s4/cache` | 两路 I$ 和 WT/NWA D$ | 维护只有 S4 的全失效语义 |
| `s5/cache-up` | WB/WA D$、clean/flush/invalidate、FENCE.I 写回 | 本目录正式接口的当前参照 |
| `docs/soc-learning-map` | 文档整理 | 源码承接 S5 |

建议先读 [SoC 访存接口契约](SOC_BUS_CONTRACT.md)，再看 [外设连接与寄存器](SOC_PERIPHERALS.md) 中的连接图和从端下标。外存本地端口与 AXI 桥见 [外存边界](SOC_EXTERNAL_MEMORY.md)。要运行仿真与板级脚本，查 [仿真工作流](SIMULATION_AND_FPGA.md)；要找模块目录，查 [项目结构](PROJECT_STRUCTURE.md)。[硬件路线图](HARDWARE_ROADMAP.md) 记录后续目标，[平台适配](PLATFORM_ADAPTATION.md) 区分盘古与 Zynq。

rhbyv 是硬件开发仓库。本仓不存放阶段变更日志或学习解读；相应内容保存在 hgb-aisystem_riscv 的 docs/understand/ 和 docs/COMMIT.md。文档变更不更改已通过的 RTL 测试结果；涉及某个阶段的真实性，以切换后看到的源码和该分支日志为准。
