# OpenClaw 深度参考 — Sessions, Memory, Automation, Security

## Session (会话管理)

### Session Key 映射

| 来源 | Key 格式 |
|------|----------|
| DM (default) | `agent:<agentId>:<mainKey>` |
| DM (per-channel-peer) | `agent:<agentId>:<channel>:dm:<peerId>` |
| DM (per-account-channel-peer) | `agent:<agentId>:<channel>:<accountId>:dm:<peerId>` |
| 群聊 | `agent:<agentId>:<channel>:group:<id>` |
| Cron | `cron:<jobId>` |
| Webhook | `hook:<uuid>` |
| Node | `node-<nodeId>` |

### DM 隔离 (dmScope)

```json5
{
  session: {
    dmScope: "per-channel-peer",  // 推荐多用户场景
    // 跨 channel 合并同一人:
    identityLinks: {
      alice: ["telegram:123", "discord:987654321"],
    },
  },
}
```

⚠️ 默认 `main` — 所有 DM 共享 session。多人场景必须设 `per-channel-peer`。

### 生命周期

- **Daily reset**: 默认凌晨 4:00 (Gateway host 本地时间)
- **Idle reset**: `session.reset.idleMinutes` (可选)
- 两者同时设 → 谁先过期谁触发 reset
- `/new` 或 `/reset` 手动重置

### 状态存储

```
~/.openclaw/agents/<agentId>/sessions/
├── sessions.json          # session key → metadata
└── <sessionId>.jsonl      # 完整对话记录
```

### 维护

```json5
{
  session: {
    maintenance: {
      mode: "enforce",       // warn | enforce
      pruneAfter: "30d",
      maxEntries: 500,
      rotateBytes: "10mb",
      maxDiskBytes: "1gb",
    },
  },
}
```

### 常用命令

```bash
openclaw status                      # 概览
openclaw sessions --json             # 所有 session
openclaw sessions cleanup --dry-run  # 预览清理
/status                              # 聊天中查状态
/context list                        # 系统提示内容
/compact                             # 手动压缩
/stop                                # 终止当前 run
```

---

## Memory (记忆系统)

### 文件层

```
workspace/
├── memory/YYYY-MM-DD.md    # 每日记忆 (append-only)
└── MEMORY.md               # 长期记忆 (仅 main session 加载)
```

- 决策/偏好/持久事实 → `MEMORY.md`
- 日常笔记/上下文 → `memory/YYYY-MM-DD.md`
- Session 开始自动读 today + yesterday

### 自动 flush

Session 接近 compaction 时自动触发静默 turn，提醒 model 写记忆到磁盘。

### 向量搜索

```json5
{
  agents: {
    defaults: {
      memorySearch: {
        provider: "openai",  // openai | gemini | voyage | mistral | local
        model: "text-embedding-3-small",
        query: {
          hybrid: {
            enabled: true,
            vectorWeight: 0.7,
            textWeight: 0.3,
            mmr: { enabled: true, lambda: 0.7 },
            temporalDecay: { enabled: true, halfLifeDays: 30 },
          },
        },
      },
    },
  },
}
```

| 功能 | 说明 |
|------|------|
| **Hybrid** | BM25 (关键词) + Vector (语义) 融合 |
| **MMR** | 去重，避免相似片段重复 |
| **Temporal decay** | 旧记忆分数衰减 (半衰期 30d) |
| **QMD** | 可选本地 sidecar (BM25+vectors+reranking) |

### 工具

- `memory_search` — 语义搜索 (snippets + file + line)
- `memory_get` — 读指定文件/行范围

---

## Automation (自动化)

### Cron Jobs

Gateway 内建调度器。Jobs 持久化在 `~/.openclaw/cron/jobs.json`。

#### 两种执行模式

| 模式 | Session | Payload | 场景 |
|------|---------|---------|------|
| **Main** | main session | systemEvent | 心跳中执行 |
| **Isolated** | `cron:<jobId>` | agentTurn | 独立 turn，不影响主聊天 |

#### 快速创建

