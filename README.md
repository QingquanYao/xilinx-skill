<p align="center">
  <a href="README_en.md">English</a> | <a href="README.md">中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Xilinx%20%7C%20AMD-E4002B?style=for-the-badge&logo=xilinx&logoColor=white" alt="Xilinx"/>
  <img src="https://img.shields.io/badge/Powered%20by-Claude%20Code-7C3AED?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License"/>
</p>
#让AI全流程自己调试FPGA真的爽翻了
# Xilinx 全工具链 Skill -- AI 编程助手插件

> **让 AI 处理繁琐的 Tcl 脚本，你只需专注架构设计。**

一个 AI 编程助手 Skill（支持 Claude Code / Codex / OpenClaw），用自然语言描述你的设计需求，即可生成可直接运行的 Vivado / Vitis HLS / Vitis Unified / PetaLinux 脚本。覆盖从 HLS 算法到启动镜像的完整 FPGA/MPSoC 设计流程。

---

## 推荐搭配的 MCP Server

本 Skill 搭配以下 MCP Server 使用效果最佳，可让 AI 直接控制 Xilinx 工具链和基础设施：

| MCP Server | 说明 |
|-----------|------|
| [vivado-mcp](https://github.com/QingquanYao/vivado-mcp) | AI 驱动的 Vivado 会话控制 -- 综合、时序报告、CRITICAL WARNING 自动诊断、烧写器件 |
| [vitis_mcp](https://github.com/QingquanYao/vitis_mcp) | AI 驱动的 Vitis 控制 -- 嵌入式软件全流程自动化 |
| [ssh-mcp](https://github.com/tufantunc/ssh-mcp) | 通过 SSH 连接虚拟机执行 PetaLinux 编译 -- 支持 sudo 和超时保护 |
| [vmware-mcp](https://github.com/ZacharyZcR/vmware-mcp) | VMware Workstation Pro 虚拟机控制 -- 管理 PetaLinux 构建环境 |

---

## 为什么需要这个 Skill？

| 痛点                     | 本 Skill 如何解决                                       |
| ---------------------- | -------------------------------------------------- |
| Vivado Tcl API 跨版本变化大  | 参考文档锁定版本特定 API，自动选择正确的命令                           |
| PS 配置参数多达 200+ 项       | 引导式问答 + 经过验证的 DDR/MIO/时钟 Tcl 模板                    |
| XDC 约束语法容易出错           | 从自然语言描述直接生成正确的 `set_property` / `create_clock`     |
| 跨工具交接流程复杂              | 自动化 HLS IP -> Vivado -> XSA -> Vitis/PetaLinux 数据流 |
| JESD204B -> 204C 迁移风险高 | 提供端口映射、寄存器差异的分步迁移指南                                |

---

## 支持的工具与器件

```
Vitis HLS ──> Vivado ──> Vitis Unified / PetaLinux
 C/C++ IP      硬件设计    裸机 / RTOS / Linux
```

**工具：** Vivado、Vitis HLS、Vitis Unified IDE (2022.x+)、PetaLinux

**器件：** Zynq UltraScale+ MPSoC（CG/EG/EV 全系，ZCU10x 评估板及自制板）、Virtex/Kintex UltraScale+/UltraScale、7 系列、Versal ACAP

---

## 安装

### Claude Code（推荐）

本仓库是一个 Claude Code 插件市场，一行命令即可安装：

```
/plugin marketplace add QingquanYao/xilinx-skill
```

然后安装插件：

```
/plugin install xilinx-suite
```

搞定，Skill 即刻可用。

### OpenAI Codex CLI

```bash
git clone https://github.com/QingquanYao/xilinx-skill.git
cd xilinx-skill && bash install.sh        # macOS/Linux
cd xilinx-skill; .\install.ps1            # Windows PowerShell
```

或手动安装：

```bash
mkdir -p ~/.agents/skills/xilinx-suite
cp plugins/xilinx-suite/skills/xilinx-suite/SKILL.md ~/.agents/skills/xilinx-suite/
cp -r plugins/xilinx-suite/references ~/.agents/skills/xilinx-suite/
cp AGENTS.md ~/.codex/AGENTS.md
```

### OpenClaw

```bash
git clone https://github.com/QingquanYao/xilinx-skill.git
cd xilinx-skill && bash install.sh        # macOS/Linux
cd xilinx-skill; .\install.ps1            # Windows PowerShell
```

或手动安装：

```bash
mkdir -p ~/.openclaw/skills/xilinx-suite
cp plugins/xilinx-suite/skills/xilinx-suite/SKILL.md ~/.openclaw/skills/xilinx-suite/
cp -r plugins/xilinx-suite/references ~/.openclaw/skills/xilinx-suite/
```

### 兼容性

| 工具 | 安装方式 | 格式 |
|------|---------|------|
| **Claude Code** | `/plugin marketplace add`（原生支持） | Plugin Marketplace |
| **OpenAI Codex** | `install.sh` / 手动复制 | `SKILL.md` + `AGENTS.md` |
| **OpenClaw** | `install.sh` / 手动复制 | `SKILL.md` |

> 三个工具都遵循 [Agent Skills](https://agentskills.io) 开放标准。

---

## 使用方法

用自然语言描述你的任务即可，例如：

```
> 为我的 ZynqMP 板卡创建 Vivado 工程，包含 Zynq PS、2 个 AXI GPIO 和 1 个 BRAM 控制器

> 为我的 Virtex UltraScale+ 板卡生成 200MHz 系统时钟的 XDC 约束，IO 标准为 LVDS

> 用我的 XSA 文件构建 PetaLinux 镜像，需要自定义设备树覆盖

> 将我的 JESD204B DAC 接口迁移到 JESD204C

> 创建一个矩阵乘法的 Vitis HLS IP，使用 AXI4-Stream 接口
```

Skill 会自动：

1. 询问必要信息（目标器件、版本、接口等）
2. 加载相关参考文档
3. 生成完整可运行的脚本
4. 告诉你如何执行以及下一步做什么

---

## 参考文档库

| 文件                           | 内容覆盖                                     |
| ---------------------------- | ---------------------------------------- |
| `vivado_guide.md`            | 工程创建、Block Design、综合、实现、报告分析             |
| `mpsoc_ps_config.md`         | Zynq UltraScale+ PS 配置 -- DDR4、MIO、时钟、中断 |
| `mpsoc_bd_guide.md`          | Block Design 自动化模式与最佳实践                  |
| `xdc_constraints.md`         | 时序约束、IO 标准、引脚分配                          |
| `xdc_guide.md`               | XDC 语法快速参考                               |
| `hls_guide.md`               | Vitis HLS C/C++ 到 IP 流程、pragma、优化        |
| `vitis_unified_guide.md`     | Vitis 2022.x+ 平台、域、应用创建                  |
| `petalinux_guide.md`         | BSP 配置、内核、rootfs、启动镜像生成                  |
| `jesd204b_to_c_migration.md` | JESD204B 到 204C IP 迁移 -- 端口、寄存器、常见陷阱     |
| `vu9p_guide.md`              | 纯 FPGA（无 PS）工程流程 -- UltraScale+/UltraScale/7 系列 |
| `tcl_commands.md`            | 常用 Vivado Tcl 命令参考                       |
| `official-docs/index.md`     | Xilinx/AMD 官方文档索引 -- UG/PG/DS/XAPP 编号、标题、用途，以及与本仓库参考指南的对应关系 |

---

## 生成的工程结构

Skill 会按阶段组织输出，结构清晰：

```
project_root/
├── 01_hls/                  # Vitis HLS（可选）
│   ├── hls_create.tcl
│   └── src/
├── 02_vivado/               # 硬件设计
│   ├── create_project.tcl
│   ├── create_bd.tcl
│   ├── constraints/*.xdc
│   ├── build.tcl
│   └── output/              # .bit + .xsa
├── 03_vitis/                # 嵌入式软件
│   ├── create_platform.tcl
│   └── src/
└── 04_petalinux/            # Linux（可选）
    ├── build.sh
    └── config/
```

---

## 贡献

本项目由社区共同维护，欢迎参与贡献！

**贡献方式：**
- 添加新 IP 核或器件系列的参考文档
- 补充版本特定的 API 细节
- 修正错误或补全 Tcl API 覆盖
- 翻译参考文档

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## 许可证

MIT

---

<p align="center">
  <sub>由 <a href="https://github.com/QingquanYao">@QingquanYao</a> 使用 Claude Code 构建</sub>
</p>
