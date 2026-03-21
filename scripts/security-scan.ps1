# security-scan.ps1 — Scan repo for leaked secrets, personal paths, and privacy info.
# Windows PowerShell equivalent of security-scan.sh
# Usage: .\scripts\security-scan.ps1 [--strict]
# Exit 0 = clean, Exit 1 = violations found.

param([switch]$Strict)

$RepoRoot  = Split-Path $PSScriptRoot -Parent
$Violations = 0
$TotalFiles = 0

# ── Whitelist helper ─────────────────────────────────────
$PathWhitelist = @(
    'grep.*"/Volumes/', '不应在.*Volumes', '禁止.*Volumes', 'Volumes.*禁止',
    'Forbidden.*Volumes', '<disk-name>', 'echo.*Volumes', 'must not reference',
    'Forbidden.*Compliant', '`/Users/xxx', 'grep -nE', '/Users/\['
)
$PrivacyWhitelist = @(
    'example\.com', 'example\.org', 'your\.email', 'openclaw\.ai',
    'github\.com', 'localhost', '127\.0\.0\.1', '0\.0\.0\.0', '255\.255\.',
    '@example\.', 'x\.x\.x\.x', 'install\.sh', 'install\.ps1',
    'curl -fsSL', 'iwr -useb', '100\.64\.', '10\.0\.0\.', '192\.168\.',
    '169\.254\.', 'Forbidden.*Compliant', '\$GOOGLE_DRIVE'
)
$SecretWhitelist = @(
    'shared-secret', 'your[_-]', 'example', 'placeholder', 'changeme',
    'xxx', '<token>', '<key>', '<secret>', '<password>', '\.\.\.',
    'long-random', '[A-Z]+_TOKEN', 'EXAMPLE', 'NOT_A_REAL'
)

function Test-Whitelisted {
    param([string]$Line, [string[]]$Whitelist)
    foreach ($W in $Whitelist) {
        if ($Line -match $W) { return $true }
    }
    return $false
}

# ── Violation logger ──────────────────────────────────────
function Write-Violation {
    param([string]$Category, [string]$File, [int]$Line, [string]$Content)
    Write-Host "[VIOLATION] " -ForegroundColor Red -NoNewline
    Write-Host $Category -ForegroundColor Yellow
    Write-Host "  File: $File"
    Write-Host "  Line: $Line"
    Write-Host "  Content: $($Content.Trim())"
    Write-Host ""
    $script:Violations++
}

# ── Skip list ─────────────────────────────────────────────
function Test-ShouldSkip {
    param([string]$Path)
    if ($Path -match '\\.git\\') { return $true }
    if ($Path -match 'security-scan\.(sh|ps1)') { return $true }
    if ($Path -match '\.(png|jpg|jpeg|gif|ico|woff|woff2|ttf|eot)$') { return $true }
    if ($Path -match '\\\.claude\\|\\\.agents\\|\\\.codex\\|\\\.qwen\\') { return $true }
    if ($Path -match 'package-lock\.json|yarn\.lock') { return $true }
    return $false
}

# ── Patterns ──────────────────────────────────────────────
$PathPatterns = @(
    '/Users/[a-zA-Z]',        # macOS home
    '/home/[a-zA-Z]',         # Linux home
    'C:\\\\Users\\\\',          # Windows home (backslash)
    'C:/Users/',               # Windows home (forward slash)
    '/var/folders/',           # macOS temp
    '/Volumes/[a-zA-Z]'       # macOS external disk
)
$SecretPatterns = @(
    'API_KEY\s*[=:]\s*["\x27][^"<>]+["\x27]',
    'SECRET\s*[=:]\s*["\x27][^"<>]+["\x27]',
    'TOKEN\s*[=:]\s*["\x27][^"<>]+["\x27]',
    'PASSWORD\s*[=:]\s*["\x27][^"<>]+["\x27]',
    'sk-[a-zA-Z0-9]{20,}',
    'ghp_[a-zA-Z0-9]{36}',
    'ghs_[a-zA-Z0-9]{36}',
    'gho_[a-zA-Z0-9]{36}',
    'github_pat_[a-zA-Z0-9_]{22,}',
    'AKIA[0-9A-Z]{16}',
    'xoxb-[0-9]+-[0-9A-Za-z]+',
    'xoxp-[0-9]+-[0-9A-Za-z]+'
)
$PrivacyPatterns = @(
    '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    '\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b',
    'BEGIN .*(PRIVATE KEY|CERTIFICATE)'
)

