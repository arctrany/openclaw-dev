# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# openclaw-dev — Uninstall OpenClaw development skills
# Windows PowerShell version (equivalent to uninstall.sh)
#
# Usage:
#   .\uninstall.ps1                          # Auto-detect and uninstall
#   .\uninstall.ps1 -Project C:\myproject    # From project (Gemini/Qwen)
#   .\uninstall.ps1 -Platforms claude,codex  # Specific platforms only
#   .\uninstall.ps1 -All -Project C:\myp     # All platforms
#   .\uninstall.ps1 -DryRun                  # Preview without executing
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[CmdletBinding()]
param(
    [string]$Project    = "",
    [string]$Platforms  = "",
    [switch]$All,
    [switch]$DryRun
)

$ScriptDir   = $PSScriptRoot
$HomeDir     = $env:USERPROFILE
$Removed     = 0
$Skipped     = 0
$IsDryRun    = $DryRun.IsPresent

$SkillDirs = @(
    "openclaw-dev-knowledgebase",
    "openclaw-skill-development",
    "openclaw-node-operations",
    "model-routing-governor"
)

# ── Color helpers ──────────────────────────────────────
function Write-Ok   { param($Msg) Write-Host "✅ $Msg" -ForegroundColor Green }
function Write-Warn { param($Msg) Write-Host "⚠️  $Msg" -ForegroundColor Yellow }
function Write-Err  { param($Msg) Write-Host "❌ $Msg" -ForegroundColor Red }
function Write-Info { param($Msg) Write-Host "ℹ  $Msg" -ForegroundColor Cyan }
function Write-Step { param($Msg) Write-Host "▸  $Msg" -ForegroundColor Cyan }
function Write-Dry  { param($Msg) Write-Host "[DRY-RUN] $Msg" -ForegroundColor Yellow }

# ── Remove a single installed item ────────────────────
function Remove-Installed {
    param([string]$Path, [string]$Label)

    if (Test-Path -Path $Path -PathType Leaf) {
        # It's a file (e.g., command .md)
        if ($IsDryRun) { Write-Dry "Remove-Item $Path" }
        else { Remove-Item $Path -Force; Write-Ok "$Label : 已移除" }
        $script:Removed++
    } elseif ((Test-Path -Path $Path -PathType Container) -and (Test-Path (Join-Path $Path "SKILL.md"))) {
        if ($IsDryRun) { Write-Dry "Remove-Item -Recurse $Path" }
        else { Remove-Item $Path -Recurse -Force; Write-Ok "$Label : 已移除 (directory)" }
        $script:Removed++
    } elseif (Test-Path $Path) {
        Write-Warn "$Label : 存在但无法识别为 openclaw 安装，跳过 ($Path)"
        $script:Skipped++
    } else {
        Write-Warn "$Label : 未安装"
        $script:Skipped++
    }
}

# ── Remove marker block from text file (HTML comment markers) ──
function Remove-MarkerBlock {
    param([string]$FilePath, [string]$Label)
    if (-not (Test-Path $FilePath)) { return }
    $Content = Get-Content $FilePath -Raw -Encoding UTF8
    if ($Content -notmatch "openclaw-dev") {
        Write-Warn "$Label : 无 openclaw-dev 引用"
        $script:Skipped++
        return
    }
    if ($IsDryRun) { Write-Dry "从 $FilePath 移除 openclaw-dev 段落"; $script:Removed++; return }
    # Remove block between <!-- openclaw-dev --> and <!-- /openclaw-dev -->
    $New = $Content -replace '(?s)<!-- openclaw-dev -->.*?<!-- /openclaw-dev -->\r?\n?', ''
    Set-Content -Path $FilePath -Value $New -Encoding UTF8
    Write-Ok "$Label : 已移除 openclaw-dev 引用"
    $script:Removed++
}

# ── Platform uninstallers ──────────────────────────────

function Uninstall-Claude {
    Write-Step "从 Claude Code 卸载"

    # Remove openclaw command files from global commands
    $CmdsDir  = Join-Path $HomeDir ".claude\commands"
    $Keywords = 'openclaw|diagnose|setup-node|lint-config|evolve-skill|create-skill|deploy-skill|validate-skill|list-skills|scaffold'
    $RemovedCmds = 0
    if (Test-Path $CmdsDir) {
        Get-ChildItem -Path $CmdsDir -Filter "*.md" | ForEach-Object {
            $Text = Get-Content $_.FullName -Raw
            if ($Text -match $Keywords) {
                if ($IsDryRun) { Write-Dry "Remove-Item $($_.FullName)" }
                else { Remove-Item $_.FullName -Force }
                $RemovedCmds++
            }
        }
    }
    if ($RemovedCmds -gt 0) {
        Write-Ok "Claude commands: $RemovedCmds 个文件已移除"
        $script:Removed++
    } else {
        Write-Warn "Claude commands: 未找到已安装的命令文件"
        $script:Skipped++
    }

    # Remove openclaw-dev section from global CLAUDE.md
    $ClaudeMd = Join-Path $HomeDir ".claude\CLAUDE.md"
    if ((Test-Path $ClaudeMd) -and ((Get-Content $ClaudeMd -Raw) -match 'openclaw-dev|OpenClaw Dev Skills')) {
        if ($IsDryRun) { Write-Dry "从 $ClaudeMd 移除 OpenClaw Dev Skills 段落" }
        else {
            $Lines   = Get-Content $ClaudeMd
            $Skip    = $false
            $Kept    = [System.Collections.Generic.List[string]]::new()
            foreach ($L in $Lines) {
                if ($L -match '^## OpenClaw Dev Skills') { $Skip = $true }
                if ($Skip -and ($L -match '^## ') -and ($L -notmatch '^## OpenClaw Dev Skills')) { $Skip = $false }
                if (-not $Skip) { $Kept.Add($L) }
            }
            Set-Content $ClaudeMd -Value $Kept -Encoding UTF8
            Write-Ok "~/.claude/CLAUDE.md: 已移除 OpenClaw Dev Skills 段落"
        }
        $script:Removed++
    }

    # Project-level CLAUDE.md
    if ($Project -ne "") {
        $ProjMd = Join-Path $Project "CLAUDE.md"
        Remove-MarkerBlock $ProjMd "Claude CLAUDE.md (project)"
    }
}

