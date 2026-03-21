# Windows 原生操作手册

OpenClaw 在 Windows 上的安装、服务管理、调试、监控的完整操作指南。

> 💡 **推荐路径选择**
>
> | 场景 | 推荐 |
> |------|------|
> | 快速体验，仅本地使用 | Windows 原生 PowerShell（本文件）|
> | 需要 Tailscale/systemd/Linux 工具链 | WSL2 + Ubuntu（参见主 SKILL.md）|
> | 已有 WSL2 环境 | 在 WSL2 内按 Linux 指南操作 |

---

## 安装

### 方法 A: PowerShell 一键安装（推荐）

```powershell
# 以普通用户身份在 PowerShell 中运行
iwr -useb https://openclaw.ai/install.ps1 | iex
```

安装器会自动处理：Node.js（通过 winget 或 nvm-windows）、OpenClaw CLI、初始配置。

### 方法 B: 手动安装

```powershell
# 1. 安装 Node.js (v22+)
winget install OpenJS.NodeJS.LTS

# 2. 重新打开 PowerShell，安装 OpenClaw
npm install -g openclaw

# 3. 初始化
openclaw onboard --install-daemon
```

### 安装选项

| 选项 | 含义 |
|------|------|
| `-NoOnboard` | 跳过交互式引导 |
| `-InstallMethod git` | 从 Git 源码安装 |
| `-Tag beta` | 安装 Beta 版 |
| `-DryRun` | 预览，不实际安装 |

---

## Gateway 服务管理

OpenClaw 在 Windows 上支持两种后台运行方式：

### 方式 A: openclaw gateway 命令（推荐）

```powershell
openclaw gateway install   # 注册为 Windows 服务或 Task Scheduler
openclaw gateway start     # 启动
openclaw gateway stop      # 停止
openclaw gateway restart   # 重启
openclaw gateway status    # 查看状态
```

### 方式 B: Task Scheduler（手动）

```powershell
# 注册开机自启（管理员权限）
$Trigger = New-ScheduledTaskTrigger -AtLogon
$Action  = New-ScheduledTaskAction -Execute "openclaw" -Argument "gateway start --foreground"
Register-ScheduledTask -TaskName "OpenClawGateway" -Trigger $Trigger -Action $Action -RunLevel Highest

# 立即启动
Start-ScheduledTask -TaskName "OpenClawGateway"

# 停止并移除
Stop-ScheduledTask -TaskName "OpenClawGateway"
Unregister-ScheduledTask -TaskName "OpenClawGateway" -Confirm:$false
```

---

## 日志位置

| 类型 | 路径 |
|------|------|
| 主日志 | `%USERPROFILE%\.openclaw\logs\gateway.log` |
| 错误日志 | `%USERPROFILE%\.openclaw\logs\gateway.err.log` |
| 配置文件 | `%USERPROFILE%\.openclaw\openclaw.json` |
| Workspace | `%USERPROFILE%\.openclaw\workspace-<agent-id>\` |

```powershell
# 以 PowerShell 变量方式引用
$LogDir  = "$env:USERPROFILE\.openclaw\logs"
$Config  = "$env:USERPROFILE\.openclaw\openclaw.json"

# 实时查看错误日志（等价于 tail -f）
Get-Content -Wait "$LogDir\gateway.err.log"

# 查看最近 50 行
Get-Content "$LogDir\gateway.err.log" -Tail 50
```

---

## 状态查询与诊断

### 快速检查

```powershell
# 环境探测（等价于 Layer 0）
openclaw --version 2>$null; if ($?) { "HAS_OPENCLAW" } else { "NO_OPENCLAW" }
Test-Path "$env:USERPROFILE\.openclaw\openclaw.json" && "HAS_CONFIG" || "NO_CONFIG"

# 健康检查
openclaw health
openclaw status --deep --all
openclaw doctor
```

### 查看配置（降级模式，openclaw CLI 不可用时）

```powershell
# 需要安装 jq (winget install jqlang.jq) 或用 PowerShell JSON
$Cfg = Get-Content "$env:USERPROFILE\.openclaw\openclaw.json" | ConvertFrom-Json
$Cfg.gateway
$Cfg.agents.list | Select-Object id, name, model
```

---

## 端口和网络

```powershell
# 检查 Gateway 端口是否在监听
Test-NetConnection -ComputerName localhost -Port 18789
Get-NetTCPConnection -LocalPort 18789 -ErrorAction SilentlyContinue

