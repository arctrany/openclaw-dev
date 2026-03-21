# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# openclaw-dev — Install OpenClaw development skills to your code agents
# Windows PowerShell version (equivalent to install.sh)
#
# Install:
#   git clone https://github.com/arctrany/openclaw-dev.git
#   cd openclaw-dev && .\install.ps1
#
# Update:
#   cd openclaw-dev && git pull && .\install.ps1
#
# Per-project:
#   .\install.ps1 -Project C:\path\to\project
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[CmdletBinding()]
param(
    [string]$Project = ""
)

$ScriptDir   = $PSScriptRoot
$SkillsDir   = Join-Path $ScriptDir "skills"
$CommandsDir = Join-Path $ScriptDir "commands"
$HomeDir     = $env:USERPROFILE

# Read version from knowledgebase SKILL.md
$KbSkill = Join-Path $SkillsDir "openclaw-dev-knowledgebase\SKILL.md"
$Version = "unknown"
if (Test-Path $KbSkill) {
    $VersionLine = Select-String -Path $KbSkill -Pattern '^version:' | Select-Object -First 1
    if ($VersionLine) {
        $Version = ($VersionLine.Line -replace '^version:\s*', '').Trim()
    }
}

Write-Host ""
Write-Host "  ┌──────────────────────────────────────┐"
Write-Host "  │  🔧 openclaw-dev installer v$Version"
Write-Host "  │  Skills for OpenClaw development     │"
Write-Host "  └──────────────────────────────────────┘"
Write-Host ""

$Installed = 0

# ─────────────────────────────────────────
# Helper: copy skills to target dir
# ─────────────────────────────────────────
function Copy-Skills {
    param([string]$Target)
    if (-not (Test-Path $Target)) { New-Item -ItemType Directory -Path $Target -Force | Out-Null }
    Get-ChildItem -Path $SkillsDir -Directory | ForEach-Object {
        $Dest = Join-Path $Target $_.Name
        if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
        Copy-Item -Recurse -Path $_.FullName -Destination $Dest
    }
}

# Helper: copy commands to target dir
function Copy-Commands {
    param([string]$Target)
    if (-not (Test-Path $Target)) { New-Item -ItemType Directory -Path $Target -Force | Out-Null }
    Get-ChildItem -Path $CommandsDir -Filter "*.md" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $Target $_.Name) -Force
    }
}

# ─────────────────────────────────────────
# Claude Code
# ─────────────────────────────────────────
function Install-Claude {
    $ClaudeDir = Join-Path $HomeDir ".claude"
    if (-not (Test-Path $ClaudeDir)) {
        Write-Host "  ⏭  Claude Code — not detected"
        return
    }
    Write-Host "  📦 Claude Code"

    $CmdTarget = Join-Path $ClaudeDir "commands"
    Copy-Commands $CmdTarget
    $CmdCount = (Get-ChildItem -Path $CmdTarget -Filter "*.md" -ErrorAction SilentlyContinue).Count
    Write-Host "     ✅ $CmdCount commands → ~/.claude/commands/"

    # User-level CLAUDE.md — only add once
    $ClaudeMd = Join-Path $ClaudeDir "CLAUDE.md"
    $Marker   = "openclaw-dev"
    if ((Test-Path $ClaudeMd) -and ((Get-Content $ClaudeMd -Raw) -match $Marker)) {
        Write-Host "     ⏭  ~/.claude/CLAUDE.md already configured"
    } else {
        $Snippet = @"

## OpenClaw Dev Skills
For OpenClaw tasks, read the skill files in ~/.claude/commands/ (slash commands like /diagnose, /setup-node, /lint-config).
For deep knowledge, read the SKILL.md files in the openclaw-dev repo's skills/ directory.
"@
        Add-Content -Path $ClaudeMd -Value $Snippet -Encoding UTF8
        Write-Host "     ✅ ~/.claude/CLAUDE.md updated"
    }

    $script:Installed++
}

