# OpenClaw 核心概念深度参考

## Node (节点)

Node 是连接到 Gateway 的外设设备，**不运行 Gateway 服务**。

### 类型

| Node | 平台 | 能力 |
|------|------|------|
| macOS App (node mode) | macOS | canvas, camera, screen, system.run, notify |
| iOS App | iOS | canvas, camera, location, screen.record |
| Android App | Android | canvas, camera, location, sms.send, screen.record |
| Headless Node Host | 跨平台 | system.run, system.which |

### 配对流程

```bash
# Node 端: 启动并连接 Gateway
openclaw node run --host <gateway-host> --port 18789 --display-name "Build Node"

# 远程 Gateway (loopback) 需要 SSH 隧道
ssh -N -L 18790:127.0.0.1:18789 user@gateway-host
export OPENCLAW_GATEWAY_TOKEN="<token>"
openclaw node run --host 127.0.0.1 --port 18790 --display-name "Build Node"

# Gateway 端: 审批
openclaw devices list
openclaw devices approve <requestId>
openclaw nodes status
```

### 常用命令

```bash
openclaw nodes canvas snapshot --node <id> --format png
openclaw nodes camera snap --node <id> --facing front
openclaw nodes screen record --node <id> --duration 10s
openclaw nodes location get --node <id>
openclaw nodes run --node <id> -- echo "Hello"
```

### exec 绑定

```bash
# 全局默认
openclaw config set tools.exec.host node
openclaw config set tools.exec.node "<node-name>"

# 每个 agent 单独配
openclaw config set agents.list[0].tools.exec.node "<node-name>"
```

### 关键注意

- Node 必须在前台才能用 `canvas.*` 和 `camera.*`
- `system.run` 受 exec approvals 控制: `~/.openclaw/exec-approvals.json`
- Node 不共享 Gateway 的 `PATH`，危险环境变量会被清除

---

## Workspace (工作区)

Workspace 是 agent 的"家"，是文件工具的默认 cwd。

### 路径

| 路径 | 用途 |
|------|------|
| `~/.openclaw/workspace` | 默认单 agent workspace |
| `~/.openclaw/workspace-<profile>` | OPENCLAW_PROFILE 模式 |
| `~/.openclaw/workspace-<agentId>` | 多 agent 各自 workspace |
| `agents.list[].workspace` | 配置文件中指定 |

### 文件结构

| 文件 | 用途 | 加载时机 |
|------|------|----------|
| `AGENTS.md` | 操作指令、行为规则 | 每个 session |
| `SOUL.md` | 人格、语调、边界 | 每个 session |
| `USER.md` | 用户信息 | 每个 session |
| `IDENTITY.md` | Agent 名称、emoji | Bootstrap |
| `TOOLS.md` | 本地工具说明 | 每个 session |
| `HEARTBEAT.md` | 心跳任务清单 | 心跳触发 |
| `BOOT.md` | Gateway 重启后执行 | Gateway 启动 |
| `BOOTSTRAP.md` | 首次运行仪式 | 仅第一次 |
| `memory/YYYY-MM-DD.md` | 每日记忆 | session 开始读 today+yesterday |
| `MEMORY.md` | 长期记忆 | 仅 main 私有 session |
| `skills/` | workspace 级 skills | 自动发现 |
| `canvas/` | Canvas UI 文件 | Node 显示 |

### workspace 之外的东西

```
~/.openclaw/
├── openclaw.json              # 配置（不在 workspace）
├── credentials/                # OAuth, API keys
├── agents/<id>/sessions/       # Session 日志
└── skills/                     # 全局 managed skills
```

### Git 备份

```bash
cd ~/.openclaw/workspace
git init
git add AGENTS.md SOUL.md TOOLS.md IDENTITY.md USER.md memory/
git commit -m "Add agent workspace"
gh repo create openclaw-workspace --private --source . --remote origin --push
```

### 迁移 workspace 到新机器

1. Clone workspace repo
2. 设 `agents.defaults.workspace` → 新路径
3. `openclaw setup --workspace <path>` 补缺失文件
4. 单独复制 `~/.openclaw/agents/<id>/sessions/`

---

## Agent (代理) & 委派

### Agent 定义

一个 agent 拥有独立的:
- **Workspace** (文件、人格、skills)
- **State** (`agentDir`: auth profiles, model registry)
- **Sessions** (聊天历史 + 路由状态)

```
~/.openclaw/agents/<agentId>/
├── agent/
│   ├── auth-profiles.json     # 独立 auth（不共享）
│   └── models.json            # 模型注册
└── sessions/
    ├── sessions.json
    └── <session-id>.jsonl
```

### 多 Agent 设置

```bash
openclaw agents add coding
openclaw agents add social
openclaw agents list --bindings
```

```json5
{
  agents: {
    list: [
      { id: "chat", name: "Everyday", workspace: "~/.openclaw/workspace-chat",
        model: "anthropic/claude-sonnet-4-5" },
      { id: "opus", name: "Deep Work", workspace: "~/.openclaw/workspace-opus",
        model: "anthropic/claude-opus-4-6" },
    ],
  },
}
```

