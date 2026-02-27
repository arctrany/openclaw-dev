---
name: openclaw-agent-development
description: "Use this skill when asked to create an OpenClaw agent, configure multi-agent routing, set up agent bindings, design agent workspaces, configure per-agent security/sandbox/tools, understand agent delegation (sessions_spawn), or troubleshoot agent routing. Covers the real OpenClaw agent system: agents.list[] config in openclaw.json, bindings, workspace isolation, SOUL.md/AGENTS.md/USER.md persona files, per-agent model/tools/sandbox, and inter-agent communication."
metadata: {"clawdbot":{"always":false,"emoji":"🤖"}}
version: 2.0.0
---

# OpenClaw Agent Development

## 什么是 Agent？

Agent 是 OpenClaw Gateway 中一个**完全隔离的 AI 大脑**，拥有独立的：

| 资源 | 路径 |
|------|------|
| **Workspace** | `~/.openclaw/workspace-<agentId>/` (SOUL.md, AGENTS.md, USER.md, skills/) |
| **State** | `~/.openclaw/agents/<agentId>/agent/` (auth profiles, model registry) |
| **Sessions** | `~/.openclaw/agents/<agentId>/sessions/` (conversation history) |

Gateway 可托管**单 agent**（默认 `main`）或**多 agent** 并行。

## Agent 配置

Agent 在 `~/.openclaw/openclaw.json` → `agents.list[]` 中定义：

### 最小配置

```json5
{
  agents: {
    list: [
      { id: "main", default: true }
    ],
  },
}
```

### 完整配置示例

```json5
{
  agents: {
    defaults: {
      model: "anthropic/claude-sonnet-4-5",  // 所有 agent 默认 model
    },
    list: [
      {
        id: "personal",
        name: "Personal",
        default: true,
        workspace: "~/.openclaw/workspace-personal",
        agentDir: "~/.openclaw/agents/personal/agent",
        model: "anthropic/claude-opus-4-6",  // 覆盖默认
        identity: { name: "My AI" },
        groupChat: {
          mentionPatterns: ["@myai", "@AI"],
        },
        sandbox: {
          mode: "off",
        },
        // 无 tools 限制 = 全部可用
      },
      {
        id: "family",
        name: "Family Bot",
        workspace: "~/.openclaw/workspace-family",
        identity: { name: "Family Bot" },
        groupChat: {
          mentionPatterns: ["@family", "@familybot"],
        },
        sandbox: {
          mode: "all",
          scope: "agent",
          docker: {
            setupCommand: "apt-get update && apt-get install -y git curl",
          },
        },
        tools: {
          allow: ["exec", "read", "sessions_list", "session_status"],
          deny: ["write", "edit", "apply_patch", "browser", "canvas", "cron"],
        },
      },
    ],
  },
}
```

### agents.list[] 字段参考

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | string | **必填**。Agent 标识符，kebab-case |
| `name` | string | 显示名称 |
| `default` | boolean | 默认 agent（fallback 路由） |
| `workspace` | string | Workspace 目录路径 |
| `agentDir` | string | State 目录路径 |
| `model` | string | 模型覆盖 (`provider/model-name`) |
| `identity.name` | string | Agent 名字 |
| `groupChat.mentionPatterns` | string[] | 群组 @mention 匹配 |
| `sandbox.mode` | string | `off` / `all` (沙盒模式) |
| `sandbox.scope` | string | `agent` / `shared` (容器范围) |
| `sandbox.docker.setupCommand` | string | 容器创建后一次性安装命令 |
| `tools.allow` | string[] | 工具白名单 |
| `tools.deny` | string[] | 工具黑名单 (deny 优先) |
| `heartbeat` | object | Per-agent 心跳配置 |
| `subagents.allowAgents` | string[] | 允许委派到的 agent ID 列表 |

## 创建 Agent

### 交互式向导（推荐）

```bash
openclaw agents add coding
```

向导会创建 workspace、agentDir、session store，并提示添加 bindings。

### 手动创建

```bash
# 1. 在 openclaw.json 中添加 agents.list[] 条目
# 2. 创建 workspace
mkdir -p ~/.openclaw/workspace-coding

# 3. 创建 persona 文件
cat > ~/.openclaw/workspace-coding/SOUL.md << 'EOF'
You are a focused coding assistant.
You prefer clean, minimal solutions.
You always explain your reasoning.
EOF

cat > ~/.openclaw/workspace-coding/AGENTS.md << 'EOF'
# Agent Workflow
- Always read before writing
- Run tests after changes
- Commit with descriptive messages
EOF

# 4. 重启 Gateway
openclaw gateway restart

# 5. 验证
openclaw agents list --bindings
```

## Workspace 人格文件

| 文件 | 用途 | 注意 |
|------|------|------|
| `SOUL.md` | 人格、语气、边界 | 每个 session 加载 |
| `AGENTS.md` | 操作指令、工作流规则 | 每个 session 加载 |
| `USER.md` | 用户信息、称呼 | 每个 session 加载 |
| `IDENTITY.md` | Agent 名字、emoji | Bootstrap 时 |
| `TOOLS.md` | 工具使用约定 | 每个 session 加载 |
| `MEMORY.md` | 长期记忆索引 | Main session 加载 |
| `skills/` | Per-agent skills | 最高优先级 |