```bash
# 一次性提醒
openclaw cron add --name "Reminder" --at "20m" \
  --session main --system-event "Check calendar" --wake now

# 定期查 isolated job + 投递到 WhatsApp
openclaw cron add --name "Morning brief" --cron "0 7 * * *" \
  --tz "America/Los_Angeles" --session isolated \
  --message "Summarize overnight updates." \
  --announce --channel whatsapp --to "+15551234567"

# 带模型覆盖
openclaw cron add --name "Deep analysis" --cron "0 6 * * 1" \
  --session isolated --model "opus" --thinking high \
  --message "Weekly analysis" --announce
```

#### 投递模式

| delivery.mode | 行为 |
|---------------|------|
| `announce` | 投递到指定 channel (默认) |
| `webhook` | POST 到 URL |
| `none` | 仅内部执行 |

#### 管理

```bash
openclaw cron list
openclaw cron run <jobId>
openclaw cron edit <jobId> --message "Updated"
openclaw cron runs --id <jobId>
```

### Heartbeat

- `/heartbeat` 内部调度 (non-cron)
- `HEARTBEAT.md` 定义心跳清单
- `wakeMode: "now"` vs `"next-heartbeat"` 控制唤醒时机

---

## Security (安全)

### 信任模型

**个人助手模型** — 每个 Gateway 一个信任边界。不支持敌对多租户。

### 安全审计

```bash
openclaw security audit          # 快速审计
openclaw security audit --deep   # 深度 (含 Gateway 探针)
openclaw security audit --fix    # 自动修复
```

### 加固基线 (60s)

```json5
{
  gateway: { mode: "local", bind: "loopback",
    auth: { mode: "token", token: "long-random-token" } },
  session: { dmScope: "per-channel-peer" },
  tools: {
    profile: "messaging",
    deny: ["group:automation", "group:runtime", "group:fs",
           "sessions_spawn", "sessions_send"],
    fs: { workspaceOnly: true },
    exec: { security: "deny", ask: "always" },
    elevated: { enabled: false },
  },
  channels: {
    whatsapp: { dmPolicy: "pairing",
      groups: { "*": { requireMention: true } } },
  },
}
```

### Credential 存储

| 路径 | 内容 |
|------|------|
| `~/.openclaw/credentials/whatsapp/<account>/` | WhatsApp session |
| `~/.openclaw/agents/<id>/agent/auth-profiles.json` | Model API keys |
| `~/.openclaw/secrets.json` | 可选 file-backed secrets |
| `~/.openclaw/openclaw.json` | 所有配置 (含 token) |

### 权限加固

```bash
chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/openclaw.json
```

---

## Sandboxing (沙盒)

可选 Docker 容器隔离。Gateway 留在 host，工具在容器中执行。

### 模式

| mode | 说明 |
|------|------|
| `off` | 无沙盒 |
| `non-main` | 仅非 main session |
| `all` | 所有 session |

### Scope

| scope | 容器 |
|-------|------|
| `session` | 每 session 一个 |
| `agent` | 每 agent 一个 |
| `shared` | 所有共享一个 |

### Workspace 访问

| workspaceAccess | 行为 |
|-----------------|------|
| `none` | 沙盒独立 workspace |
| `ro` | 只读挂载 agent workspace 到 `/agent` |
| `rw` | 读写挂载到 `/workspace` |

### 最小配置

```json5
{
  agents: {
    defaults: {
      sandbox: {
        mode: "non-main",
        scope: "session",
        workspaceAccess: "none",
      },
    },
  },
}
```

### Setup

```bash
scripts/sandbox-setup.sh          # 构建沙盒镜像
scripts/sandbox-browser-setup.sh  # 构建浏览器沙盒
```

### 调试

```bash
openclaw sandbox explain  # 查看生效的沙盒模式和策略
```

### 注意

- 默认容器**无网络** (`network: "none"`)
- `setupCommand` 需要网络和 root
- `tools.elevated` 绕过沙盒直接在 host 执行
- `network: "host"` 被禁止
