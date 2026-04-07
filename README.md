<p align="center">
  <a href="README.md">English</a> | <a href="README_zh.md">中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Xilinx%20%7C%20AMD-E4002B?style=for-the-badge&logo=xilinx&logoColor=white" alt="Xilinx"/>
  <img src="https://img.shields.io/badge/Powered%20by-Claude%20Code-7C3AED?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License"/>
</p>

# Xilinx Full-Toolchain Skill for AI Coding Assistants

> **Let AI handle the tedious Tcl scripting. You focus on the architecture.**

An AI coding skill (Claude Code / Codex / OpenClaw) that turns natural language into production-ready Vivado / Vitis HLS / Vitis Unified / PetaLinux scripts. Describe what you want to build, and get runnable Tcl, XDC, shell scripts, and C/C++ templates -- covering the complete FPGA/MPSoC design flow from HLS algorithm to boot image.

---

## Recommended MCP Servers

This skill works best when paired with the following MCP servers, which give AI direct control over Xilinx tools and infrastructure:

| MCP Server | Description |
|-----------|-------------|
| [vivado-mcp](https://github.com/QingquanYao/vivado-mcp) | AI-driven Vivado session control -- synthesis, timing reports, CRITICAL WARNING diagnosis, device programming |
| [vitis_mcp](https://github.com/QingquanYao/vitis_mcp) | AI-driven Vitis control -- end-to-end embedded software automation |
| [ssh-mcp](https://github.com/tufantunc/ssh-mcp) | SSH into VMs to run PetaLinux builds -- supports sudo and timeout protection |
| [vmware-mcp](https://github.com/ZacharyZcR/vmware-mcp) | VMware Workstation Pro VM control -- manage PetaLinux build VMs |

---

## Why This Skill?

| Pain Point                             | How This Skill Helps                                                      |
| -------------------------------------- | ------------------------------------------------------------------------- |
| Vivado Tcl API changes across versions | Reference docs pin version-specific APIs; the skill picks the right one   |
| PS configuration is 200+ parameters    | Guided questionnaire + validated Tcl templates for DDR/MIO/clocks         |
| XDC constraint syntax is error-prone   | Generates correct `set_property` / `create_clock` from plain descriptions |
| Cross-tool handoff is confusing        | Automates HLS IP -> Vivado -> XSA -> Vitis/PetaLinux data flow            |
| JESD204B -> 204C migration is risky    | Step-by-step migration guide with port mapping and register diffs         |

---

## Supported Tools & Devices

```
Vitis HLS ──> Vivado ──> Vitis Unified / PetaLinux
 C/C++ IP      Hardware    Bare-metal / RTOS / Linux
```

**Tools:** Vivado, Vitis HLS, Vitis Unified IDE (2022.x+), PetaLinux

**Devices:** Zynq UltraScale+ MPSoC (CG/EG/EV, ZCU10x eval boards, custom boards), Virtex/Kintex UltraScale+/UltraScale, 7-Series, Versal ACAP

---

## Installation

### Claude Code (Recommended)

This repo is a Claude Code Plugin Marketplace. Install with one command:

```
/plugin marketplace add QingquanYao/xilinx-skill
```

Then install the plugin:

```
/plugin install xilinx-suite
```

That's it. The skill is ready to use.

### OpenAI Codex CLI

```bash
git clone https://github.com/QingquanYao/xilinx-skill.git
cd xilinx-skill && bash install.sh        # macOS/Linux
cd xilinx-skill; .\install.ps1            # Windows PowerShell
```

Or manually:

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

Or manually:

```bash
mkdir -p ~/.openclaw/skills/xilinx-suite
cp plugins/xilinx-suite/skills/xilinx-suite/SKILL.md ~/.openclaw/skills/xilinx-suite/
cp -r plugins/xilinx-suite/references ~/.openclaw/skills/xilinx-suite/
```

### Compatibility

| Tool | Install Method | Format |
|------|---------------|--------|
| **Claude Code** | `/plugin marketplace add` (native) | Plugin Marketplace |
| **OpenAI Codex** | `install.sh` / manual copy | `SKILL.md` + `AGENTS.md` |
| **OpenClaw** | `install.sh` / manual copy | `SKILL.md` |

> All three tools follow the [Agent Skills](https://agentskills.io) open standard.

---

## Usage

Just describe your task in natural language. Examples:

```
> Create a Vivado project for my ZynqMP board with Zynq PS, 2 AXI GPIO and 1 BRAM controller

> Generate XDC constraints for a 200MHz system clock on my Virtex UltraScale+ board with LVDS IO standard

> Build a PetaLinux image from my XSA with custom device tree overlay

> Migrate my JESD204B DAC interface to JESD204C

> Create a Vitis HLS IP for matrix multiplication with AXI4-Stream interface
```

The skill will:

1. Ask clarifying questions (target device, version, interfaces ...)
2. Load the relevant reference docs
3. Generate complete, runnable scripts
4. Tell you exactly how to execute them and what comes next

---

## Reference Library

| File                         | Coverage                                                           |
| ---------------------------- | ------------------------------------------------------------------ |
| `vivado_guide.md`            | Project creation, Block Design, synthesis, implementation, reports |
| `mpsoc_ps_config.md`         | Zynq UltraScale+ PS config -- DDR4, MIO, clocks, interrupts        |
| `mpsoc_bd_guide.md`          | Block Design automation patterns and best practices                |
| `xdc_constraints.md`         | Timing constraints, IO standards, pin assignments                  |
| `xdc_guide.md`               | XDC syntax quick reference                                         |
| `hls_guide.md`               | Vitis HLS C/C++ to IP flow, pragmas, optimization                  |
| `vitis_unified_guide.md`     | Vitis 2022.x+ platform, domain, application creation               |
| `petalinux_guide.md`         | BSP config, kernel, rootfs, boot image generation                  |
| `jesd204b_to_c_migration.md` | JESD204B to 204C IP migration -- ports, registers, pitfalls        |
| `vu9p_guide.md`              | Pure-FPGA (no-PS) design flow -- UltraScale+/UltraScale/7-Series   |
| `tcl_commands.md`            | Common Vivado Tcl command reference                                |

---

## Project Structure Generated

The skill organizes output into a clean, stage-separated layout:

```
project_root/
├── 01_hls/                  # Vitis HLS (optional)
│   ├── hls_create.tcl
│   └── src/
├── 02_vivado/               # Hardware design
│   ├── create_project.tcl
│   ├── create_bd.tcl
│   ├── constraints/*.xdc
│   ├── build.tcl
│   └── output/              # .bit + .xsa
├── 03_vitis/                # Embedded software
│   ├── create_platform.tcl
│   └── src/
└── 04_petalinux/            # Linux (optional)
    ├── build.sh
    └── config/
```

---

## Contributing

This is a community-maintained skill -- contributions are welcome and encouraged!

**Ways to contribute:**
- Add reference docs for new IP cores or device families
- Improve existing guides with version-specific details
- Fix errors or add missing Tcl API coverage
- Translate reference docs

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

MIT

---

<p align="center">
  <sub>Built with Claude Code by <a href="https://github.com/QingquanYao">@QingquanYao</a></sub>
</p>
