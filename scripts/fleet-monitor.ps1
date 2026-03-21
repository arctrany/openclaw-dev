# fleet-monitor.ps1 — Windows fleet monitoring panel
# Equivalent to fleet-tmux.sh but uses PowerShell Jobs + Windows Terminal (if available)
#
# Usage: .\scripts\fleet-monitor.ps1 -SessionName <name> -NodesJson '<json>'
#
# NodesJson format: '[{"name":"node-a","user":"your-user","host":"10.0.0.1","port":"22","key":""}]'
# Max 4 nodes.
#
# Attach with:  Get-Content -Wait "$env:TEMP\fleet-<session>-<node>.log"
# Stop with:    /watch stop  OR  Stop-Fleet <session>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SessionName,
    [Parameter(Mandatory)][string]$NodesJson
)

# ── Dependency check: jq ─────────────────────────────────
$HasJq  = $null -ne (Get-Command "jq" -ErrorAction SilentlyContinue)
$HasWt  = $null -ne (Get-Command "wt" -ErrorAction SilentlyContinue)   # Windows Terminal
$HasSsh = $null -ne (Get-Command "ssh" -ErrorAction SilentlyContinue)

if (-not $HasSsh) {
    Write-Error "ERROR: ssh is required. Install OpenSSH: Settings → Apps → Optional Features → OpenSSH Client"
    exit 1
}

