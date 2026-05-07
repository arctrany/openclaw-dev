# OpenClaw 安装和调试参考

## 安装

### 快速安装

| 平台 | 命令 |
|------|------|
| **macOS / Linux** | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| **macOS / Linux (无 root)** | `curl -fsSL https://openclaw.ai/install-cli.sh \| bash` |
| **Windows (PowerShell)** | `iwr -useb https://openclaw.ai/install.ps1 \| iex` |

### Installer 选项

| 选项 | install.sh | install.ps1 |
|------|-----------|-------------|
| 跳过 onboard | `--no-onboard` | `-NoOnboard` |
| Git 安装 | `--install-method git` | `-InstallMethod git` |
| Beta 版 | `--beta` | `-Tag beta` |
| Dry run | `--dry-run` | `-DryRun` |
| CI/自动化 | `--no-prompt --no-onboard` | `-NoOnboard` |

### 从源码

```bash
git clone https://github.com/openclaw/openclaw.git && cd openclaw
pnpm install && pnpm ui:build && pnpm build
openclaw onboard
```

### 平台特殊注意

**macOS**: 自动安装 Homebrew + Node 22。Gateway 安装为 LaunchAgent。

**Linux**: 推荐 Node 运行时（Bun 有 WhatsApp/Telegram bugs）。Gateway 安装为 systemd user service：
```bash
openclaw onboard --install-daemon
systemctl --user enable --now openclaw-gateway.service
```

**Windows**: 推荐 WSL2 (Ubuntu)：
```powershell
wsl --install -d Ubuntu-24.04
# 启用 systemd:
# /etc/wsl.conf → [boot] systemd=true
# 然后 wsl --shutdown && 重新打开
# 在 WSL 内同 Linux 安装
```

WSL 端口暴露 (PowerShell Admin):
```powershell
$WslIp = (wsl -d Ubuntu-24.04 -- hostname -I).Trim().Split(" ")[0]
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=18789 connectaddress=$WslIp connectport=18789
```

## 调试

### 日志位置

| 平台 | 路径 |
|------|------|
| macOS | `~/Library/Logs/OpenClaw/` 或 `~/.openclaw/logs/` |
| Linux | `journalctl --user -u openclaw-gateway` 或 `~/.openclaw/logs/` |
| Windows/WSL | WSL 内同 Linux |

### 诊断命令

```bash
openclaw doctor                     # 只读诊断
openclaw doctor --fix               # 应用建议修复
openclaw health                     # Gateway 健康
openclaw status --deep --all        # 深度状态
openclaw channels status --probe    # Channel 探测
openclaw agents list --bindings     # Agent 路由
openclaw plugins list               # Plugin 状态
openclaw plugins doctor             # Plugin 诊断
openclaw update status              # 更新通道 + 最新稳定版
```

### 2026.5.6: Codex OAuth 路由恢复

先确认当前更新状态：

```bash
openclaw update status
openclaw update --dry-run
```

如果 `2026.5.5` 的 `doctor --fix` 把默认 Codex OAuth 路由错误改写成了 `openai/*`，先恢复再继续排障：

```bash
openclaw models set openai-codex/gpt-5.5
openclaw config validate
```

### 常见问题

| 问题 | 诊断 | 修复 |
|------|------|------|
| Gateway 不启动 | `openclaw doctor` | `lsof -i :18789` 检查端口 |
| Channel 连接失败 | `openclaw channels status --probe` | 检查 token |
| Skill 不加载 | `openclaw status --deep` | 检查 workspace 路径 |
| `2026.5.5` 后 Codex OAuth 路由异常 | `openclaw update status` | `openclaw models set openai-codex/gpt-5.5 && openclaw config validate` |
| npm EACCES (Linux) | `npm config get prefix` | 用 `install-cli.sh` |
| openclaw 找不到 | `which openclaw` | 检查 PATH |
| WSL portproxy 失效 | `netsh interface portproxy show all` | WSL IP 变化需重配 |
