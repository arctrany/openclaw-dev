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

### 升级到最新稳定版

```bash
openclaw update status --json
openclaw update --dry-run
openclaw update --yes
```

- `openclaw update` 会根据安装方式自动走 package manager 或 git checkout 更新路径。
- `availability.available: false` 表示当前 channel 已是最新，不需要重复安装。
- 如果 `doctor` 报 Gateway service 混入代理环境变量或版本管理 PATH，更新后执行 `openclaw gateway install --force` 重建服务定义。

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
openclaw doctor                     # 自动诊断 + 修复
openclaw health                     # Gateway 健康
openclaw status --deep --all        # 深度状态
openclaw channels status --probe    # Channel 探测
openclaw agents list --bindings     # Agent 路由
openclaw plugins list               # Plugin 状态
openclaw plugins doctor             # Plugin 诊断
openclaw update status --json       # 当前 channel / 最新版本 / 可升级状态
openclaw security audit --deep      # 深度安全审计
```

### 常见问题

| 问题 | 诊断 | 修复 |
|------|------|------|
| Gateway 不启动 | `openclaw doctor` | `lsof -i :18789` 检查端口 |
| Channel 连接失败 | `openclaw channels status --probe` | 检查 token |
| Skill 不加载 | `openclaw status --deep` | 检查 workspace 路径 |
| groupChat 回复落到源群 | `openclaw doctor` | 给 agent 启用 message tool，或把 `messages.groupChat.visibleReplies` 改成 `automatic` |
| owner-only 命令无法执行 | `openclaw doctor` | 设置 `commands.ownerAllowFrom` 并重启 Gateway |
| Qwen 登录失效 | `openclaw doctor` | 改用 `openclaw onboard --auth-choice qwen-api-key` 或 `qwen-api-key-cn` |
| session / transcript 不一致 | `openclaw doctor` + `openclaw sessions cleanup --dry-run` | 预览后再做 `--fix-missing` |
| Gateway service 环境污染 | `openclaw doctor` | `openclaw gateway install --force` 重建服务 |
| npm EACCES (Linux) | `npm config get prefix` | 用 `install-cli.sh` |
| openclaw 找不到 | `which openclaw` | 检查 PATH |
| WSL portproxy 失效 | `netsh interface portproxy show all` | WSL IP 变化需重配 |
