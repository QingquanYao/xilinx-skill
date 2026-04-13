# Xilinx/AMD 官方文档索引

> **用途：** 快速查找官方文档编号、用途和链接。生成脚本时应结合对应参考指南使用，本文件仅提供文档定位。
> **链接基础 URL：** `https://docs.amd.com/r/en-US/` + 文档编号（如 `ug892-vivado-design-flows-overview`）

---

## Vivado 设计工具

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **UG892** | Vivado Design Suite User Guide: Design Flows Overview | Vivado 整体设计流程总览，适合初次了解工具链 |
| **UG893** | Vivado Design Suite User Guide: Using the Vivado IDE | GUI 操作、项目模式 vs 非项目模式 |
| **UG894** | Vivado Design Suite User Guide: Using Tcl Scripting | Tcl 脚本编写、批处理模式、自定义命令 |
| **UG895** | Vivado Design Suite User Guide: System-Level Design Entry | RTL 设计输入、Schematic 查看、Elaboration |
| **UG896** | Vivado Design Suite User Guide: Designing with IP | IP Catalog 使用、IP 自定义、IP 仓库管理 |
| **UG897** | Vivado Design Suite User Guide: I/O and Clock Planning | IO 规划、Bank 分配、时钟资源规划 |
| **UG900** | Vivado Design Suite User Guide: Logic Simulation | 行为仿真、时序仿真、第三方仿真器集成 |
| **UG901** | Vivado Design Suite User Guide: Synthesis | 综合策略、综合属性、RTL 编码建议 |
| **UG903** | Vivado Design Suite User Guide: Using Constraints | XDC 约束语法、时序约束、IO 约束、例外约束 |
| **UG904** | Vivado Design Suite User Guide: Implementation | 布局布线策略、opt_design/place_design/route_design |
| **UG906** | Vivado Design Suite User Guide: Design Analysis and Closure Techniques | 时序分析、时序收敛、报告解读 |
| **UG908** | Vivado Design Suite User Guide: Programming and Debugging | 比特流下载、ILA/VIO 在线调试、hw_server 使用 |
| **UG909** | Vivado Design Suite User Guide: Partial Reconfiguration | 动态部分重配置设计流程 |
| **UG912** | Vivado Design Suite User Guide: IP Integrator | Block Design 创建、AXI 互联、自动化连接 |
| **UG945** | Vivado Design Suite Tutorial: Using Constraints | XDC 约束实战教程 |
| **UG949** | UltraFast Design Methodology Guide for FPGAs and SoCs | 最佳实践、设计方法学、时序收敛策略 |

---

## Vitis HLS（高层次综合）

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **UG1399** | Vitis HLS User Guide | HLS pragma、接口综合、数据流优化、C/RTL 协同仿真 |
| **UG1393** | Vitis Unified Software Platform Documentation: Application Acceleration Development | Vitis 加速流程（OpenCL/XRT 内核开发） |

---

## Vitis Unified / 嵌入式软件

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **UG1400** | Vitis Unified Software Platform Documentation | Vitis 2022.x+ 统一 IDE，Platform/Domain/Application 流程 |
| **UG1076** | Versal ACAP System Software Developers Guide | Versal 嵌入式软件开发（PLM、CDO、Boot 流程） |
| **UG1137** | Zynq UltraScale+ MPSoC Software Developer Guide | MPSoC 嵌入式软件（FSBL、ATF、U-Boot、Linux） |
| **UG1283** | Bootgen User Guide | BOOT.BIN 生成、安全启动、BIF 文件语法 |

---

## PetaLinux

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **UG1144** | PetaLinux Tools Documentation: Reference Guide | PetaLinux 完整流程（create → config → build → package） |
| **UG1157** | PetaLinux Tools Documentation: Command Line Reference | petalinux-* 命令详细参数说明 |

---

## 器件技术参考手册（TRM）

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **UG585** | Zynq-7000 SoC Technical Reference Manual | Zynq-7000 PS 架构、外设寄存器、MIO 映射 |
| **UG1085** | Zynq UltraScale+ MPSoC Technical Reference Manual | MPSoC PS 架构、RPU/APU、外设、安全模块 |
| **AM011** | Versal Adaptive SoC Technical Reference Manual | Versal 架构、PMC、NoC、AI Engine 接口 |

