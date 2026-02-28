---
name: openclaw-node-operations
description: "Use this skill when asked to install OpenClaw, set up a node, configure a Gateway, onboard a new machine, debug OpenClaw issues (read logs, run doctor, health checks, diagnose faults), fix Gateway problems, set up networking (Tailscale, SSH tunnels), check node status, troubleshoot connectivity, configure remote access, deploy on Linux/Windows/macOS, lint config, validate openclaw.json, check fleet status, query agent/channel/plugin status, or run systematic diagnostics. Also use for: 'diagnose OpenClaw', 'lint my config', 'validate configuration', 'show status', 'fleet status', 'Gateway health', 'check OpenClaw health'. Covers hands-on operations: installation, onboarding, Gateway service management, remote access, cross-OS support, debugging, monitoring, diagnostics, config validation. For architecture/theory questions use openclaw-dev-knowledgebase instead."
metadata: {"clawdbot":{"always":false,"emoji":"🖥️"}}
version: 2.0.0
---

# OpenClaw Node Operations

节点的安装、配置、调试、组网、监控、诊断。

## 安装

### 快速安装（推荐）

| 平台 | 命令 |
|------|------|
| **macOS / Linux** | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| **macOS / Linux (无 root)** | `curl -fsSL https://openclaw.ai/install-cli.sh \| bash` |
| **Windows (PowerShell)** | `iwr -useb https://openclaw.ai/install.ps1 \| iex` |

### 从源码安装

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm ui:build
pnpm build
openclaw onboard
```

### 安装选项

| 选项 | install.sh | install.ps1 |
|------|-----------|-------------|
| 跳过 onboard | `--no-onboard` | `-NoOnboard` |
| Git 安装 | `--install-method git` | `-InstallMethod git` |
| Beta 版 | `--beta` | `-Tag beta` |
| Dry run | `--dry-run` | `-DryRun` |
| CI/自动化 | `--no-prompt --no-onboard` | `-NoOnboard` |

### 平台特殊注意

**macOS**: 自动安装 Homebrew + Node 22。Gateway 可通过 `openclaw gateway install` 安装为 LaunchAgent。

**Linux**: 推荐 Node 运行时（非 Bun）。Gateway 安装为 systemd user service：
```bash
openclaw onboard --install-daemon
# 或手动:
systemctl --user enable --now openclaw-gateway.service
```

**Windows**: 推荐通过 **WSL2 (Ubuntu)** 运行：
```powershell
# 1. 安装 WSL2
wsl --install -d Ubuntu-24.04
# 2. 启用 systemd
echo -e "[boot]\nsystemd=true" | sudo tee /etc/wsl.conf
wsl --shutdown
# 3. 在 WSL 内安装 OpenClaw (同 Linux)
```

如需从外部访问 WSL 内的 Gateway (LAN 暴露):
```powershell
# PowerShell (Admin) — 端口转发
$WslIp = (wsl -d Ubuntu-24.04 -- hostname -I).Trim().Split(" ")[0]
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=18789 connectaddress=$WslIp connectport=18789
```

## Onboarding

```bash
openclaw onboard                    # 交互式
openclaw onboard --install-daemon   # 含 Gateway 服务安装
openclaw configure                  # 仅配置
```

Onboard 流程：设置 workspace → 配置 model provider → 创建 auth profile → 安装 Gateway 服务 → 配置 channels

## Gateway 管理

```bash
# 服务管理
openclaw gateway install     # 安装为系统服务
openclaw gateway start       # 启动
openclaw gateway stop        # 停止
openclaw gateway restart     # 重启
openclaw gateway status      # 状态

# 健康检查
openclaw health              # 基础健康
openclaw status --deep       # 深度状态
openclaw doctor              # 诊断修复
```

### 多 Gateway (同一机器)

用 `--profile` 隔离:
```bash
openclaw --profile main gateway --port 18789
openclaw --profile rescue gateway --port 19001
```

⚠️ 端口间距 ≥ 20（浏览器/canvas 派生端口避免冲突）

## 远程访问

### SSH 隧道

```bash
# 从笔记本连到远程 Gateway
ssh -N -L 18789:127.0.0.1:18789 user@gateway-host &

# 然后本地 CLI 直连
openclaw health
openclaw status --deep
```

### Tailscale

```bash
# 每台机器加入同一 Tailnet
tailscale up
tailscale status

# Gateway 发布发现信息
export OPENCLAW_TAILNET_DNS=my-gateway
export OPENCLAW_SSH_PORT=22
```

### CLI 远程默认值

```json5
// ~/.openclaw/openclaw.json
{
  gateway: {
    mode: "remote",
    remote: {
      url: "ws://127.0.0.1:18789",
      token: "your-token",
    },
  },
}
```

## 调试

### 日志位置

| 平台 | 路径 |
|------|------|
| macOS | `~/Library/Logs/OpenClaw/` 或 `~/.openclaw/logs/` |
| Linux | `journalctl --user -u openclaw-gateway` 或 `~/.openclaw/logs/` |
| Windows/WSL | WSL 内同 Linux |

### 常用诊断命令

```bash
openclaw doctor                     # 自动诊断 + 修复
openclaw health                     # Gateway 健康
openclaw status --deep --all        # 所有组件深度状态
openclaw channels status --probe    # Channel 连接探测
openclaw agents list --bindings     # Agent 路由检查
openclaw plugins list               # Plugin 加载状态
openclaw plugins doctor             # Plugin 诊断
```

### 常见问题

| 问题 | 诊断 | 修复 |
|------|------|------|
| Gateway 不启动 | `openclaw doctor` | 检查端口占用: `lsof -i :18789` |
| Channel 连接失败 | `openclaw channels status --probe` | 检查 token/credentials |
| Node 连不上 | `tailscale status` + ping | 检查 Tailscale 状态 |
| Skill 不加载 | `openclaw status --deep` | 检查 workspace 路径 |
| Auth 失败 | `openclaw status --all` | `openclaw onboard` 重新配置 |
| npm EACCES (Linux) | `npm config get prefix` | `install-cli.sh` 安装到 `~/.openclaw` |
| openclaw 命令找不到 | `which openclaw` | 检查 PATH |
| WSL portproxy 失效 | `netsh interface portproxy show all` | WSL IP 变化后需重新配置 |

## 组网

详见 `references/multi-node-networking.md`：

- Tailscale 互联 (跨地域加密隧道)
- 单 Gateway + 远程 Node 拓扑
- master/worker agent 委派
- 节点可见性查询

## 监控

### 节点状态查询

```bash
# Agent 列表
openclaw agents list --bindings

# 完整状态
openclaw status --deep --all

# Tailscale 网络
tailscale status --json | jq '.Peer[] | {Name: .HostName, IP: .TailscaleIPs[0], Online: .Online}'

# Session 活跃度
for agent in $(jq -r '.agents.list[].id' ~/.openclaw/openclaw.json); do
  echo "$agent: $(ls ~/.openclaw/agents/$agent/sessions/*.jsonl 2>/dev/null | wc -l | tr -d ' ') sessions"
done
```

## 操作 Runbooks

以下 runbook 提供完整的步骤化操作指南，按需读取：

| 操作 | 参考文件 | 用途 |
|------|---------|------|
| **系统性诊断** | `references/diagnose-runbook.md` | 5 步方法论分析 + 结构化报告 + 故障模式沉淀 |
| **配置验证** | `references/lint-config-runbook.md` | 验证 openclaw.json 语法/安全/路径/Auth |
| **状态仪表盘** | `references/status-runbook.md` | 全组件状态查询 + 格式化输出 |

