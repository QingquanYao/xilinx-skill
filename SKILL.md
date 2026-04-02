---
name: xilinx-suite
description: >
  Xilinx 全工具链综合助手，覆盖从零到一的完整 FPGA/MPSoC 工程构建，包括：
  - Vivado：硬件设计、Block Design、IP 配置、XDC 约束、综合实现、比特流生成
  - Vitis HLS：C/C++ 高层次综合，生成自定义 IP 核
  - Vitis Unified IDE（2022.x+）：嵌入式软件开发，Platform/Domain/Application 创建，XSCT 脚本
  - PetaLinux：嵌入式 Linux 系统构建，BSP 配置，内核/rootfs 定制，启动镜像生成
  - 器件支持：Zynq UltraScale+ MPSoC（ZU15EG、ZU19EG、ZCU104 等）、Versal、纯 FPGA（VU9P、KU、7系列）
  只要用户提到以下任何内容，请立即使用本 skill：
  vivado、vitis、hls、高层次综合、vitis_hls、petalinux、zynq、ultrascale、fpga、mpsoc、xsa、比特流、
  block design、综合、实现、xdc、约束、IP核、AXI、嵌入式软件、裸机程序、linux镜像、bsp、设备树、
  jesd204、jesd204b、jesd204c、204b升级204c、204b迁移、高速串行、DAC、ADC、AD9144、AD9250、AD9680
  请在用户描述任何 Xilinx/AMD FPGA 硬件或软件设计任务时主动使用本 skill。
---

# Xilinx 全工具链 Skill

本 skill 帮助你完成 Xilinx（AMD）完整设计流程，生成可直接运行的脚本和文件。

---

## 第一步：判断工具和流程

**收到任何 Xilinx 相关请求时，首先确定用户处于哪个阶段，然后加载对应参考文件。**

### 完整设计流程总览

```
[可选] Vitis HLS        →    Vivado          →    Vitis Unified / PetaLinux
C/C++ 算法 → IP 核        硬件平台设计           软件开发 / Linux 系统
  hls_guide.md              vivado_guide.md      vitis_unified_guide.md
                          + mpsoc_ps_config.md    petalinux_guide.md
                          + xdc_constraints.md
```

### 工具路由表

| 用户描述的任务 | 需要的工具 | 加载的参考文件 |
|--------------|-----------|--------------|
| C/C++ 算法加速、pragma 优化、生成 IP | Vitis HLS | `references/hls_guide.md` |
| 创建工程、Block Design、配置 PS/IP、XDC、比特流 | Vivado | `references/vivado_guide.md` + 按需加载 |
| PS 详细配置（DDR、MIO、时钟）| Vivado | `references/mpsoc_ps_config.md` |
| IO 引脚约束、时序约束 | Vivado | `references/xdc_constraints.md` |
| JESD204B→C 迁移、高速串行 ADC/DAC 接口 | Vivado | `references/jesd204b_to_c_migration.md` |
| 嵌入式软件、裸机程序、RTOS、platform/domain | Vitis Unified | `references/vitis_unified_guide.md` |
| 嵌入式 Linux、kernel 配置、rootfs、启动镜像 | PetaLinux | `references/petalinux_guide.md` |

---

## 第二步：需求确认（必须先做）

在生成任何脚本之前，确认以下信息（没有明确答案的项主动提问）：

### 所有工程必须确认
1. **目标器件/开发板**：完整 part number 或板型（如 `xczu19eg-ffvc1760-2-i`、ZCU104）
2. **Vivado/Vitis 版本**（如 2023.2、2024.1）
3. **设计目标**：这个工程要实现什么功能？

### HLS 工程额外确认
4. **算法描述**：C/C++ 函数的输入输出和功能
5. **性能目标**：目标时钟频率、延迟、吞吐量要求
6. **接口类型**：AXI4-Lite（控制）、AXI4-Stream（数据）、AXI4-Master（存储器访问）

### Vivado 工程额外确认（MPSoC 类）
4. **PS 配置**：DDR 类型和容量、MIO 外设（UART、Ethernet、USB、SD 等）
5. **PL IP 需求**：需要哪些 AXI IP，是否有自定义 HDL 模块
6. **时钟要求**：PL 时钟频率（pl0_ref_clk）

