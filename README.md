<p align="center">
  <img src="https://img.shields.io/badge/Platform-Xilinx%20%7C%20AMD-E4002B?style=for-the-badge&logo=xilinx&logoColor=white" alt="Xilinx"/>
  <img src="https://img.shields.io/badge/Powered%20by-Claude%20Code-7C3AED?style=for-the-badge&logo=anthropic&logoColor=white" alt="Claude Code"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License"/>
</p>

# Xilinx Full-Toolchain Skill for Claude Code

> **Let AI handle the tedious Tcl scripting. You focus on the architecture.**

A Claude Code skill that turns natural language into production-ready Vivado / Vitis HLS / Vitis Unified / PetaLinux scripts. Describe what you want to build, and get runnable Tcl, XDC, shell scripts, and C/C++ templates -- covering the complete FPGA/MPSoC design flow from HLS algorithm to boot image.

---

## Why This Skill?

| Pain Point | How This Skill Helps |
|---|---|
| Vivado Tcl API changes across versions | Reference docs pin version-specific APIs; the skill picks the right one |
| PS configuration is 200+ parameters | Guided questionnaire + validated Tcl templates for DDR/MIO/clocks |
| XDC constraint syntax is error-prone | Generates correct `set_property` / `create_clock` from plain descriptions |
| Cross-tool handoff is confusing | Automates HLS IP -> Vivado -> XSA -> Vitis/PetaLinux data flow |
| JESD204B -> 204C migration is risky | Step-by-step migration guide with port mapping and register diffs |

---

## Supported Tools & Devices

```
Vitis HLS ──> Vivado ──> Vitis Unified / PetaLinux
 C/C++ IP      Hardware    Bare-metal / RTOS / Linux
```

**Tools:** Vivado, Vitis HLS, Vitis Unified IDE (2022.x+), PetaLinux

**Devices:** Zynq UltraScale+ MPSoC (ZU15EG, ZU19EG, ZCU104 ...), Virtex UltraScale+ (VU9P), Kintex UltraScale, 7-Series, Versal

---

## Quick Start

### 1. Install the Skill

Copy this repository into your Claude Code skills directory:

```bash
# Clone to your Claude Code skills location
git clone https://github.com/QingquanYao/xilinx-skill.git
```

Then add the skill path to your Claude Code configuration.

### 2. Start Designing

Just describe your task in natural language. Examples:

```
> Create a Vivado project for ZCU104 with Zynq PS, 2 AXI GPIO and 1 BRAM controller

> Generate XDC constraints for a 200MHz system clock on VU9P with LVDS IO standard

> Build a PetaLinux image from my XSA with custom device tree overlay

> Migrate my JESD204B DAC interface to JESD204C on ZU19EG

> Create a Vitis HLS IP for matrix multiplication with AXI4-Stream interface
```

The skill will:
1. Ask clarifying questions (target device, version, interfaces ...)
2. Load the relevant reference docs
3. Generate complete, runnable scripts
4. Tell you exactly how to execute them and what comes next

---

## Reference Library

| File | Coverage |
|------|----------|
| `vivado_guide.md` | Project creation, Block Design, synthesis, implementation, reports |
| `mpsoc_ps_config.md` | Zynq UltraScale+ PS config -- DDR4, MIO, clocks, interrupts |
| `mpsoc_bd_guide.md` | Block Design automation patterns and best practices |
| `xdc_constraints.md` | Timing constraints, IO standards, pin assignments |
| `xdc_guide.md` | XDC syntax quick reference |
| `hls_guide.md` | Vitis HLS C/C++ to IP flow, pragmas, optimization |
| `vitis_unified_guide.md` | Vitis 2022.x+ platform, domain, application creation |
| `petalinux_guide.md` | BSP config, kernel, rootfs, boot image generation |
| `jesd204b_to_c_migration.md` | JESD204B to 204C IP migration -- ports, registers, pitfalls |
| `vu9p_guide.md` | VU9P-specific design notes |
| `tcl_commands.md` | Common Vivado Tcl command reference |

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

## Works Great With

This skill is designed to work alongside the [Vivado MCP Server](https://github.com/QingquanYao/vivado-mcp), which provides live Vivado session control -- run synthesis, read timing reports, and program devices directly from Claude Code.

---

## Contributing

Issues and PRs are welcome. If you have reference docs for additional Xilinx IP cores or device families, feel free to contribute.

---

## License

MIT

---

<p align="center">
  <sub>Built with Claude Code by <a href="https://github.com/QingquanYao">@QingquanYao</a></sub>
</p>
