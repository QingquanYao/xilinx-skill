#!/usr/bin/env bash
# ----------------------------------------------------------
# Xilinx Skill Installer (Codex CLI / OpenClaw)
# For Claude Code, use: /plugin marketplace add QingquanYao/xilinx-skill
# ----------------------------------------------------------
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$REPO_DIR/plugins/xilinx-suite"
SKILL_NAME="xilinx-suite"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

installed=0

copy_skill() {
    local target_dir="$1"
    local tool_name="$2"
    mkdir -p "$target_dir"
    cp "$PLUGIN_DIR/skills/$SKILL_NAME/SKILL.md" "$target_dir/"
    cp -r "$PLUGIN_DIR/references" "$target_dir/"
    echo -e "  ${GREEN}[OK]${NC} $tool_name  ->  $target_dir"
    installed=$((installed + 1))
}

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Xilinx Skill Installer${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "  Claude Code users: use ${GREEN}/plugin marketplace add QingquanYao/xilinx-skill${NC} instead"
echo ""

# --- Codex CLI ---
CODEX_SKILL_DIR="$HOME/.agents/skills/$SKILL_NAME"
echo -e "${YELLOW}[1/2]${NC} Codex CLI"
if command -v codex &>/dev/null || [ -d "$HOME/.codex" ]; then
    copy_skill "$CODEX_SKILL_DIR" "Codex CLI"
    mkdir -p "$HOME/.codex"
    cp "$REPO_DIR/AGENTS.md" "$HOME/.codex/AGENTS.md"
    echo -e "  ${GREEN}[OK]${NC} AGENTS.md  ->  ~/.codex/AGENTS.md"
else
    echo "  [SKIP] Codex CLI not detected"
fi

# --- OpenClaw ---
OPENCLAW_SKILL_DIR="$HOME/.openclaw/skills/$SKILL_NAME"
echo -e "${YELLOW}[2/2]${NC} OpenClaw"
if command -v openclaw &>/dev/null || command -v claw &>/dev/null || [ -d "$HOME/.openclaw" ]; then
    copy_skill "$OPENCLAW_SKILL_DIR" "OpenClaw"
else
    echo "  [SKIP] OpenClaw not detected"
fi

echo ""
if [ $installed -gt 0 ]; then
    echo -e "${GREEN}Done! Installed for $installed tool(s).${NC}"
    echo "Restart your coding assistant to activate the skill."
else
    echo "No supported tools detected. You can install manually:"
    echo ""
    echo "  Codex CLI:    mkdir -p ~/.agents/skills/$SKILL_NAME && cp plugins/xilinx-suite/skills/$SKILL_NAME/SKILL.md ~/.agents/skills/$SKILL_NAME/ && cp -r plugins/xilinx-suite/references ~/.agents/skills/$SKILL_NAME/"
    echo "  OpenClaw:     mkdir -p ~/.openclaw/skills/$SKILL_NAME && cp plugins/xilinx-suite/skills/$SKILL_NAME/SKILL.md ~/.openclaw/skills/$SKILL_NAME/ && cp -r plugins/xilinx-suite/references ~/.openclaw/skills/$SKILL_NAME/"
fi
echo ""