# ── Load identity strings ─────────────────────────────────
$IdentityFile   = Join-Path $RepoRoot ".security-identities"
$IdentityStrings = @()
if (Test-Path $IdentityFile) {
    $IdentityStrings = Get-Content $IdentityFile | Where-Object { $_ -ne "" -and -not $_.StartsWith("#") }
}

# ── Collect files ─────────────────────────────────────────
Write-Host "🔍 OpenClaw Security Scan"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Repo: $RepoRoot"
Write-Host ""

# Use git tracked files if available, otherwise all files
$GitExe = Get-Command "git" -ErrorAction SilentlyContinue
$Files = @()
if ($GitExe) {
    try {
        $GitFiles = & git -C $RepoRoot ls-files --cached --others --exclude-standard 2>$null
        if ($LASTEXITCODE -eq 0 -and $GitFiles) {
            $Files = $GitFiles | ForEach-Object { Join-Path $RepoRoot $_ }
        }
    } catch {}
}
if ($Files.Count -eq 0) {
    $Files = Get-ChildItem -Path $RepoRoot -Recurse -File | Where-Object { $_.FullName -notmatch '\\.git\\' } | Select-Object -ExpandProperty FullName
}

foreach ($FilePath in $Files) {
    if (-not (Test-Path $FilePath -PathType Leaf)) { continue }
    if (Test-ShouldSkip $FilePath) { continue }

    # Skip non-text files
    $Ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
    $TextExts = @('.md','.txt','.sh','.ps1','.py','.js','.ts','.json','.yaml','.yml','.toml','.env','.gitignore','.example')
    if ($TextExts -notcontains $Ext -and $Ext -ne '') { continue }

    try { $FileContent = Get-Content $FilePath -Encoding UTF8 -ErrorAction Stop }
    catch { continue }

    $TotalFiles++
    $RelPath = $FilePath.Replace($RepoRoot + '\', '').Replace($RepoRoot + '/', '')
    $LineNum = 0

    foreach ($LineText in $FileContent) {
        $LineNum++

        # 1. Personal path check
        foreach ($Pat in $PathPatterns) {
            if ($LineText -match $Pat) {
                if (-not (Test-Whitelisted $LineText $PathWhitelist)) {
                    Write-Violation "PERSONAL_PATH" $RelPath $LineNum $LineText
                }
                break
            }
        }

        # 2. Secret check
        foreach ($Pat in $SecretPatterns) {
            if ($LineText -imatch $Pat) {
                if (-not (Test-Whitelisted $LineText $SecretWhitelist)) {
                    Write-Violation "SECRET_LEAK" $RelPath $LineNum $LineText
                }
                break
            }
        }

        # 3. Privacy check
        foreach ($Pat in $PrivacyPatterns) {
            if ($LineText -match $Pat) {
                if (-not (Test-Whitelisted $LineText $PrivacyWhitelist)) {
                    Write-Violation "PRIVACY_INFO" $RelPath $LineNum $LineText
                }
                break
            }
        }

        # 4. Identity check
        foreach ($Identity in $IdentityStrings) {
            if ($LineText -imatch [regex]::Escape($Identity)) {
                Write-Violation "IDENTITY_LEAK" $RelPath $LineNum $LineText
                break
            }
        }
    }
}

# ── Summary ───────────────────────────────────────────────
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Scanned: $TotalFiles files"

if ($Violations -gt 0) {
    Write-Host "❌ Found $Violations violation(s)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ No violations found" -ForegroundColor Green
    exit 0
}
