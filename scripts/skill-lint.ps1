# skill-lint.ps1 — Lint all SKILL.md files for OpenClaw best-practice compliance.
# Windows PowerShell equivalent of skill-lint.sh
# Usage: .\scripts\skill-lint.ps1 [skills\specific-skill]

param([string]$Target = "")

$RepoRoot      = Split-Path $PSScriptRoot -Parent
if ($Target -eq "") { $Target = Join-Path $RepoRoot "skills" }
$Errors        = 0
$Warnings      = 0
$SkillsChecked = 0

function Write-Ok   { param($M) Write-Host "  ✓ $M" -ForegroundColor Green }
function Write-Warn { param($M) Write-Host "  ⚠ [WARN]  $M" -ForegroundColor Yellow; $script:Warnings++ }
function Write-Err  { param($M) Write-Host "  ✗ [ERROR] $M" -ForegroundColor Red;    $script:Errors++ }

function Invoke-LintSkill {
    param([string]$SkillDir)

    $SkillName = Split-Path $SkillDir -Leaf
    $SkillFile = Join-Path $SkillDir "SKILL.md"

    Write-Host ""
    Write-Host "━━━ $SkillName ━━━" -ForegroundColor Cyan
    $script:SkillsChecked++

    if (-not (Test-Path $SkillFile)) {
        Write-Err "SKILL.md not found in $SkillDir"
        return
    }

    # ── Extract frontmatter ──
    $Lines    = Get-Content $SkillFile -Encoding UTF8
    $InFM     = $false
    $PastFM   = $false
    $FMLines  = [System.Collections.Generic.List[string]]::new()
    $BodyLines = 0

    foreach ($L in $Lines) {
        if ($L.Trim() -eq "---") {
            if ($InFM)           { $InFM = $false; $PastFM = $true }
            elseif (-not $PastFM){ $InFM = $true }
            continue
        }
        if ($InFM)    { $FMLines.Add($L) }
        elseif ($PastFM) { $BodyLines++ }
    }
    $Frontmatter = $FMLines -join "`n"

    # ── 1. Frontmatter checks ──
    $FmName = ($FMLines | Where-Object { $_ -match '^name:' } | Select-Object -First 1) -replace '^name:\s*', '' -replace '\s',''
    if (-not $FmName) {
        Write-Err "Frontmatter missing 'name' field"
    } else {
        Write-Ok "name: $FmName"
        if ($FmName -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
            Write-Err "name '$FmName' is not kebab-case"
        }
        if ($FmName -ne $SkillName) {
            Write-Err "name '$FmName' does not match directory '$SkillName'"
        }
    }

    $FmDesc = ($FMLines | Where-Object { $_ -match '^description:' } | Select-Object -First 1) -replace '^description:\s*', ''
    if (-not $FmDesc) {
        Write-Err "Frontmatter missing 'description' field"
    } else {
        $DescWords = ($FmDesc -split '\s+' | Where-Object { $_ -ne '' }).Count
        if ($DescWords -gt 200) {
            Write-Warn "description is $DescWords words (recommended ≤ 200)"
        } else {
            Write-Ok "description: $DescWords words"
        }
    }

    # ── 2. Body length ──
    $TotalLines = $Lines.Count
    if ($TotalLines -gt 500) {
        Write-Warn "SKILL.md is $TotalLines lines (recommended ≤ 500)"
    } else {
        Write-Ok "body: $TotalLines lines"
    }

    # ── 3. Body anti-patterns ──
    $Content = Get-Content $SkillFile -Raw -Encoding UTF8
    if ($Content -match '(?im)^#+\s+(when to use|usage|use case)') {
        Write-Warn "'When to use' section found (should be in description)"
    }
    if ($Content -match '(?im)^#+\s+(installation|changelog|release notes)') {
        Write-Warn "README-style section found (installation/changelog)"
    }

    # ── 4. Directory structure ──
    if ($Content -match 'references/') {
        $RefDir = Join-Path $SkillDir "references"
        if (-not (Test-Path $RefDir)) {
            Write-Err "SKILL.md references 'references/' but directory does not exist"
        } elseif ((Get-ChildItem $RefDir -File -ErrorAction SilentlyContinue).Count -eq 0) {
            Write-Err "references/ directory is empty"
        } else {
            $RefCount = (Get-ChildItem $RefDir -File -Recurse).Count
            Write-Ok "references/: $RefCount file(s)"
        }
    }

    # ── 5. No hardcoded paths ──
    $HardcodedPatterns = @('/Users/[a-zA-Z]', '/home/[a-zA-Z]', 'C:\\Users\\', 'C:/Users/')
    foreach ($Pat in $HardcodedPatterns) {
        $Matches = Select-String -Path $SkillFile -Pattern $Pat -ErrorAction SilentlyContinue
        foreach ($M in $Matches) {
            Write-Err "Hardcoded path in SKILL.md: $($M.Line.Trim())"
        }
    }
}

