# Contributing / 贡献指南

[English](#english) | [中文](#中文)

---

## English

Thanks for your interest in contributing! This skill is community-maintained and we welcome all kinds of contributions.

### How to Contribute

1. **Fork** this repository
2. **Create a branch** for your changes (`git checkout -b add-versal-guide`)
3. **Make your changes** following the guidelines below
4. **Submit a Pull Request**

### Adding a New Reference Document

Place your file in the `plugins/xilinx-suite/references/` directory. Follow the existing naming convention:

```
plugins/xilinx-suite/references/
├── <topic>_guide.md          # General guide
├── <device>_guide.md         # Device-specific guide
└── <feature>_migration.md    # Migration guide
```

**Reference doc requirements:**
- Use Markdown format
- Include Tcl/command examples that are copy-paste ready
- Specify which Vivado/Vitis versions the content applies to
- Organize with clear headers so the AI can locate specific sections

### Updating SKILL.md

If you add a new reference doc, also update `plugins/xilinx-suite/skills/xilinx-suite/SKILL.md`:
- Add the file to the routing table (the "Tool Routing Table" section)
- Add trigger keywords to the `description` frontmatter field
- Add it to the "Reference Files" section at the bottom

### Updating AGENTS.md

If you modify `SKILL.md`, keep `AGENTS.md` in sync -- it's the Codex CLI equivalent.

### Code Style

- Reference docs: Chinese or English are both fine
- File names: English, lowercase, underscores
- Tcl examples: Include comments explaining non-obvious parameters

---

## 中文

感谢你对本项目的关注！这是一个社区维护的 Skill，欢迎各种形式的贡献。

### 如何贡献

1. **Fork** 本仓库
2. **创建分支**（`git checkout -b add-versal-guide`）
3. **按照以下规范修改**
4. **提交 Pull Request**

### 添加新的参考文档

将文件放在 `plugins/xilinx-suite/references/` 目录下，遵循现有命名规范：

```
plugins/xilinx-suite/references/
├── <主题>_guide.md            # 通用指南
├── <器件>_guide.md            # 器件专用指南
└── <功能>_migration.md        # 迁移指南
```

**参考文档要求：**
- 使用 Markdown 格式
- 包含可直接复制粘贴的 Tcl/命令示例
- 标明适用的 Vivado/Vitis 版本
- 使用清晰的标题结构，便于 AI 定位特定内容

### 更新 SKILL.md

如果你添加了新的参考文档，同时更新 `plugins/xilinx-suite/skills/xilinx-suite/SKILL.md`：
- 将文件添加到工具路由表
- 将触发关键词添加到 `description` frontmatter 字段
- 添加到底部的"参考文件"章节

### 更新 AGENTS.md

如果修改了 `SKILL.md`，请同步更新 `AGENTS.md`（Codex CLI 的等效文件）。

### 代码规范

- 参考文档：中文或英文均可
- 文件名：英文、小写、下划线分隔
- Tcl 示例：对非显而易见的参数添加注释
