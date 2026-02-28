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

引导完成（推荐选择）：

| 步骤 | 推荐 |
|------|------|
| Model provider | **Anthropic** |
| API Key | 从 console.anthropic.com 获取 |
| Model | **claude-sonnet-4-5** |
| Gateway daemon | **Yes** |
| Channel | 首次可**跳过** |

> 💡 没有 API Key？用 [OpenRouter](https://openrouter.ai) 免费额度试用。

### 4. 验证

```bash
openclaw health
openclaw status --deep
openclaw doctor
```

### 5. 首次体验 (WebChat)

```bash
# WebChat 零配置，onboard 完就能用
open http://127.0.0.1:18789/    # macOS
# 或浏览器打开 http://127.0.0.1:18789/

# 发送 "你好" → 应收到 Agent 回复
# 这证明: Gateway ✅ Model ✅ Auth ✅ Agent ✅
```

### 6. 可选：接入 Channel

询问用户是否需要接通消息渠道：

| 难度 | Channel | 配置方式 | 耗时 |
|------|---------|---------|------|
| ⭐ | WebChat | 零配置 (已完成) | 0 分钟 |
| ⭐⭐ | Telegram | @BotFather → token | 5 分钟 |
| ⭐⭐⭐ | WhatsApp | QR 配对 | 10 分钟 |

**Telegram 快速接入 (推荐第二个 Channel)：**
```bash
# 1. Telegram 中找 @BotFather → /newbot → 获取 token
# 2. 配置:
openclaw channels add telegram --token "<your-bot-token>"
# 3. 验证:
openclaw channels status --probe
```

### 7. 可选：网络配置

询问用户是否需要远程访问或组网：

**Tailscale（推荐）:**
```bash
brew install tailscale    # macOS
sudo apt install tailscale # Linux
tailscale up
```

**SSH 远程访问:**
```bash
# 从其他机器连接 (推荐加 IdentitiesOnly)
ssh -N -L 18789:127.0.0.1:18789 \
  -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  user@this-host &
```

### 8. 输出初始化报告

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
Model:     anthropic/claude-sonnet-4-5
Channels:  webchat ✅
Tailscale: connected (100.x.x.x) / not configured

📨 What's Next:
  1. WebChat: http://127.0.0.1:18789/
  2. 接 Telegram: openclaw channels add telegram --token <token>
  3. 创建新 Agent: /scaffold-agent
  4. 诊断问题: /diagnose
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