---

## 器件数据手册

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **DS190** | Zynq-7000 SoC Data Sheet: Overview | Zynq-7000 系列器件总览、封装、速度等级 |
| **DS891** | Zynq UltraScale+ MPSoC Data Sheet: Overview | MPSoC 系列器件总览、CG/EG/EV 子系列差异 |
| **DS890** | Zynq UltraScale+ MPSoC Data Sheet: DC and AC Switching Characteristics | MPSoC 电气参数、IO 标准、时序参数 |
| **DS892** | Zynq UltraScale+ RFSoC Data Sheet: Overview | RFSoC 系列总览（含 RF-ADC/RF-DAC） |
| **DS923** | UltraScale+ FPGA Product Selection Guide | UltraScale+ 纯 FPGA 系列选型 |

---

## IP 核产品指南（PG）

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **PG021** | AXI DMA v7.1 LogiCORE IP Product Guide | AXI DMA 配置、S2MM/MM2S 通道、Scatter-Gather |
| **PG059** | AXI Interconnect v2.1 LogiCORE IP Product Guide | AXI Interconnect 配置、多主多从拓扑 |
| **PG065** | AXI4-Stream FIFO v4.2 LogiCORE IP Product Guide | AXI-Stream FIFO 深度配置、背压机制 |
| **PG085** | AXI BRAM Controller v4.1 LogiCORE IP Product Guide | BRAM 控制器配置、ECC 选项 |
| **PG144** | AXI GPIO v2.0 LogiCORE IP Product Guide | GPIO 配置、双通道、中断支持 |
| **PG150** | UltraScale FPGAs Transceivers Wizard Product Guide | GTH/GTY 高速收发器配置向导 |
| **PG201** | Zynq UltraScale+ MPSoC Processing System LogiCORE IP Product Guide | PS IP 在 Block Design 中的配置参数 |
| **PG204** | JESD204B LogiCORE IP Product Guide | JESD204B IP 配置、Lane 映射、Link 参数 |
| **PG242** | JESD204C LogiCORE IP Product Guide | JESD204C IP 配置、64B/66B 编码、E 参数 |
| **PG269** | Clocking Wizard v6.0 LogiCORE IP Product Guide | 时钟管理（MMCM/PLL）配置向导 |

---

## AXI SmartConnect 与互联

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **PG247** | SmartConnect v1.0 LogiCORE IP Product Guide | AXI SmartConnect（替代 AXI Interconnect）配置 |

---

## 应用笔记（XAPP）

| 文档编号 | 标题 | 用途说明 |
|---------|------|---------|
| **XAPP1305** | Accelerating OpenCV Applications with Zynq UltraScale+ MPSoC | Yocto 流程参考、OpenCV 硬件加速 |
| **XAPP1319** | Designing with Zynq UltraScale+ MPSoC | MPSoC 设计最佳实践、PS-PL 数据通路选型 |

---

## 如何查找文档

1. **AMD 文档中心**：https://docs.amd.com — 搜索文档编号（如 UG912）即可找到最新版本
2. **版本匹配**：文档版本应与你的 Vivado/Vitis 版本匹配，AMD 文档中心可按版本筛选
3. **本仓库参考指南**：`references/` 目录下的指南已提炼了各文档中最常用的参数和命令，日常使用优先查阅参考指南

---

## 与本仓库参考指南的对应关系

| 参考指南 | 主要依据的官方文档 |
|---------|-----------------|
| `vivado_guide.md` | UG892, UG893, UG894, UG912, UG904 |
| `mpsoc_ps_config.md` | UG1085, PG201, DS891 |
| `mpsoc_bd_guide.md` | UG912, PG059, PG247 |
| `xdc_constraints.md` / `xdc_guide.md` | UG903, UG945 |
| `hls_guide.md` | UG1399 |
| `vitis_unified_guide.md` | UG1400, UG1137 |
| `petalinux_guide.md` | UG1144, UG1157 |
| `grpc_on_petalinux.md` | UG1144, UG1137, UG1085, PG021, PG144 |
| `jesd204b_to_c_migration.md` | PG204, PG242 |
| `vu9p_guide.md` | UG904, UG901, DS923 |
| `tcl_commands.md` | UG894, UG908 |
