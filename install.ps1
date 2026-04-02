# ----------------------------------------------------------
# Xilinx Skill Installer (Windows PowerShell)
# Detects Claude Code / Codex / OpenClaw and installs accordingly
# ----------------------------------------------------------
$ErrorActionPreference = "Stop"

$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillName = "xilinx-suite"
$Installed = 0

function Copy-Skill {
    param([string]$TargetDir, [string]$ToolName)
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    Copy-Item "$RepoDir\SKILL.md" -Destination $TargetDir -Force
    Copy-Item "$RepoDir\references" -Destination $TargetDir -Recurse -Force
    Write-Host "  [OK] $ToolName  ->  $TargetDir" -ForegroundColor Green
    $script:Installed++
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Xilinx Skill Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# --- Claude Code ---
$ClaudeDir = Join-Path $env:USERPROFILE ".claude\skills\$SkillName"
Write-Host "[1/3] Claude Code" -ForegroundColor Yellow
if ((Get-Command claude -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $env:USERPROFILE ".claude"))) {
    Copy-Skill -TargetDir $ClaudeDir -ToolName "Claude Code"
} else {
    Write-Host "  [SKIP] Claude Code not detected" -ForegroundColor Gray
}

# --- Codex CLI ---
$CodexDir = Join-Path $env:USERPROFILE ".agents\skills\$SkillName"
Write-Host "[2/3] Codex CLI" -ForegroundColor Yellow
if ((Get-Command codex -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $env:USERPROFILE ".codex"))) {
    Copy-Skill -TargetDir $CodexDir -ToolName "Codex CLI"
    $CodexHome = Join-Path $env:USERPROFILE ".codex"
    New-Item -ItemType Directory -Force -Path $CodexHome | Out-Null
    Copy-Item "$RepoDir\AGENTS.md" -Destination $CodexHome -Force
    Write-Host "  [OK] AGENTS.md  ->  $CodexHome\AGENTS.md" -ForegroundColor Green
} else {
    Write-Host "  [SKIP] Codex CLI not detected" -ForegroundColor Gray
}

# --- OpenClaw ---
$OpenClawDir = Join-Path $env:USERPROFILE ".openclaw\skills\$SkillName"
Write-Host "[3/3] OpenClaw" -ForegroundColor Yellow
if ((Get-Command openclaw -ErrorAction SilentlyContinue) -or (Get-Command claw -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $env:USERPROFILE ".openclaw"))) {
    Copy-Skill -TargetDir $OpenClawDir -ToolName "OpenClaw"
} else {
    Write-Host "  [SKIP] OpenClaw not detected" -ForegroundColor Gray
}

Write-Host ""
if ($Installed -gt 0) {
    Write-Host "Done! Installed for $Installed tool(s)." -ForegroundColor Green
    Write-Host "Restart your coding assistant to activate the skill."
} else {
    Write-Host "No supported tools detected. You can install manually:"
    Write-Host ""
    Write-Host "  Claude Code:  Copy to ~\.claude\skills\$SkillName\"
    Write-Host "  Codex CLI:    Copy to ~\.agents\skills\$SkillName\"
    Write-Host "  OpenClaw:     Copy to ~\.openclaw\skills\$SkillName\"
}
Write-Host ""