### Binding 路由 (消息如何找到 agent)

优先级 (most-specific wins):

1. `peer` 精确匹配 (DM/group ID)
2. `parentPeer` 线程继承
3. `guildId + roles` (Discord 角色)
4. `guildId`
5. `teamId` (Slack)
6. `accountId`
7. `accountId: "*"` (channel 通配)
8. 默认 agent (first in list)

```json5
{
  bindings: [
    // peer 精确 > channel 通配
    { agentId: "opus", match: { channel: "whatsapp",
      peer: { kind: "direct", id: "+15551234567" } } },
    { agentId: "chat", match: { channel: "whatsapp" } },
  ],
}
```

### Agent-to-Agent 委派

**默认关闭**，必须显式启用 + 白名单:

```json5
{
  tools: {
    agentToAgent: {
      enabled: false,
      allow: ["home", "work"],
    },
  },
}
```

### Per-Agent 安全

```json5
{
  agents: {
    list: [{
      id: "family",
      sandbox: { mode: "all", scope: "agent" },
      tools: {
        allow: ["read", "exec"],
        deny: ["write", "edit", "browser", "canvas"],
      },
      groupChat: {
        mentionPatterns: ["@family", "@familybot"],
      },
    }],
  },
}
```

- `tools.allow/deny` 控制工具权限
- `sandbox` 控制执行隔离
- `tools.elevated` 是全局的，不能 per-agent

---

## Model (模型)

### 选择顺序

1. **Primary**: `agents.defaults.model.primary`
2. **Fallbacks**: `agents.defaults.model.fallbacks` (按序)
3. **Provider auth failover**: 同 provider 内轮换 auth profile

### 每个 agent 可设不同模型

```json5
{
  agents: {
    list: [
      { id: "chat", model: "anthropic/claude-sonnet-4-5" },
      { id: "opus", model: "anthropic/claude-opus-4-6" },
    ],
  },
}
```

### CLI

```bash
openclaw models list          # 已配置的模型
openclaw models list --all    # 完整目录
openclaw models status        # 当前 primary + fallbacks + auth 状态
openclaw models set <provider/model>
openclaw models fallbacks add <provider/model>
openclaw models scan          # 扫描 OpenRouter 免费模型
```

### 运行时切换 (聊天中)

```
/model                        # 列出可选模型
/model list                   # 同上
/model 3                      # 选第 3 个
/model openai/gpt-5.2         # 指定模型
/model status                 # 详细状态
```

### Allowlist

设了 `agents.defaults.models` = 白名单。没在白名单里的模型会报 "Model is not allowed"

```json5
{
  agent: {
    model: { primary: "anthropic/claude-sonnet-4-5" },
    models: {
      "anthropic/claude-sonnet-4-5": { alias: "Sonnet" },
      "anthropic/claude-opus-4-6": { alias: "Opus" },
    },
  },
}
```

### Auth

| Provider | 推荐方式 |
|----------|----------|
| Anthropic | `claude setup-token` 或 API key |
| OpenAI | API key 或 Codex OAuth |
| OpenRouter | API key (`OPENROUTER_API_KEY`) |
| 自定义 | `models.providers` in config |

Auth profiles 是 **per-agent** 的:
```
~/.openclaw/agents/<agentId>/agent/auth-profiles.json
```

---

## 开发/部署/调试常见问题

### Workspace 问题

| 问题 | 排查 |
|------|------|
| Skills 没加载 | 检查 workspace 路径对不对；发 `/new` 新 session |
| AGENTS.md 没生效 | 确认 `agents.list[].workspace` 指向正确路径 |
| 多个 workspace 冲突 | `openclaw doctor` 会检测；只保留一个活跃 workspace |
| Bootstrap 文件缺失 | `openclaw setup --workspace <path>` |

### Agent 路由问题

| 问题 | 排查 |
|------|------|
| 消息到了错误 agent | `openclaw agents list --bindings` 检查路由 |
| Binding 没匹配 | peer binding 必须在 channel-wide 前面 |
| Auth 冲突 | 不要 reuse `agentDir`，各 agent 独立 auth |
| Agent-to-agent 失败 | 检查 `tools.agentToAgent.enabled` + `allow` 列表 |

### Model 问题

| 问题 | 排查 |
|------|------|
| "Model is not allowed" | 加入 `agents.defaults.models` 白名单 |
| Auth 过期 | `openclaw models status --check` (exit 1=missing, 2=expiring) |
| Fallback 不生效 | `openclaw models fallbacks list` 确认配置 |
| 切换模型无效 | `/model status` 看当前实际使用的模型 |

### Node 问题

| 问题 | 排查 |
|------|------|
| Node 连接失败 | 确认 Gateway bind + port + token |
| 配对被拒 | `openclaw devices list` 重新审批 |
| exec 被拒 | 检查 `exec-approvals.json` 的 allowlist |
| 后台不可用 | Node 必须前台才能 canvas/camera |