# ─────────────────────────────────────────
# Qwen
# ─────────────────────────────────────────
function Install-Qwen {
    $QwenDir = Join-Path $HomeDir ".qwen"
    if (-not (Test-Path $QwenDir)) {
        Write-Host "  ⏭  Qwen — not detected"
        return
    }
    Write-Host "  📦 Qwen"

    $SkillTarget = Join-Path $QwenDir "skills"
    Copy-Skills $SkillTarget
    $Count = (Get-ChildItem -Path $SkillsDir -Directory).Count
    Write-Host "     ✅ $Count skills → ~/.qwen/skills/"

    $Settings = Join-Path $QwenDir "settings.json"
    if (Test-Path $Settings) {
        $Json = Get-Content $Settings -Raw | ConvertFrom-Json
        if ($Json.experimental.skills -eq $true) {
            Write-Host "     ✅ experimental.skills enabled"
        } else {
            Write-Host "     ⚠️  Set experimental.skills=true in ~/.qwen/settings.json"
        }
    }

    $script:Installed++
}

# ─────────────────────────────────────────
# Codex (OpenAI)
# ─────────────────────────────────────────
function Install-Codex {
    $CodexDir = Join-Path $HomeDir ".codex"
    if (-not (Test-Path $CodexDir)) {
        Write-Host "  ⏭  Codex — not detected"
        return
    }
    Write-Host "  📦 Codex"

    $SkillTarget = Join-Path $CodexDir "skills"
    Copy-Skills $SkillTarget
    $Count = (Get-ChildItem -Path $SkillsDir -Directory).Count
    Write-Host "     ✅ $Count skills → ~/.codex/skills/"

    $CodexCmd = Get-Command "codex" -ErrorAction SilentlyContinue
    if ($CodexCmd) { Write-Host "     ✅ codex CLI: $($CodexCmd.Source)" }

    $script:Installed++
}

# ─────────────────────────────────────────
# Gemini (Antigravity) — per-project install
# ─────────────────────────────────────────
function Install-Gemini {
    $GeminiDir = Join-Path $HomeDir ".gemini"
    if (-not (Test-Path $GeminiDir)) {
        Write-Host "  ⏭  Gemini — not detected"
        return
    }
    Write-Host "  📦 Gemini (Antigravity)"

    $IsProject = (Test-Path ".git") -or (Test-Path "package.json") -or (Test-Path ".agents")
    if ($IsProject) {
        $SkillTarget = ".agents\skills"
        Copy-Skills $SkillTarget
        $Count = (Get-ChildItem -Path $SkillsDir -Directory).Count
        Write-Host "     ✅ $Count skills → .agents\skills\"
        $script:Installed++
    } else {
        Write-Host "     ℹ️  Gemini requires per-project install."
        Write-Host "        Run from your project root, or use:"
        Write-Host "        .\$ScriptDir\install.ps1 -Project C:\path\to\project"
    }
}

# ─────────────────────────────────────────
# Per-project install
# ─────────────────────────────────────────
function Install-Project {
    param([string]$ProjectPath)
    if (-not (Test-Path $ProjectPath)) {
        Write-Error "Not found: $ProjectPath"
        exit 1
    }
    Write-Host "  📦 Project: $ProjectPath"

    # Gemini
    Copy-Skills  (Join-Path $ProjectPath ".agents\skills")
    Copy-Commands (Join-Path $ProjectPath ".agents\workflows")
    Write-Host "     ✅ Gemini:  .agents\skills\ + .agents\workflows\"

    # Codex
    Copy-Skills (Join-Path $ProjectPath ".codex\skills")
    Write-Host "     ✅ Codex:   .codex\skills\"

    # Qwen
    Copy-Skills (Join-Path $ProjectPath ".qwen\skills")
    Write-Host "     ✅ Qwen:    .qwen\skills\"

    # Claude Code
    Copy-Commands (Join-Path $ProjectPath ".claude\commands")
    Write-Host "     ✅ Claude:  .claude\commands\"
}

# ─────────────────────────────────────────
# Main
# ─────────────────────────────────────────
if ($Project -ne "") {
    Install-Project $Project
} else {
    Install-Claude
    Install-Qwen
    Install-Codex
    Install-Gemini
}

Write-Host ""
Write-Host "  ── Done: $Installed platforms ──"
Write-Host ""
$RepoName = Split-Path $ScriptDir -Leaf
Write-Host "  Update: cd $RepoName && git pull && .\install.ps1"
Write-Host ""