### Vitis 工程额外确认
4. **运行环境**：裸机（standalone）、FreeRTOS、还是 Linux 用户态
5. **处理器核**：A53、R5、MicroBlaze
6. **XSA 文件路径**：从 Vivado 导出的硬件描述文件

### PetaLinux 工程额外确认
4. **BSP 或 XSA**：是否有厂商 BSP？或者直接使用 Vivado 导出的 XSA？
5. **自定义需求**：是否需要添加驱动/应用程序/设备树覆盖

---

## 第三步：按工具流程执行

确认需求后，加载对应参考文件并按步骤生成脚本。

### 加载参考文件的时机

**始终在生成脚本之前先读取参考文件**，不要凭记忆生成 Tcl/XSCT/命令，因为不同 Vivado/Vitis 版本的 API 有差异。

```
Vivado 工程  → 先读 references/vivado_guide.md
              → 如有 PS  → 再读 references/mpsoc_ps_config.md
              → 如有 IO  → 再读 references/xdc_constraints.md
              → 如有 JESD204 → 再读 references/jesd204b_to_c_migration.md

HLS 工程     → 先读 references/hls_guide.md

Vitis 工程   → 先读 references/vitis_unified_guide.md

PetaLinux    → 先读 references/petalinux_guide.md
```

---

## 输出规范

每次生成脚本时，必须提供：

1. **完整可运行的脚本文件**（`.tcl`、`.xdc`、`.py`、shell 脚本等）
2. **运行命令**：如何在命令行或 GUI 中执行
3. **预期输出**：脚本运行成功后会产生哪些文件
4. **下一步提示**：完成本阶段后应该做什么

### 文件组织规范

```
project_root/
├── 01_hls/                  ← Vitis HLS 工程（可选）
│   ├── hls_create.tcl
│   └── src/*.cpp / *.h
│
├── 02_vivado/               ← Vivado 硬件工程
│   ├── create_project.tcl
│   ├── create_bd.tcl
│   ├── add_sources.tcl
│   ├── constraints/design.xdc
│   ├── build.tcl
│   └── output/
│       ├── design.bit
│       └── design_fixed.xsa
│
├── 03_vitis/                ← Vitis 软件工程
│   ├── create_platform.tcl  (XSCT 脚本)
│   ├── create_app.tcl
│   └── src/*.c / *.h
│
└── 04_petalinux/            ← PetaLinux（可选）
    ├── build.sh
    └── config/
```

---

## 跨工具数据流

```
Vitis HLS                    Vivado                    Vitis / PetaLinux
─────────────────────────────────────────────────────────────────────────
hls_ip/                  →   IP Catalog
  solution/impl/ip       →   (add_files / ip_repo)
                             ↓
                         project.xsa         →        平台/BSP/Linux BSP
                         design.bit          →        boot/BOOT.BIN
```

---

## 常见错误和注意事项

1. **版本兼容性**：Vivado 2022.x+ 的 `write_hw_platform` 替代了旧版 `write_sysdef`；Vitis Unified 2022.x+ 的 Tcl API 与 Classic 版本有重大差异
2. **XSA 类型**：`write_hw_platform`（综合前，可编辑）vs `write_hw_platform -fixed -include_bit`（实现后，固定含比特流）
3. **HLS IP 导入 Vivado**：需要在 Vivado 工程中添加 HLS IP 仓库路径，并刷新 IP 目录
4. **PetaLinux 版本匹配**：PetaLinux 版本必须与 Vivado 版本一致（例如都用 2023.2）
5. **器件系列判断**：`zu` 开头 → MPSoC；`vu`/`ku`/`xc7` → 纯 FPGA；`xcvc` → Versal

---

## 参考文件

- `references/vivado_guide.md`：Vivado 工程创建、Block Design、综合实现、报告分析
- `references/mpsoc_ps_config.md`：Zynq UltraScale+ PS 详细配置（DDR、MIO、时钟参数）
- `references/xdc_constraints.md`：XDC 约束完整指南（时序、IO、例外约束）
- `references/hls_guide.md`：Vitis HLS 工程流程（C/C++ → IP）
- `references/vitis_unified_guide.md`：Vitis Unified IDE 2022.x+ 工程流程
- `references/petalinux_guide.md`：PetaLinux 系统构建流程
- `references/jesd204b_to_c_migration.md`：JESD204B→C IP 迁移指南（端口映射、数据位宽、AXI 寄存器、常见陷阱）
