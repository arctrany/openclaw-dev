---
name: openclaw-node-operations
description: "Use this skill when asked to install OpenClaw, set up a node, configure a Gateway, onboard a new machine, debug OpenClaw issues (read logs, run doctor, health checks, diagnose faults), fix Gateway problems, set up networking (Tailscale, SSH tunnels), check node status, troubleshoot connectivity, configure remote access, deploy on Linux/Windows/macOS, lint config, validate openclaw.json, check fleet status, query agent/channel/plugin status, or run systematic diagnostics. Also use for: 'diagnose OpenClaw', 'lint my config', 'validate configuration', 'show status', 'fleet status', 'Gateway health', 'check OpenClaw health'. Covers hands-on operations: installation, onboarding, Gateway service management, remote access, cross-OS support, debugging, monitoring, diagnostics, config validation. For architecture/theory questions use openclaw-dev-knowledgebase instead."
metadata: {"clawdbot":{"always":false,"emoji":"🖥️","requires":{"bins":["jq","ssh"]}}}
user-invocable: true
version: 3.1.0
---

# OpenClaw Node Operations

节点的安装、配置、调试、组网、监控、诊断。

> ⛔ **铁律: 不可破坏 Memory**
> - 绝对不能删除、覆盖、截断 `memory/` 目录下的任何文件和 `MEMORY.md`
> - 只允许 **append** 操作，不允许 rewrite 或 truncate
> - 迁移 workspace 时必须完整保留 `memory/` 和 `MEMORY.md`
> - 任何涉及 workspace 目录的 `rm -rf`、`rsync --delete` 必须排除 `memory/`
>
> ⛔ **铁律: 遇到问题先跑 `openclaw doctor`**
> - 任何异常（Gateway 不启动、Agent 不响应、Skill 不加载、Channel 断连）先运行 `openclaw doctor`
> - doctor 会自动检测并修复常见问题，输出结果后再决定下一步

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

### 升级到最新稳定版

```bash
openclaw update status --json
openclaw update --dry-run
openclaw update --yes
```

- `openclaw update` 是官方首选升级入口，会按实际安装方式处理 package / git checkout。
- 先看 `update status`：若 `availability.available: false`，说明本机已经在当前 channel 的最新版本。
- `--dry-run` 先预览动作；自动化或无人值守环境再加 `--yes`。
- 若 `doctor` 提示 Gateway service 持久化了代理环境变量或过长 PATH，升级后执行 `openclaw gateway install --force` 重建服务定义。

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

### 交互式引导

```bash
openclaw onboard --install-daemon   # 推荐：含 Gateway 服务安装
openclaw onboard                    # 不安装 Gateway 服务
openclaw configure                  # 仅配置（已安装过 OpenClaw）
```

`openclaw onboard` 会依次询问：