# ── Parse nodes ──────────────────────────────────────────
if ($HasJq) {
    $Nodes = @()
    $Count = [int](jq length $NodesJson 2>$null)
    if ($Count -eq 0) { Write-Error "ERROR: No nodes provided."; exit 1 }
    if ($Count -gt 4) { Write-Warning "Max 4 panes supported. Using first 4 nodes only."; $Count = 4 }
    for ($i = 0; $i -lt $Count; $i++) {
        $Nodes += [PSCustomObject]@{
            Name = (jq -r ".[$i].name" $NodesJson 2>$null)
            User = (jq -r ".[$i].user" $NodesJson 2>$null)
            Host = (jq -r ".[$i].host" $NodesJson 2>$null)
            Port = (jq -r ".[$i].port // `"22`"" $NodesJson 2>$null)
            Key  = (jq -r ".[$i].key // `"`"" $NodesJson 2>$null)
        }
    }
} else {
    # Fallback: basic JSON parsing without jq
    Write-Warning "jq not found — using basic JSON parsing (install jq for full support)"
    try {
        $NodeList = ($NodesJson | ConvertFrom-Json)
        $Nodes    = @()
        $Count    = [Math]::Min($NodeList.Count, 4)
        for ($i = 0; $i -lt $Count; $i++) {
            $N = $NodeList[$i]
            $Nodes += [PSCustomObject]@{
                Name = $N.name
                User = $N.user
                Host = $N.host
                Port = if ($N.port) { $N.port } else { "22" }
                Key  = if ($N.key)  { $N.key  } else { "" }
            }
        }
    } catch {
        Write-Error "ERROR: Failed to parse NodesJson. Please install jq for reliable parsing."
        exit 1
    }
}

# ── Log file paths ───────────────────────────────────────
$TempDir  = $env:TEMP
$LogFiles = @{}
foreach ($Node in $Nodes) {
    $LogFile = Join-Path $TempDir "fleet-$SessionName-$($Node.Name).log"
    $LogFiles[$Node.Name] = $LogFile
}

# ── Session reattach check ───────────────────────────────
$LockFile = Join-Path $TempDir "fleet-$SessionName.lock"
if (Test-Path $LockFile) {
    $ExistingPid = Get-Content $LockFile -ErrorAction SilentlyContinue
    $Running = $ExistingPid -and (Get-Process -Id $ExistingPid -ErrorAction SilentlyContinue)
    if ($Running) {
        Write-Host "SESSION_EXISTS: Fleet session '$SessionName' is already running (PID $ExistingPid)."
        # Append reattach marker to all log files
        foreach ($Node in $Nodes) {
            $Log = $LogFiles[$Node.Name]
            if (Test-Path $Log) {
                Add-Content $Log ""
                Add-Content $Log "━━━ $(Get-Date -Format 'HH:mm:ss') Session reattached ━━━"
            }
        }
        Write-Host ""
        Write-Host "── Attach Instructions ──────────────────────────────"
        foreach ($Node in $Nodes) {
            Write-Host "  $($Node.Name):  Get-Content -Wait '$($LogFiles[$Node.Name])'"
        }
        Write-Host "  Stop:         .\scripts\fleet-monitor.ps1 -Stop -SessionName '$SessionName'"
        Write-Host "────────────────────────────────────────────────────"
        Write-Host "FLEET_SESSION_INFO:{`"session`":`"$SessionName`",`"reattached`":true}"
        exit 0
    }
    Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}

# ── Initialize log files ─────────────────────────────────
foreach ($Node in $Nodes) {
    $Log = $LogFiles[$Node.Name]
    Add-Content $Log ""
    Add-Content $Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Add-Content $Log "━━━ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Fleet Monitor: $($Node.Name) ━━━"
    Add-Content $Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Add-Content $Log "Waiting for commands..."
}

# ── Helper: build SSH options ────────────────────────────
function Get-SshOpts {
    param($Node)
    $Opts = @("-o", "IdentitiesOnly=yes", "-o", "ConnectTimeout=10",
              "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=2",
              "-p", $Node.Port)
    if ($Node.Key -ne "") { $Opts += @("-i", $Node.Key) }
    return $Opts
}

# ── Launch background watch jobs ─────────────────────────
$Jobs = @()
foreach ($Node in $Nodes) {
    $Log     = $LogFiles[$Node.Name]
    $SshOpts = Get-SshOpts $Node
    $UserHost = "$($Node.User)@$($Node.Host)"

    $Job = Start-Job -ScriptBlock {
        param($Log, $SshOpts, $UserHost, $NodeName, $SessionName, $TempDir)
        $LockFile = Join-Path $TempDir "fleet-$SessionName.lock"

        function Write-Log { param($M) Add-Content $Log $M }

        # Initial diagnostics
        Write-Log ""
        Write-Log "━━━ $(Get-Date -Format 'HH:mm:ss') openclaw health ━━━"
        try {
            $Out = & ssh @SshOpts $UserHost "openclaw health" 2>&1
            $Out | ForEach-Object { Write-Log $_ }
        } catch {
            Write-Log "[ERROR] $(Get-Date -Format 'HH:mm:ss') SSH failed for $NodeName"
        }

        Write-Log ""
        Write-Log "━━━ $(Get-Date -Format 'HH:mm:ss') openclaw status --deep ━━━"
        try {
            $Out = & ssh @SshOpts $UserHost "openclaw status --deep" 2>&1
            $Out | ForEach-Object { Write-Log $_ }
        } catch {
            Write-Log "[ERROR] $(Get-Date -Format 'HH:mm:ss') SSH failed for $NodeName"
        }

        # Watch loop — heartbeat every 60 s while lock file exists
        while (Test-Path $LockFile) {
            Start-Sleep 60
            Write-Log ""
            Write-Log "━━━ $(Get-Date -Format 'HH:mm:ss') [heartbeat] openclaw health ━━━"
            try {
                $Out = & ssh @SshOpts $UserHost "openclaw health" 2>&1
                $Out | ForEach-Object { Write-Log $_ }
            } catch {
                Write-Log "[ERROR] $(Get-Date -Format 'HH:mm:ss') Node unreachable: $NodeName"
            }
        }
    } -ArgumentList $Log, $SshOpts, $UserHost, $Node.Name, $SessionName, $TempDir

    $Jobs += $Job
    Write-Host "  ▸ Monitoring $($Node.Name) ($($Node.User)@$($Node.Host)):$($Node.Port) → PID $($Job.Id)"
}

# Write PID to lock file (use first job ID as proxy)
$Jobs[0].Id | Set-Content $LockFile

# ── Open Windows Terminal tabs (if available) ─────────────
if ($HasWt) {
    Write-Host ""
    Write-Host "  Opening Windows Terminal tabs for fleet monitoring..."
    $WtArgs = @("--title", "fleet:$SessionName")
    $First  = $true
    foreach ($Node in $Nodes) {
        $Log = $LogFiles[$Node.Name]
        if ($First) {
            $WtArgs += @("powershell.exe", "-NoExit", "-Command", "Get-Content -Wait '$Log'")
            $First = $false
        } else {
            $WtArgs += @(";", "new-tab", "--title", $Node.Name, "powershell.exe", "-NoExit", "-Command", "Get-Content -Wait '$Log'")
        }
    }
    try {
        Start-Process "wt.exe" -ArgumentList $WtArgs -ErrorAction Stop
    } catch {
        Write-Warning "Failed to open Windows Terminal automatically."
    }
}

# ── Attach instructions ───────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Fleet Monitor: $SessionName"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
foreach ($Node in $Nodes) {
    $Log = $LogFiles[$Node.Name]
    Write-Host "  $($Node.Name):"
    Write-Host "    Get-Content -Wait '$Log'"
}
Write-Host ""
Write-Host "  Stop:  Remove-Item '$LockFile'; Get-Job | Stop-Job; Get-Job | Remove-Job"
Write-Host "  Or:    /watch stop"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Output JSON summary for calling agent
$NodeNames = ($Nodes | ForEach-Object { "`"$($_.Name)`"" }) -join ','
Write-Host ""
Write-Host "FLEET_SESSION_INFO:{`"session`":`"$SessionName`",`"panes`":$($Nodes.Count),`"nodes`":[$NodeNames],`"reattached`":false}"
