---
name: setup-node
description: "Guided OpenClaw node initialization — install, onboard, configure Gateway, set up networking"
user-invocable: true
---

# /setup-node — 初始化 OpenClaw 节点

引导用户在新机器上完成 OpenClaw 安装和配置。

## 流程

### 1. 环境检测

确定操作系统和现有环境：

```bash
# 检测 OS
uname -s   # Darwin / Linux
# Windows: 检查 WSL
wsl --list 2>/dev/null

# 检测已有安装
which openclaw 2>/dev/null
which node 2>/dev/null
which tailscale 2>/dev/null
```

### 2. 安装 OpenClaw

根据 OS 选择安装方式：

**macOS / Linux:**
```bash
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash
```

**Linux (无 root 权限):**
```bash
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install-cli.sh | bash
```

**Windows (PowerShell):**
```powershell
# 先确保 WSL2
wsl --install -d Ubuntu-24.04
# 在 WSL 内:
curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install.sh | bash
```

### 3. Onboarding

```bash
openclaw onboard --install-daemon
```

引导完成：
- Model provider 配置 (API key)
- Workspace 创建
- Auth profile 设置
- Gateway 服务安装

### 4. 验证

```bash
openclaw health
openclaw status --deep
openclaw doctor
```

### 5. 可选：网络配置

询问用户是否需要远程访问或组网：

**Tailscale（推荐）:**
```bash
brew install tailscale    # macOS
sudo apt install tailscale # Linux
tailscale up
```

**SSH 远程访问:**
```bash
# 从其他机器连接
ssh -N -L 18789:127.0.0.1:18789 user@this-host &
```

### 6. 输出初始化报告

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🖥  Node Setup Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OS:        macOS 15.2 / Linux Ubuntu 24.04 / Windows WSL2
OpenClaw:  v2026.x.x
Node.js:   v22.x.x
Gateway:   running (:18789)
Workspace: ~/.openclaw/workspace
Agent:     main (default)
Tailscale: connected (100.x.x.x)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Next: send a message to your agent via channel, or use WebChat at http://127.0.0.1:18789/
```