| 步骤 | 问题 | 推荐选择 | 说明 |
|------|------|---------|------|
| 1 | Workspace 路径 | 默认 `~/.openclaw/workspace` | 直接回车 |
| 2 | Model provider | **Anthropic** | 最稳定，原生支持 |
| 3 | API Key | 从 [console.anthropic.com](https://console.anthropic.com) 获取 | 粘贴即可 |
| 4 | Model | **claude-sonnet-4-5** | 性价比最优 |
| 5 | Gateway daemon | **Yes** | 开机自启，后台常驻 |
| 6 | Channel | 首次可 **跳过** | 后续单独配 |

> 💡 如果没有 Anthropic API Key，可用 [OpenRouter](https://openrouter.ai) 获取免费额度试用。

### Onboard 完成后 → 第一步

```bash
# 1. 验证 Gateway 运行
openclaw health

# 2. 打开 WebChat (零配置，内置)
open http://127.0.0.1:18789/    # macOS
# 或浏览器打开 http://127.0.0.1:18789/

# 3. 发送 "你好" → 应收到 Agent 回复
# 这证明: Gateway ✅ Model ✅ Auth ✅ Agent ✅
```

## 快速体验 (5 分钟)

最快路径 — 从零到跟 Agent 对话：

```bash
# 1. 安装 (自动装 Node.js + OpenClaw)
curl -fsSL https://openclaw.ai/install.sh | bash

# 2. Onboard (选 Anthropic + claude-sonnet-4-5 + 装 Gateway)
openclaw onboard --install-daemon

# 3. 验证
openclaw health

# 4. 体验! 打开 WebChat
open http://127.0.0.1:18789/   # macOS
# 发送 "你好" 🎉
```

### 接下来: 选一个 Channel

| 难度 | Channel | 配置方式 | 耗时 |
|------|---------|---------|------|
| ⭐ | **WebChat** | 零配置，已内置 | 0 分钟 |
| ⭐⭐ | **Telegram** | 从 @BotFather 获取 token → 配置 | 5 分钟 |
| ⭐⭐⭐ | **WhatsApp** | QR 配对，功能最全 | 10 分钟 |
| ⭐⭐⭐ | **Discord** | 创建 Bot Application → 配置 | 15 分钟 |

```bash
# 配置 Channel (以 Telegram 为例)
# 1. Telegram 中找 @BotFather → /newbot → 获取 token
# 2. 设置 token:
openclaw channels add telegram --token "<your-bot-token>"
# 3. 验证:
openclaw channels status --probe
```

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
# 从笔记本连到远程 Gateway (推荐加 IdentitiesOnly 和指定密钥)
ssh -N -L 18789:127.0.0.1:18789 \
  -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  user@gateway-host &

# 然后本地 CLI 直连
openclaw health
openclaw status --deep
```

### SSH 排障 (分层方法)

⚠️ **每次远程操作前，先确认当前执行环境**：
```bash
echo "🖥️ 当前: $(hostname) | $(whoami) | $(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')"
```

SSH 故障分层排查顺序：**网络层 → 握手层 → 认证层**

| 层级 | 检查命令 | 正常输出 | 异常说明 |
|------|---------|---------|---------|
| **网络层** | `tailscale ping <host>` 或 `nc -zv <host> 22` | `Open` / `pong` | Tailscale 离线或防火墙 |
| **握手层** | `ssh -v user@host 2>&1 \| head -20` | `SSH-2.0-OpenSSH` | `Host key verification failed` → 修指纹 |
| **认证层** | `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 user@host` | 登录成功 | `Permission denied` → 查 authorized_keys |

### SSH 最佳实践

```bash
# 1. 始终使用 IdentitiesOnly + 指定密钥 (避免 Too many authentication failures)
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 user@host

# 2. Host key 冲突时精准清除 (不要删整个 known_hosts)
ssh-keygen -R <host-ip>

# 3. 远程机器 authorized_keys 权限必须严格
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R $(whoami):staff ~/.ssh   # macOS
# chown -R $(whoami):$(whoami) ~/.ssh  # Linux

# 4. 本机回环验证 (确认 sshd + authorized_keys 同时工作)
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 $(whoami)@127.0.0.1

# 5. 成功后记录公钥指纹 (后续可快速对比)
ssh-keygen -lf ~/.ssh/id_ed25519.pub
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
openclaw update status --json       # 当前 channel / 最新版本 / 可升级状态
openclaw security audit --deep      # 深度安全审计
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
| SSH Host key 报错 | `ssh -v user@host 2>&1 \| grep "Host key"` | `ssh-keygen -R <host>` 清除旧指纹 |
| SSH Too many auth failures | `ssh -v user@host 2>&1 \| grep -c "Offering"` | 加 `-o IdentitiesOnly=yes -i <key>` |
| SSH Permission denied | `ssh -o IdentitiesOnly=yes -i <key> user@host` | 检查远程 `~/.ssh/authorized_keys` 权限 (700/600) |

### Doctor 重点告警速查

| Doctor 告警 | 含义 | 处理 |
|------------|------|------|
| `messages.groupChat.visibleReplies = "message_tool"` but tool unavailable | 群聊里普通回复可能直接发到源群 | 为对应 agent 启用 message tool，或改成 `automatic` |
| `commands.ownerAllowFrom` 未配置 | owner-only 命令和危险操作审批没有明确人类 owner | `openclaw config set commands.ownerAllowFrom '["telegram:123456789"]'` 后重启 Gateway |
| `qwen-portal:* expired` + portal deprecated | 老的 Qwen portal OAuth 已废弃 | 改用 `openclaw onboard --auth-choice qwen-api-key` 或 `qwen-api-key-cn` |
| stale agent dir / missing transcripts | 磁盘 session 状态与 `agents.list` 或 transcript store 不一致 | 用 `openclaw sessions --store` / `openclaw sessions cleanup --dry-run` 预览，再决定清理 |
| gateway service embeds proxy env / long PATH | LaunchAgent/systemd 持久化了不该落盘的代理变量或版本管理 PATH | 审核环境后执行 `openclaw gateway install --force` 重建服务 |
| bundled provider discovery legacy mode | `plugins.allow` 已收紧，但 bundled provider 仍可能出现在 inventory | 确认允许列表后把 `plugins.bundledDiscovery` 设为 `allowlist` |

## 组网

详见 `openclaw-dev-knowledgebase` 的 `references/multi-node-networking.md`：

- Tailscale 互联 (跨地域加密隧道)
- 单 Gateway + 远程 Node 拓扑
- master/worker agent 委派
- 节点可见性查询

## 监控

### 节点状态查询

遵循 FSFR 原则，分层查询（详见 `references/status-runbook.md`）：

```bash
# 环境探测（先确认 openclaw 是否可用）
command -v openclaw && openclaw --version || echo "NO_OPENCLAW"
test -f ~/.openclaw/openclaw.json && echo "HAS_CONFIG" || echo "NO_CONFIG"

# 正常模式（openclaw 可用时，1 个命令获取 80% 信息）
openclaw health && openclaw status --deep --all

# 降级模式（openclaw 不可用但 config 存在时）
jq '{gateway: .gateway, agents: [.agents.list[] | {id,name,model}]}' ~/.openclaw/openclaw.json
```

## 操作 Runbooks

以下 runbook 提供完整的步骤化操作指南，按需读取：

| 操作 | 参考文件 | 用途 |
|------|---------|------|
| **系统性诊断** | `references/diagnose-runbook.md` | 5 步方法论分析 + 结构化报告 + 故障模式沉淀 |
| **配置验证** | `references/lint-config-runbook.md` | 验证 openclaw.json 语法/安全/路径/Auth |
| **状态仪表盘** | `references/status-runbook.md` | 分层状态查询 (FSFR) + 降级策略 + 格式化输出 |
