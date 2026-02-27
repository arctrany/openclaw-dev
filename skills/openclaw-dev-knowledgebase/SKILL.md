---
name: openclaw-dev-knowledgebase
description: "Use this skill when the user asks about OpenClaw architecture overview, development setup, debugging OpenClaw locally or remotely, OpenClaw configuration, Gateway troubleshooting, session logs, channel setup, building openclaw from source, testing openclaw, releasing openclaw, macOS app, openclaw CLI commands, memory search, cron jobs, heartbeat, hooks, webhooks, browser automation, tool policy, sandboxing, security audit, workspace bootstrap files, node pairing, discovery, networking topology, or general OpenClaw internals questions. For creating agents use openclaw-agent-development; for creating plugins use openclaw-plugin-architecture; for creating skills use openclaw-skill-development; for evolving skills use openclaw-skill-evolution."
metadata: {"clawdbot":{"always":false,"emoji":"📚"}}
user-invocable: true
version: 2.0.0
---

# OpenClaw Dev Knowledgebase

全面覆盖 OpenClaw 的 **功能 / 架构 / 开发 / 部署 / 运维** 五个维度。

---

## 一、功能 (Features)

### 核心功能

| 功能 | 说明 | 详细参考 |
|------|------|---------|
| **Multi-Agent** | 多 Agent 路由、委派、隔离、per-agent 安全 | `references/core-concepts.md` |
| **Sessions** | DM 隔离、session key 映射、生命周期、compaction | `references/sessions-memory-automation-security.md` |
| **Memory** | MEMORY.md + daily files + 向量搜索 (BM25+Vector hybrid) | 同上 |
| **Channels** | 20+ 渠道 (WhatsApp/Telegram/Discord/iMessage...) | `references/workspace-channels-discovery.md` |
| **Tools** | 15+ 内置工具 (exec/fs/browser/message/cron...) | `references/tools-browser-plugins.md` |
| **Browser** | 隔离浏览器、CDP profiles、Playwright snapshots | 同上 |
| **Cron & Heartbeat** | 定时任务 + 心跳轮询 | `references/sessions-memory-automation-security.md` + `references/hooks-webhooks-heartbeat.md` |
| **Hooks & Webhooks** | 内部事件驱动 + 外部 HTTP 接入 | `references/hooks-webhooks-heartbeat.md` |
| **Plugins** | TypeScript 扩展 (channels/tools/provider auth/CLI) | `references/tools-browser-plugins.md` |
| **Nodes** | 设备配对 (canvas/camera/screen/exec) | `references/core-concepts.md` |
| **多节点组网** | Tailscale 互联、跨地域 master/worker 部署、Node 可见性 | `references/multi-node-networking.md` |
| **Sandboxing** | Docker 容器隔离 (modes/scopes/workspace access) | `references/sessions-memory-automation-security.md` |

### Workspace 引导文件

| 文件 | 用途 | 加载时机 |
|------|------|---------|
| `AGENTS.md` | 操作指令、记忆规则 | 每个 session |
| `SOUL.md` | 人格、语气、边界 | 每个 session |
| `USER.md` | 用户信息 | 每个 session |
| `IDENTITY.md` | Agent 名字/emoji | Bootstrap |
| `TOOLS.md` | 本地工具约定 | 每个 session |
| `HEARTBEAT.md` | 心跳检查表 | 心跳 run |
| `BOOT.md` | 启动脚本 | Gateway 启动 |
| `MEMORY.md` | 长期记忆 | Main session |

详细 → `references/workspace-channels-discovery.md`

---

## 二、架构 (Architecture)

```
WhatsApp / Telegram / Slack / Discord / Signal / iMessage / Teams / Matrix / WebChat
               │
               ▼
┌───────────────────────────────┐
│     Gateway (WS control plane)│  ws://127.0.0.1:18789
│  Sessions, channels, tools,   │
│  events, cron, webhooks       │
└──────────────┬────────────────┘
               │
               ├─ Pi agent runtime (RPC, tool+block streaming)
               ├─ CLI (openclaw …)
               ├─ Control UI + WebChat
               ├─ macOS app (menu bar, Voice Wake, Talk Mode)
               └─ iOS / Android nodes (Canvas, camera)
```

### 关键组件

| 组件 | 说明 |
|------|------|
| **Gateway** | 单一 WS 控制面，所有 clients/tools/events |
| **Pi Agent** | AI 运行时 (RPC 模式，tool+block 流式) |
| **Session** | 隔离对话上下文 (main/group/queue/cron/hook) |
| **Channel** | 消息表面 (20+ 渠道) |
| **Skill** | `SKILL.md` 注入系统提示 |
| **Extension** | 进程内 TypeScript 插件 |
| **Node** | 设备 (mac/iOS/Android) 通过 WS 连接 |

### 网络拓扑

| 方案 | Config | 访问方式 |
|------|--------|---------|
| **Tailscale Serve** | `tailscale: { mode: "serve" }` | `https://<magicdns>/` |
| **Tailscale 直绑** | `bind: "tailnet"` + token | `ws://<tailscale-ip>:18789` |
| **SSH 隧道** | `bind: "loopback"` | `ssh -N -L 18789:127.0.0.1:18789 user@host` |
| **Funnel (公网)** | `tailscale: { mode: "funnel" }` + password | `https://<magicdns>/` |

详细组网 → `references/networking.md`

---

## 三、开发 (Development)

### 构建

