# OpenClaw 事件驱动自动化 — Hooks, Webhooks, Heartbeat

## Hooks (内部事件系统)

### 概念

Hooks 是 Gateway 内部事件监听器。当 agent 命令 (`/new`, `/reset`, `/stop`) 或生命周期事件触发时运行。

### 内置 Hooks

| Hook | 事件 | 说明 |
|------|------|------|
| `session-memory` | `command:new` | `/new` 时存 session 到 `memory/YYYY-MM-DD-slug.md` |
| `bootstrap-extra-files` | `agent:bootstrap` | 注入额外 workspace 文件 (glob 匹配) |
| `command-logger` | `command` | JSONL 审计日志 → `~/.openclaw/logs/commands.log` |
| `boot-md` | `gateway:startup` | Gateway 启动时执行 `BOOT.md` |

### 事件类型

| 类型 | 事件 | 说明 |
|------|------|------|
| Command | `command:new / reset / stop` | 用户命令 |
| Agent | `agent:bootstrap` | 引导前 (可修改 bootstrapFiles) |
| Gateway | `gateway:startup` | channels + hooks 加载后 |
| Message | `message:received / sent` | 消息收发 |
| Tool | `tool_result_persist` | 同步修改工具结果 (plugin API) |

### 发现顺序 (高 → 低)

1. `<workspace>/hooks/` — per-agent
2. `~/.openclaw/hooks/` — 全局
3. `<openclaw>/dist/hooks/bundled/` — 内置

### Hook 目录结构

```
my-hook/
├── HOOK.md      # YAML frontmatter + 文档
└── handler.ts   # 导出 default async (event) => { ... }
```

### HOOK.md 元数据

```yaml
---
name: my-hook
description: "Short description"
metadata:
  openclaw:
    emoji: "🎯"
    events: ["command:new"]
    requires:
      bins: ["git"]
      env: ["API_KEY"]
      config: ["workspace.dir"]
      os: ["darwin"]
---
```

### Hook Packs (npm)

```bash
openclaw hooks install @acme/my-hooks
```

`package.json` 中 `openclaw.hooks` 列表。安装到 `~/.openclaw/hooks/<id>`。依赖用 `npm install --ignore-scripts`。

### 管理命令

```bash
openclaw hooks list [--eligible] [--verbose]
openclaw hooks info <id>
openclaw hooks check
openclaw hooks enable <id>
openclaw hooks disable <id>
```

### 最佳实践

- Handler 保持轻量 (fire-and-forget)
- try/catch 包裹 (不影响其他 handlers)
- 事件过滤要早 return
- 在 metadata 中声明精确事件 (不用 `command` 用 `command:new`)

---

## Webhooks (外部 HTTP 接入)

### 启用

```json5
{
  hooks: {
    enabled: true,
    token: "shared-secret",
    path: "/hooks",
    allowedAgentIds: ["hooks", "main"],
  },
}
```

### 认证

- `Authorization: Bearer <token>` (推荐)
- `x-openclaw-token: <token>`
- ⚠️ Query string `?token=...` 被拒绝 (400)

### 端点

#### `POST /hooks/wake`

```json
{ "text": "System line", "mode": "now" }
```
在 **main session** 排入系统事件。`mode=now` 触发立即 heartbeat。

#### `POST /hooks/agent`

```json
{
  "message": "Run this",
  "name": "Email",
  "agentId": "hooks",
  "wakeMode": "now",
  "deliver": true,
  "channel": "last",
  "to": "+15551234567",
  "model": "openai/gpt-5.2-mini",
  "thinking": "low",
  "timeoutSeconds": 120
}
```
运行 **isolated** agent turn。Summary 投递到 main session。

#### `POST /hooks/<name>` (映射)

`hooks.mappings` 自定义命名映射。支持 `match.source`、`transform.module`、`deliver` 到 channel。

### Session Key 策略

```json5
{
  hooks: {
    defaultSessionKey: "hook:ingress",
    allowRequestSessionKey: false, // 默认禁止覆盖
    allowedSessionKeyPrefixes: ["hook:"],
  },
}
```

### 响应码

| 码 | 说明 |
|----|------|
| 200 | `/hooks/wake` 成功 |
| 202 | `/hooks/agent` 异步启动 |
| 401 | 认证失败 |
| 429 | 速率限制 (重复认证失败) |
| 400 | 无效 payload |
| 413 | Payload 过大 |

### 安全

- Webhook 端点放在 loopback / tailnet / 可信反代后面
- 使用专用 hook token，不复用 gateway auth token
- Payload 默认被安全边界包裹 (untrusted content)
- `allowUnsafeExternalContent: true` 仅对可信内部源

---

## Heartbeat (定时心跳)

### 核心概念

Gateway 运行**定期 agent turn** (在 main session)，agent 根据 `HEARTBEAT.md` 检查表决定是否通知用户。

### 默认行为

- 间隔: `30m` (Anthropic OAuth: `1h`)
- 响应约定: 无事 → `HEARTBEAT_OK`；有告警 → 不含 `HEARTBEAT_OK`
- `HEARTBEAT_OK` + ≤300 chars → 静默吞掉

### 配置

```json5
{
  agents: {
    defaults: {
      heartbeat: {
        every: "30m",
        target: "last",           // none | last | <channel>
        to: "+15551234567",       // 可选
        directPolicy: "allow",    // allow | block
        model: "provider/model",  // 可选覆盖
        includeReasoning: false,  // 发送推理过程
        activeHours: {
          start: "09:00",
          end: "22:00",
          timezone: "America/New_York",
        },
      },
    },
  },
}
```

### Per-Agent Heartbeat

`agents.list[].heartbeat` 设置后，只有**有 heartbeat block 的 agent** 运行心跳。

### HEARTBEAT.md

```markdown
# Heartbeat checklist

- Quick scan: anything urgent in inboxes?
- If daytime, lightweight check-in if nothing pending
- If a task is blocked, write down what is missing
```

- 空文件 (仅标题) → 跳过心跳 (省 token)
- 文件不存在 → heartbeat 仍运行

### 可见性控制

```yaml
channels:
  defaults:
    heartbeat:
      showOk: false      # 隐藏 OK (默认)
      showAlerts: true    # 显示告警 (默认)
      useIndicator: true  # UI indicator (默认)
```

三者全 false → 完全跳过 heartbeat run。

### 手动唤醒

```bash
openclaw system event --text "Check urgent follow-ups" --mode now
```

### 成本注意

Heartbeat 运行完整 agent turn。短间隔 = 更多 token。考虑:
- 便宜 model
- `target: "none"` (仅内部更新)
- 保持 HEARTBEAT.md 小巧