# ── Main ──────────────────────────────────────────────
Write-Host "🔍 OpenClaw SKILL Lint"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if (Test-Path (Join-Path $Target "SKILL.md")) {
    Invoke-LintSkill $Target
} elseif (Test-Path -Path $Target -PathType Container) {
    Get-ChildItem -Path $Target -Directory | ForEach-Object { Invoke-LintSkill $_.FullName }
} else {
    Write-Error "Error: $Target is not a valid skill directory"
    exit 2
}

# ── Cross-reference checks ──────────────────────────────
Write-Host ""
Write-Host "━━━ Cross-Reference Checks ━━━" -ForegroundColor Cyan

$ValidCommands = @()
$CmdPaths = @(
    (Join-Path $RepoRoot "commands\*.md"),
    (Join-Path $RepoRoot "commands\maintainer\*.md")
)
foreach ($Pattern in $CmdPaths) {
    Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue | ForEach-Object {
        $NameLine = Select-String -Path $_.FullName -Pattern '^name:' | Select-Object -First 1
        if ($NameLine) {
            $ValidCommands += ($NameLine.Line -replace '^name:\s*', '').Trim().Trim('"')
        }
    }
}

$OldCommands = @("openclaw-status","diagnose-openclaw","evolve-openclaw-capability","collect-signals","evolve-openclaw-dev","sync-knowledge")
$SearchIn    = @(
    (Join-Path $RepoRoot "skills"),
    (Join-Path $RepoRoot "commands"),
    (Join-Path $RepoRoot "CLAUDE.md"),
    (Join-Path $RepoRoot "README.md")
)

foreach ($OldCmd in $OldCommands) {
    $Pattern = "(?:^|[\s\`])/$OldCmd(?:[\s\`\).]|$)"
    $Hits = @()
    foreach ($Loc in $SearchIn) {
        if (Test-Path $Loc) {
            $Found = Get-ChildItem -Path $Loc -Recurse -File -Include "*.md" -ErrorAction SilentlyContinue |
                     Where-Object { $_.FullName -notmatch 'docs.plans' } |
                     Select-String -Pattern $Pattern -ErrorAction SilentlyContinue
            $Hits += $Found | ForEach-Object { $_.Path }
        }
    }
    if ($Hits) {
        Write-Err ("Stale command reference '/$OldCmd' found in: " + ($Hits -join ', '))
    }
}
Write-Ok "Cross-reference check complete"

# ── Summary ──────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Skills checked: $SkillsChecked"
if ($Errors -gt 0) {
    Write-Host "Errors: $Errors  Warnings: $Warnings" -ForegroundColor Red
    Write-Host "❌ Lint failed" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Errors: $Errors  Warnings: $Warnings"
    Write-Host "✅ All skills passed" -ForegroundColor Green
    exit 0
}
