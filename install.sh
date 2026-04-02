#!/usr/bin/env bash
# ----------------------------------------------------------
# Xilinx Skill Installer
# Detects Claude Code / Codex / OpenClaw and installs accordingly
# ----------------------------------------------------------
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
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
    cp "$REPO_DIR/SKILL.md" "$target_dir/"
    cp -r "$REPO_DIR/references" "$target_dir/"
    echo -e "  ${GREEN}[OK]${NC} $tool_name  ->  $target_dir"
    installed=$((installed + 1))
}

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Xilinx Skill Installer${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# --- Claude Code ---
CLAUDE_SKILL_DIR="$HOME/.claude/skills/$SKILL_NAME"
echo -e "${YELLOW}[1/3]${NC} Claude Code"
if command -v claude &>/dev/null || [ -d "$HOME/.claude" ]; then
    copy_skill "$CLAUDE_SKILL_DIR" "Claude Code"
else
    echo "  [SKIP] Claude Code not detected (~/.claude not found)"
fi

# --- Codex CLI ---
CODEX_SKILL_DIR="$HOME/.agents/skills/$SKILL_NAME"
echo -e "${YELLOW}[2/3]${NC} Codex CLI"
if command -v codex &>/dev/null || [ -d "$HOME/.codex" ]; then
    copy_skill "$CODEX_SKILL_DIR" "Codex CLI"
    # Also copy AGENTS.md to ~/.codex/ for global instructions
    mkdir -p "$HOME/.codex"
    cp "$REPO_DIR/AGENTS.md" "$HOME/.codex/AGENTS.md"
    echo -e "  ${GREEN}[OK]${NC} AGENTS.md  ->  ~/.codex/AGENTS.md"
else
    echo "  [SKIP] Codex CLI not detected"
fi

# --- OpenClaw ---
OPENCLAW_SKILL_DIR="$HOME/.openclaw/skills/$SKILL_NAME"
echo -e "${YELLOW}[3/3]${NC} OpenClaw"
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
    echo "  Claude Code:  cp -r . ~/.claude/skills/$SKILL_NAME/"
    echo "  Codex CLI:    cp -r . ~/.agents/skills/$SKILL_NAME/"
    echo "  OpenClaw:     cp -r . ~/.openclaw/skills/$SKILL_NAME/"
fi
echo ""