function Uninstall-Codex {
    Write-Step "从 Codex CLI 卸载"
    foreach ($Skill in $SkillDirs) {
        Remove-Installed (Join-Path $HomeDir ".codex\skills\$Skill") "Codex/$Skill"
    }
    Remove-MarkerBlock (Join-Path $HomeDir ".codex\instructions.md") "Codex instructions.md"
    if ($Project -ne "") {
        Remove-MarkerBlock (Join-Path $Project "AGENTS.MD") "Codex AGENTS.MD"
    }
}

function Uninstall-Gemini {
    if ($Project -eq "") { Write-Err "Gemini 需要 -Project <path> 参数"; return }
    Write-Step "从 Gemini Antigravity 卸载 ← $Project"
    foreach ($Skill in $SkillDirs) {
        Remove-Installed (Join-Path $Project ".agents\skills\$Skill") "Gemini/$Skill"
    }
}

function Uninstall-Qwen {
    if ($Project -eq "") { Write-Err "Qwen 需要 -Project <path> 参数"; return }
    Write-Step "从 Qwen Code 卸载 ← $Project"
    foreach ($Skill in $SkillDirs) {
        Remove-Installed (Join-Path $Project ".qwen\skills\$Skill") "Qwen/$Skill"
    }
}

# ── Detection ──────────────────────────────────────────
function Get-InstalledPlatforms {
    $Found = [System.Collections.Generic.List[string]]::new()

    # Claude
    $ClaudeCmds = Join-Path $HomeDir ".claude\commands"
    if (Test-Path $ClaudeCmds) {
        $Hit = Get-ChildItem $ClaudeCmds -Filter "*.md" -ErrorAction SilentlyContinue |
               Where-Object { (Get-Content $_.FullName -Raw) -match 'openclaw|diagnose|setup-node' }
        if ($Hit) { $Found.Add("claude") }
    }
    $ClaudeMd = Join-Path $HomeDir ".claude\CLAUDE.md"
    if ((Test-Path $ClaudeMd) -and ((Get-Content $ClaudeMd -Raw) -match 'OpenClaw Dev Skills') -and -not $Found.Contains("claude")) {
        $Found.Add("claude")
    }

    # Codex
    $CodexHit = $false
    foreach ($Skill in $SkillDirs) {
        if (Test-Path (Join-Path $HomeDir ".codex\skills\$Skill")) { $CodexHit = $true; break }
    }
    if ($CodexHit) { $Found.Add("codex") }

    if ($Project -ne "") {
        # Gemini
        foreach ($Skill in $SkillDirs) {
            if (Test-Path (Join-Path $Project ".agents\skills\$Skill")) { $Found.Add("gemini"); break }
        }
        # Qwen
        foreach ($Skill in $SkillDirs) {
            if (Test-Path (Join-Path $Project ".qwen\skills\$Skill")) { $Found.Add("qwen"); break }
        }
    }
    return $Found
}

# ── Main ───────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "🗑️  openclaw-dev 卸载" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

if ($IsDryRun) { Write-Warn "DRY-RUN 模式 — 只预览操作，不实际执行"; Write-Host "" }

# Resolve platform list
if ($Platforms -ne "") {
    $PlatformList = $Platforms -split ','
} elseif ($All) {
    $PlatformList = @("claude","codex","gemini","qwen")
} else {
    $PlatformList = @(Get-InstalledPlatforms)
    if ($PlatformList.Count -eq 0) {
        Write-Info "未检测到已安装的 openclaw-dev"
        exit 0
    }
    Write-Info "检测到已安装: $($PlatformList -join ', ')"
}
Write-Host ""

foreach ($Platform in $PlatformList) {
    switch ($Platform.Trim()) {
        "claude" { Uninstall-Claude }
        "codex"  { Uninstall-Codex  }
        "gemini" { Uninstall-Gemini }
        "qwen"   { Uninstall-Qwen   }
        default  { Write-Err "未知平台: $Platform" }
    }
    Write-Host ""
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "✅ $Removed 项已移除  ⏭️  $Skipped 项已跳过"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
