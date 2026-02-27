---
name: scaffold-agent
description: Interactive workflow to create a new OpenClaw agent with workspace, bindings, persona files, and security configuration.
argument-hint: [agent-id]
---

# Scaffold OpenClaw Agent

Guide the user through adding a new agent to their OpenClaw Gateway.

## Step 1: Gather Requirements

Ask the user:

1. **Agent ID** (if not provided as $1)
   - Must be kebab-case, 3-50 chars
   - Examples: `code-reviewer`, `support-bot`, `deploy-worker`

2. **Agent purpose** — What does this agent do?

3. **Model**
   - `anthropic/claude-opus-4-6` (complex tasks)
   - `anthropic/claude-sonnet-4-5` (balanced, recommended)
   - Other `provider/model-name`

4. **Role in delegation**
   - Standalone (no delegation)
   - Master (delegates to workers via `sessions_spawn`)
   - Worker (receives delegated tasks)

5. **Security**
   - Sandbox mode: `none` / `lenient` / `strict`
   - Tool restrictions (optional)

## Step 2: Check Environment

```bash
# Verify OpenClaw config exists
if [ ! -f ~/.openclaw/openclaw.json ]; then
  echo "ERROR: ~/.openclaw/openclaw.json not found"
  echo "Run 'openclaw onboard' first"
  exit 1
fi

# List existing agents
jq -r '.agents.list[] | "\(.id) — \(.model // "default")"' ~/.openclaw/openclaw.json

AGENT_ID="${1:-<from user>}"

# Check if agent already exists
if jq -e ".agents.list[] | select(.id==\"$AGENT_ID\")" ~/.openclaw/openclaw.json >/dev/null 2>&1; then
  echo "WARNING: Agent '$AGENT_ID' already exists"
fi
```

## Step 3: Create Workspace

```bash
WORKSPACE="$HOME/.openclaw/workspace-$AGENT_ID"
mkdir -p "$WORKSPACE/skills"
mkdir -p "$WORKSPACE/SOUL"
```

## Step 4: Create Persona Files

Generate workspace bootstrap files:

**SOUL.md** — Agent identity and behavioral directives:
```markdown
# <Agent Name>

You are <agent purpose>.

## Core Behaviors
- <key behavior 1>
- <key behavior 2>

## Constraints
- <constraint 1>
```

**AGENTS.md** (if delegation is configured):
```markdown
# Delegation Rules

## Available Workers
- `<worker-id>`: <what it does>

## When to Delegate
- <delegation criteria>
```

**USER.md** — User preferences:
```markdown
# User Preferences

- Respond in <language>
- <other preferences>
```

## Step 5: Update openclaw.json

Add the agent entry to `agents.list[]`:

```json5
{
  id: "<agent-id>",
  name: "<Agent Name>",
  workspace: "~/.openclaw/workspace-<agent-id>",
  model: "<provider/model-name>",

  // If master:
  subagents: {
    allowAgents: ["<worker-ids>"],
  },

  // If sandbox needed:
  sandbox: {
    mode: "<lenient|strict>",
    scope: "agent",
  },

  // If tool restrictions:
  tools: {
    restricted: ["<tool-names>"],
  },
}
```

Show the user the exact JSON to add and confirm before modifying the file:

```bash
# Backup config
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak

# Add agent (using jq)
jq '.agents.list += [<new-agent-json>]' ~/.openclaw/openclaw.json > /tmp/openclaw.json.tmp \
  && mv /tmp/openclaw.json.tmp ~/.openclaw/openclaw.json
```

## Step 6: Optionally Add Bindings

If the agent should receive messages from specific channels:

```json5
{
  bindings: [
    {
      agents: ["<agent-id>"],
      channels: ["telegram"],
      // Optional filters:
      peers: ["<phone-number>"],
    },
  ],
}
```

## Step 7: Restart & Verify

```bash
# Restart Gateway to pick up new config
pkill -TERM openclaw-gateway
sleep 3

# Verify agent is registered
openclaw agents list --bindings

# Check health
openclaw health
```

## Step 8: Report

```
Agent created: <agent-id>
  Workspace: ~/.openclaw/workspace-<agent-id>
  Model:     <provider/model-name>
  Role:      <standalone | master | worker>
  Sandbox:   <none | lenient | strict>
  Bindings:  <channel list or "none">
  Status:    Gateway restarted, agent active

Next steps:
  - Send a message to the agent via bound channel
  - Or use: openclaw gateway send --agent <agent-id> "Hello"
  - Add skills: /create-skill
```