**关键**: Workspace 是 agent 的默认 cwd，不是硬沙盒。除非启用 sandboxing，绝对路径可以访问其他位置。

## Bindings (消息路由)

Bindings 将入站消息路由到特定 agent：

```json5
{
  bindings: [
    // 最具体的规则优先
    {
      agentId: "opus",
      match: {
        channel: "whatsapp",
        peer: { kind: "direct", id: "+15551234567" },
      },
    },
    // Channel 级别 fallback
    { agentId: "chat", match: { channel: "whatsapp" } },
    // 账号级别绑定
    { agentId: "coding", match: { channel: "discord", accountId: "coding" } },
  ],
}
```

### 路由优先级 (高 → 低)

1. `peer` (精确 DM/group/channel ID)
2. `parentPeer` (thread 继承)
3. `guildId + roles` (Discord role)
4. `guildId` (Discord)
5. `teamId` (Slack)
6. `accountId`
7. `channel` (accountId: "*")
8. 默认 agent (`agents.list[].default`)

多条规则匹配同一 tier → 配置顺序取胜。

### 常见路由模式

**按渠道分流**:
```json5
bindings: [
  { agentId: "chat", match: { channel: "whatsapp" } },
  { agentId: "opus", match: { channel: "telegram" } },
]
```

**同渠道按联系人分流**:
```json5
bindings: [
  { agentId: "alex", match: { channel: "whatsapp", peer: { kind: "direct", id: "+15551230001" } } },
  { agentId: "mia", match: { channel: "whatsapp", peer: { kind: "direct", id: "+15551230002" } } },
]
```

**按 Discord bot 分流**:
```json5
bindings: [
  { agentId: "main", match: { channel: "discord", accountId: "default" } },
  { agentId: "coding", match: { channel: "discord", accountId: "coding" } },
]
```

## Agent 间通信

### Agent-to-Agent 消息 (sessions_send)

默认**关闭**。需显式启用:

```json5
{
  tools: {
    agentToAgent: {
      enabled: true,
      allow: ["personal", "work"],  // 允许通信的 agent 列表
    },
  },
}
```

### 委派子 Agent (sessions_spawn)

```json5
{
  agents: {
    list: [
      {
        id: "main",
        subagents: {
          allowAgents: ["coding", "research"],  // 可委派到的 agent
        },
      },
    ],
  },
}
```

⚠️ **Auth profiles 不共享**。每个 agent 读取自己的 `~/.openclaw/agents/<agentId>/agent/auth-profiles.json`。如需共享凭证，手动复制。

## 模型配置

```
agents.defaults.model (全局默认)
  → agents.list[].model (per-agent 覆盖)
```

模型格式: `provider/model-name`

```json5
{
  agents: {
    defaults: { model: "anthropic/claude-sonnet-4-5" },
    list: [
      { id: "chat", model: "anthropic/claude-sonnet-4-5" },
      { id: "opus", model: "anthropic/claude-opus-4-6" },
      { id: "fast", model: "anthropic/claude-haiku-3-5" },
    ],
  },
}
```

## Per-Agent 安全

### 工具限制

```json5
{
  agents: {
    list: [{
      id: "restricted",
      tools: {
        allow: ["read", "exec"],        // 白名单
        deny: ["write", "edit", "cron"], // 黑名单 (deny wins)
      },
    }],
  },
}
```

### 沙盒

```json5
{
  agents: {
    list: [{
      id: "untrusted",
      sandbox: {
        mode: "all",       // off | all
        scope: "agent",    // agent (独立容器) | shared
      },
    }],
  },
}
```

⚠️ `tools.elevated` 是**全局**配置，不能 per-agent。如需限制，用 `tools.deny` 禁止 `exec`。

## 验证与调试

```bash
# 列出所有 agent 及绑定
openclaw agents list --bindings

# 检查 channel 连接
openclaw channels status --probe

# 检查特定 agent session
ls ~/.openclaw/agents/<agentId>/sessions/*.jsonl

# 查看路由决策日志
openclaw gateway --verbose
```

## 常见问题

| 问题 | 原因 | 修复 |
|------|------|------|
| 消息路由到错误 agent | Binding 优先级不对 | 更具体的规则放前面 |
| Agent 无响应 | 无匹配 binding | `openclaw agents list --bindings` 检查 |
| Auth 失败 | Agent 无 auth profile | 复制或创建 `auth-profiles.json` |
| Session 混乱 | 共享 agentDir | 确保每个 agent 有独立 agentDir |
| Skills 不加载 | Workspace 路径错误 | 检查 `agents.list[].workspace` |

## Additional Resources

- **`references/system-prompt-examples.md`** — SOUL.md 和 AGENTS.md 的实际生产示例
