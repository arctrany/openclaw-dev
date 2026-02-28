# Agent 创建指南

交互式创建新 OpenClaw Agent，包含 workspace、bindings、persona 文件和安全配置。

## 需求收集

1. **Agent ID** — kebab-case, 3-50 chars (例: `code-reviewer`, `support-bot`)
2. **Agent 用途** — 这个 agent 做什么？
3. **Model** — `anthropic/claude-opus-4-6` / `anthropic/claude-sonnet-4-5` / 其他
4. **委派角色** — Standalone / Master (委派给 workers) / Worker (接收任务)
5. **安全** — Sandbox mode: `none` / `lenient` / `strict`

## 环境检查

```bash
# 验证配置存在
[ -f ~/.openclaw/openclaw.json ] || { echo "ERROR: 先运行 'openclaw onboard'"; exit 1; }

# 列出现有 agent
jq -r '.agents.list[] | "\(.id) — \(.model // "default")"' ~/.openclaw/openclaw.json

# 检查是否已存在
AGENT_ID="<agent-id>"
jq -e ".agents.list[] | select(.id==\"$AGENT_ID\")" ~/.openclaw/openclaw.json >/dev/null 2>&1 && echo "WARNING: Agent '$AGENT_ID' already exists"
```

## 创建 Workspace

```bash
WORKSPACE="$HOME/.openclaw/workspace-$AGENT_ID"
mkdir -p "$WORKSPACE/skills"
mkdir -p "$WORKSPACE/SOUL"
```

## 创建 Persona 文件

**SOUL.md** — Agent 身份和行为:
```markdown
# <Agent Name>
You are <agent purpose>.
## Core Behaviors
- <key behavior 1>
## Constraints
- <constraint 1>
```

**AGENTS.md** (如果有委派):
```markdown
# Delegation Rules
## Available Workers
- `<worker-id>`: <what it does>
## When to Delegate
- <delegation criteria>
```

**USER.md** — 用户偏好:
```markdown
# User Preferences
- Respond in <language>
```

## 更新 openclaw.json

```json5
{
  id: "<agent-id>",
  name: "<Agent Name>",
  workspace: "~/.openclaw/workspace-<agent-id>",
  model: "<provider/model-name>",
  // Master:
  subagents: { allowAgents: ["<worker-ids>"] },
  // Sandbox:
  sandbox: { mode: "<lenient|strict>", scope: "agent" },
}
```

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak
jq '.agents.list += [<new-agent-json>]' ~/.openclaw/openclaw.json > /tmp/openclaw.json.tmp \
  && mv /tmp/openclaw.json.tmp ~/.openclaw/openclaw.json
```

## Bindings (可选)

```json5
{
  bindings: [{
    agents: ["<agent-id>"],
    channels: ["telegram"],
    peers: ["<phone-number>"],  // 可选过滤
  }],
}
```

## 重启验证

```bash
pkill -TERM openclaw-gateway
sleep 3
openclaw agents list --bindings
openclaw health
```

## 完成报告

```
Agent created: <agent-id>
  Workspace: ~/.openclaw/workspace-<agent-id>
  Model:     <provider/model-name>
  Role:      <standalone | master | worker>
  Sandbox:   <none | lenient | strict>
  Bindings:  <channel list or "none">
  Status:    Gateway restarted, agent active
```