# 等价于 lsof -i :18789（查占用进程）
Get-NetTCPConnection -LocalPort 18789 | Select-Object -ExpandProperty OwningProcess |
  ForEach-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }

# 检查防火墙规则（管理员）
Get-NetFirewallRule | Where-Object { $_.DisplayName -match "OpenClaw" }

# 手动添加防火墙规则（仅本地访问无需，仅需要 LAN 暴露时才添加）
New-NetFirewallRule -DisplayName "OpenClaw Gateway" -Direction Inbound -Protocol TCP -LocalPort 18789 -Action Allow
```

---

## 进程管理

```powershell
# 查找 OpenClaw 进程
Get-Process | Where-Object { $_.Name -match "openclaw|node" }

# 优雅重启 Gateway
openclaw gateway restart

# 强制终止（等价于 pkill openclaw-gateway）
Get-Process | Where-Object { $_.Name -match "openclaw-gateway" } | Stop-Process -Force
```

---

## WebChat 快速体验

```powershell
# 安装完 onboard 后，直接用浏览器打开
Start-Process "http://127.0.0.1:18789/"

# 发送 "你好" → 应收到 Agent 回复
# 这证明: Gateway ✅ Model ✅ Auth ✅ Agent ✅
```

---

## WSL2 互通（高级）

若 OpenClaw 运行在 WSL2 内，在 Windows 侧访问：

```powershell
# 获取 WSL IP
$WslIp = (wsl -d Ubuntu-24.04 -- hostname -I).Trim().Split(" ")[0]

# 设置端口转发（管理员）
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=18789 connectaddress=$WslIp connectport=18789

# 验证转发规则
netsh interface portproxy show all

# 删除转发规则（不再需要时）
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=18789
```

> ⚠️ WSL IP 在每次 `wsl --shutdown` 后会变化，需要重新执行上面的 portproxy 命令。

---

## 常见 Windows 问题排查

| 问题 | 诊断 | 修复 |
|------|------|------|
| `openclaw` 命令找不到 | `$env:PATH -split ";"` 检查 Node 路径 | `npm install -g openclaw` 重装；重开 PowerShell |
| Gateway 不启动 | `Get-NetTCPConnection -LocalPort 18789` | 检查端口冲突；检查 Windows 防火墙 |
| PowerShell 报 Execution Policy | `Get-ExecutionPolicy` | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| WSL portproxy 失效 | `netsh interface portproxy show all` | WSL IP 变化，重新执行 portproxy add |
| onboard 失败（Node 版本太旧）| `node --version` | 安装 Node.js 22+：`winget install OpenJS.NodeJS.LTS` |
| 防火墙阻断 Channel 回调 | 查 Windows Defender 防火墙日志 | 添加 inbound rule 或用隧道（Cloudflare Tunnel）|

---

## Fleet 监控（Windows Terminal）

Windows 没有 tmux，但可以用 `fleet-monitor.ps1` + Windows Terminal：

```powershell
# 启动 fleet 监控（等价于 bash scripts/fleet-tmux.sh）
$Nodes = '[{"name":"home-mac","user":"your-user","host":"100.x.x.x","port":"22","key":""}]'
.\scripts\fleet-monitor.ps1 -SessionName "openclaw-fleet" -NodesJson $Nodes
```

脚本会：
1. 初始化日志文件到 `%TEMP%\fleet-<session>-<node>.log`
2. 启动 PowerShell Background Job 做 SSH 轮询
3. 若检测到 Windows Terminal (`wt.exe`)，自动打开多标签实时查看
4. 输出 `Get-Content -Wait <log>` 指令供手动 attach

停止监控：
```powershell
# 删除锁文件（Watch Loop 自动退出）
Remove-Item "$env:TEMP\fleet-openclaw-fleet.lock" -Force
Get-Job | Stop-Job
Get-Job | Remove-Job
```