```bash
pnpm install          # 安装依赖
pnpm build            # 全量构建 (UI + core → dist/)
pnpm openclaw ...     # Dev 模式运行 CLI (tsx)
pnpm gateway:watch    # 自动重载开发循环
```

Onboard: `pnpm openclaw onboard --install-daemon`

### 调试 — 本地

```bash
pnpm openclaw gateway --port 18789 --verbose   # verbose 启动
pnpm openclaw doctor                           # 健康检查
pnpm openclaw channels status --probe          # channel 探测
./scripts/clawlog.sh                           # macOS 日志

# 尾读 session 日志
tail -f ~/.openclaw/agents/<id>/sessions/*.jsonl | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        obj = json.loads(line.strip())
        role = obj.get('message',{}).get('role','')
        print(f'{role}: {str(obj.get(\"message\",{}).get(\"content\",\"\"))[:200]}')
    except: pass
"
```

### 调试 — 远程

```bash
ssh <host>
sudo npm i -g openclaw@latest
pkill -9 -f openclaw-gateway || true
nohup openclaw gateway run --bind loopback --port 18789 --force > /tmp/openclaw-gateway.log 2>&1 &
openclaw channels status --probe
tail -n 120 /tmp/openclaw-gateway.log
```

### 测试

| Command | Scope |
|---------|-------|
| `pnpm test` | All (vitest, parallel) |
| `pnpm test:fast` | Unit only |
| `pnpm test:e2e` | End-to-end |
| `pnpm test:coverage` | V8 coverage |
| `pnpm test:live` | Real API keys |

低内存: `OPENCLAW_TEST_PROFILE=low OPENCLAW_TEST_SERIAL_GATEWAY=1 pnpm test`

### 代码地图

详细 → `references/source-code-map.md`

---

## 四、部署 (Deployment)

### 配置文件

| 路径 | 用途 |
|------|------|
| `~/.openclaw/openclaw.json` | 主配置 |
| `~/.openclaw/credentials/` | Channel credentials |
| `~/.openclaw/workspace/` | Agent workspace |
| `~/.openclaw/workspace/skills/` | Workspace skills |
| `~/.openclaw/skills/` | Managed (全局) skills |
| `~/.openclaw/agents/<id>/sessions/*.jsonl` | Session 日志 |

### Skill 部署

```bash
# 查找 workspace
jq '.agents.list[] | {id, workspace}' ~/.openclaw/openclaw.json

# 复制 skill
cp -r my-skill/ "$WORKSPACE/skills/my-skill/"

# 发送 /new 加载最新 skills

# 远程部署
rsync -avz ./my-skill/ user@remote:~/.openclaw/workspace/skills/my-skill/
```

### Skill 解析顺序 (高 → 低)

1. **Workspace**: `<agent-workspace>/skills/<name>/SKILL.md`
2. **Managed**: `~/.openclaw/skills/<name>/SKILL.md`
3. **Bundled**: `<install>/skills/<name>/SKILL.md`

### 版本管理

- frontmatter `version: X.Y.Z`
- `.evolution/` 历史版本
- `openclaw-skill-evolution` skill 做数据驱动改进

### Release

| 类型 | Tag | npm 标签 |
|------|-----|---------|
| Stable | `vYYYY.M.D` | `latest` |
| Beta | `vYYYY.M.D-beta.N` | `beta` |
| Dev | main branch | `dev` |

Pre-check: `pnpm release:check`

---

## 五、运维 (Operations)

### 常见问题

| 问题 | 解决 |
|------|------|
| Gateway 不启动 | `openclaw doctor`, 检查端口 18789 |
| Channel 不连接 | `openclaw channels status --probe` |
| Skills 不加载 | `/new` 刷新 session |
| 配置不生效 | `pkill -TERM openclaw-gateway` 重启 |
| Agent 循环调用 | 启用 `tools.loopDetection.enabled: true` |
| 沙盒权限问题 | `openclaw sandbox explain` |

### 安全审计

```bash
openclaw security audit          # 快速审计
openclaw security audit --deep   # 深度 (含 Gateway 探针)
openclaw security audit --fix    # 自动修复
```

### 安全加固

```bash
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/openclaw.json
```

### 运维手册

详细 Remote Gateway 远程登录、Gateway 远程运维、macOS 应用维护 → `references/runbooks.md`

---

## 参考文件索引

| 文件 | 内容 |
|------|------|
| `references/core-concepts.md` | Node / Workspace / Agent (多 Agent、委派、安全) / Model (选择、fallback、auth) / 故障排查 |
| `references/sessions-memory-automation-security.md` | Session 管理 / Memory 系统 / Cron 自动化 / Security 安全 / Sandboxing 沙盒 |
| `references/hooks-webhooks-heartbeat.md` | 内部 Hooks 事件系统 / Webhooks HTTP 接入 / Heartbeat 心跳轮询 |
| `references/tools-browser-plugins.md` | 工具系统 (profiles/groups/15+ tools) / Browser CDP 控制 / Plugin 插件 API |
| `references/workspace-channels-discovery.md` | Workspace 引导文件 / 20+ 消息渠道 / Discovery 发现与传输 |
| `references/networking.md` | 网络拓扑 / 4 种组网方案 / Credential 优先级 / Tailscale auth / 安全规则 |
| `references/runbooks.md` | Remote Gateway 远程登录 / Gateway 远程运维 / macOS 应用维护 |
| `references/source-code-map.md` | 源代码目录映射 |
| `references/extensions-and-skills.md` | 39 个扩展 + 52 个内置 skills 列表 |
