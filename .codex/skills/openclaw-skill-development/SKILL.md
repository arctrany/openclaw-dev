---
name: openclaw-skill-development
description: "Guided workflow for creating, validating, deploying, and evolving OpenClaw skills. Use when asked to 'create a skill', 'build a SKILL.md', 'develop an agent skill', 'validate skill', 'deploy skill', 'evolve skill', 'improve skill from usage data', 'analyze session logs for skill performance', 'upgrade skills based on usage', 'list skills', 'show installed skills', 'what skills are available', or any skill lifecycle task. Covers: requirements, scaffolding, frontmatter, deployment, session verification, data-driven evolution, and skill inventory."
metadata: {"clawdbot":{"always":false,"emoji":"🛠️","requires":{"bins":["jq"]}}}
user-invocable: true
version: 3.0.0
---

# OpenClaw Skill Development — Standard Operating Procedure

Follow this process for every OpenClaw skill development task. No shortcuts.

## Architecture Overview

OpenClaw skills are modular capability packages defined by a `SKILL.md` file. They are loaded into an agent's system prompt to extend its capabilities.

### Skill Resolution Order (highest precedence first)

1. **Workspace skills**: `<agent-workspace>/skills/<skill-name>/SKILL.md`
2. **Managed skills**: `~/.openclaw/skills/<skill-name>/SKILL.md`
3. **Bundled skills**: `<openclaw-install>/skills/<skill-name>/SKILL.md`

Higher precedence overrides lower. Workspace skills are per-agent (configured via `openclaw.json` → `agents.list[].workspace`).

### Key Files

| File | Purpose |
|------|---------|
| `~/.openclaw/openclaw.json` | Main config. Agent definitions, workspace paths, models |
| `<workspace>/skills/*/SKILL.md` | Skill definitions |
| `<workspace>/SOUL.md` | Agent personality |
| `<workspace>/TOOLS.md` | Tool usage guidance |
| `<workspace>/AGENTS.md` | Workflow and delegation rules |
| `<workspace>/MEMORY.md` | Persistent memory index |
| `<workspace>/memory/*.md` | Memory entries |

## Phase 1: Requirements

Before writing any code, gather these:

1. **Target agent** — which agent gets this skill? (check `openclaw.json` → `agents.list`)
2. **Workspace path** — where does that agent's workspace live? (check `agents.list[].workspace`)
3. **Skill purpose** — what capability does this add?
4. **Trigger mode** — always-on (`metadata.clawdbot.always: true`) or on-demand (user-invocable / model-triggered)?
5. **Dependencies** — does it require binaries (`requires.bins`), env vars (`requires.env`), or config (`requires.config`)?
6. **Scope** — agent-specific (workspace skill) or global (managed skill)?

### Find agent workspace
```bash
jq '.agents.list[] | {id, workspace, model}' ~/.openclaw/openclaw.json
```

## Phase 2: Design

### SKILL.md Anatomy

```
skill-name/
├── SKILL.md          # Required — YAML frontmatter + markdown instructions
├── scripts/          # Optional — executable code
├── references/       # Optional — docs loaded on-demand
└── assets/           # Optional — files used in output
```

### SKILL.md Format

```markdown
---
name: skill-name
description: What this skill does and WHEN to use it. This is the primary trigger — be specific and comprehensive.
metadata: {"clawdbot":{"always":false,"emoji":"🔧","requires":{"bins":["jq"]}}}
user-invocable: true
---

# Skill Title

Instructions for the agent...
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Lowercase kebab-case, matches directory name |
| `description` | Yes | Primary trigger mechanism. Include WHAT it does AND WHEN to use it. The body is only loaded after triggering. |
| `metadata` | No | JSON string with OpenClaw-specific config (see below) |
| `user-invocable` | No | `true` = user can trigger via `/skill-name` command |

### Metadata Object (`metadata.clawdbot`)

| Key | Type | Description |
|-----|------|-------------|
| `always` | boolean | Auto-inject into every session's system prompt |
| `emoji` | string | Display emoji for the skill |
| `skillKey` | string | Config key in `openclaw.json` → `skills.entries` |
| `primaryEnv` | string | Primary env var (for API key gating) |
| `os` | string[] | OS filter: `["darwin"]`, `["linux"]`, etc. |
| `requires.bins` | string[] | ALL listed binaries must exist |
| `requires.anyBins` | string[] | At least ONE listed binary must exist |
| `requires.env` | string[] | Required environment variables |
| `requires.config` | string[] | Required config paths in openclaw.json |
| `install` | array | Auto-install specs (brew/node/go/uv/download) |

### Design Rules

1. **Context window is a public good** — skills share the prompt with everything else. Keep SKILL.md under 500 lines. Challenge every paragraph: "Does the agent really need this?"
2. **Description is the trigger** — the body only loads AFTER triggering. All "when to use" info goes in `description`, not the body.
3. **Progressive disclosure** — Level 1: metadata (~100 words, always loaded). Level 2: SKILL.md body (<5k words, loaded on trigger). Level 3: references/ (unlimited, loaded on demand).
4. **Imperative voice** — write instructions in imperative form ("Run X", "Check Y"), not descriptive ("This skill runs X").
5. **No extraneous files** — no README.md, CHANGELOG.md, INSTALLATION_GUIDE.md. Only SKILL.md and functional resources.

## Phase 3: Implement

### Step 1: Create skill directory

```bash
WORKSPACE=$(jq -r '.agents.list[] | select(.id=="<agent-id>") | .workspace' ~/.openclaw/openclaw.json)
WORKSPACE=$(eval echo "$WORKSPACE")  # expand ~
mkdir -p "$WORKSPACE/skills/<skill-name>"
```

### Step 2: Write SKILL.md

Follow the format above. Key checks:
- [ ] `name` matches directory name exactly
- [ ] `description` is comprehensive (includes triggers/contexts)
- [ ] `metadata` is valid JSON (use `echo '...' | jq .` to verify)
- [ ] Body uses imperative voice
- [ ] Under 500 lines
- [ ] No "When to use" section in body (that belongs in description)
- [ ] References large content to `references/` files

### Step 3: Add resources (if needed)

- `scripts/` — executable code that would be rewritten each time
- `references/` — docs the agent reads on demand (keep SKILL.md lean)
- `assets/` — templates, images, files used in output

## Phase 4: Validate

Run these checks before considering the skill ready:

### Structural validation
```bash
SKILL_DIR="$WORKSPACE/skills/<skill-name>"

# 1. SKILL.md exists
test -f "$SKILL_DIR/SKILL.md" && echo "OK: SKILL.md exists" || echo "FAIL: Missing SKILL.md"

# 2. Frontmatter has required fields
head -20 "$SKILL_DIR/SKILL.md" | grep -q "^name:" && echo "OK: has name" || echo "FAIL: missing name"
head -20 "$SKILL_DIR/SKILL.md" | grep -q "^description:" && echo "OK: has description" || echo "FAIL: missing description"

# 3. Name matches directory
DIRNAME=$(basename "$SKILL_DIR")
SKILLNAME=$(head -20 "$SKILL_DIR/SKILL.md" | grep "^name:" | sed 's/name: *//')
[ "$DIRNAME" = "$SKILLNAME" ] && echo "OK: name matches dir" || echo "FAIL: name '$SKILLNAME' != dir '$DIRNAME'"

# 4. Metadata JSON is valid (if present)
META=$(head -20 "$SKILL_DIR/SKILL.md" | grep "^metadata:" | sed 's/metadata: *//')
if [ -n "$META" ]; then
  echo "$META" | jq . > /dev/null 2>&1 && echo "OK: valid metadata JSON" || echo "FAIL: invalid metadata JSON"
fi

# 5. Line count check
LINES=$(wc -l < "$SKILL_DIR/SKILL.md")
[ "$LINES" -le 500 ] && echo "OK: $LINES lines (under 500)" || echo "WARN: $LINES lines (over 500, consider splitting)"
```

### Dependency validation
```bash
# Check required binaries exist
META=$(head -20 "$SKILL_DIR/SKILL.md" | grep "^metadata:" | sed 's/metadata: *//')
if [ -n "$META" ]; then
  for bin in $(echo "$META" | jq -r '.clawdbot.requires.bins[]? // empty'); do
    which "$bin" > /dev/null 2>&1 && echo "OK: $bin found" || echo "FAIL: $bin not found"
  done
fi
```

## Phase 5: Deploy & Verify

### Deploy

The skill is already in the workspace directory. No copy needed. But the agent needs a new session to pick it up.

### Restart gateway (if config changed)
```bash
# Only needed if openclaw.json was modified (e.g., workspace path changed)
pkill -TERM openclaw-gateway
sleep 3
# Gateway should auto-restart via launchd/systemd. If not:
# openclaw-gateway &
```

### Trigger new session

Send `/new` to the agent via its messaging platform (Telegram, Discord, etc.). This creates a fresh session that re-resolves skills from the workspace.

### Verify skills loaded

```bash
# Check session snapshot includes the new skill
AGENT_ID="<agent-id>"
cat ~/.openclaw/agents/$AGENT_ID/sessions/sessions.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
session = data.get('agent:${AGENT_ID}:main', {})
prompt = session.get('skillsSnapshot', {}).get('prompt', '')
skill = '<skill-name>'
if skill in prompt:
    print(f'FOUND: {skill} loaded in session')
else:
    print(f'NOT FOUND: {skill} — check workspace path and gateway')
"
```

### Verify skill content in session
```bash
# Check the latest session log for skill awareness
LATEST=$(ls -t ~/.openclaw/agents/$AGENT_ID/sessions/*.jsonl | head -1)
tail -5 "$LATEST" | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        obj = json.loads(line.strip())
        role = obj.get('message', {}).get('role', '')
        if role == 'assistant':
            content = obj.get('message', {}).get('content', '')
            if isinstance(content, list):
                for c in content:
                    if c.get('type') == 'text':
                        print(c['text'][:300])
            elif isinstance(content, str):
                print(content[:300])
    except: pass
"
```

## Common Pitfalls (from real experience)

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Skill in wrong directory | Not loaded in session | Verify agent's `workspace` in openclaw.json, put skill in `<workspace>/skills/` |
| Skill in shared workspace | Affects all agents | Use per-agent workspace via `agents.list[].workspace` |
| Gateway not restarted | Old session, old skills | `pkill -TERM openclaw-gateway`, wait for auto-restart |
| Session not refreshed | Skills in config but not in prompt | Send `/new` to agent to create fresh session |
| `metadata` not valid JSON | Skill loads but flags ignored | Test with `echo '<metadata>' \| jq .` |
| Description too vague | Skill never triggers | Include specific trigger phrases and contexts |
| Body too long | Context bloat | Move details to `references/` files, keep body < 500 lines |
| `always: true` on optional skill | Wastes context every session | Only use `always` for core behavioral skills |
| No dependency check | Skill fails at runtime | Use `requires.bins` / `requires.anyBins` in metadata |
| Memory files not preserved | Agent loses history during migration | Always copy `memory/` and `MEMORY.md` when migrating workspaces |

## Skill Categories & Templates

### Category A: Behavioral Protocol (always-on)
Skills that define HOW the agent works. Examples: task execution protocol, communication standards.
- `always: true` — always in system prompt
- No `user-invocable` — not triggered manually
- Keep extremely concise — loaded every single session

### Category B: Tool Integration (model-triggered)
Skills that teach the agent to use a specific tool. Examples: coding-agent, oracle, email.
- `always: false` — loaded only when relevant
- Comprehensive `description` with trigger phrases
- Include tool-specific examples and flags

### Category C: User Command (user-invocable)
Skills triggered by user via slash command. Examples: /insights, /deploy.
- `user-invocable: true`
- Clear command syntax in body
- May also be model-triggered if description matches

### Category D: Self-Improvement (hybrid)
Skills that analyze and optimize the agent. Examples: self-evolve, session analytics.
- Both `always: true` (for heartbeat mode) and `user-invocable: true` (for deep mode)
- Reads session logs at `~/.openclaw/agents/<id>/sessions/*.jsonl`
- Tracks state in `memory/` directory

## Additional Resources

This skill now includes comprehensive supporting resources for progressive disclosure:

### Utility Scripts (`scripts/`)

**Validation and deployment utilities** (all support local and remote agents):

- **`scripts/validate-skill.sh`** - Validate skill structure and metadata
  ```bash
  # Local validation
  ./scripts/validate-skill.sh /path/to/skill-name

  # Validate in agent workspace
  ./scripts/validate-skill.sh -a momiji skill-name

  # Validate on remote agent
  ./scripts/validate-skill.sh -r user@remote-host -a momiji skill-name
  ```

- **`scripts/deploy-skill.sh`** - Deploy skill to local or remote agent
  ```bash
  # Deploy locally
  ./scripts/deploy-skill.sh ./my-skill momiji

  # Deploy to remote agent (rsync)
  ./scripts/deploy-skill.sh -r user@remote-host ./my-skill momiji

  # Deploy to remote agent (git)
  ./scripts/deploy-skill.sh -m git -r user@remote-host my-skill momiji
  ```

- **`scripts/verify-skill-loaded.sh`** - Verify skill loaded in agent session
  ```bash
  # Verify local agent
  ./scripts/verify-skill-loaded.sh -a momiji skill-name

  # Verify remote agent
  ./scripts/verify-skill-loaded.sh -r user@remote-host -a momiji skill-name
  ```

**Key features**:
- ✅ No hardcoded paths - all paths resolved dynamically
- ✅ Support for remote OpenClaw agents via SSH
- ✅ 3 deployment methods: rsync/scp/git
- ✅ Comprehensive validation and verification

### Reference Documentation (`references/`)

**Detailed guides for progressive disclosure** (load when needed):

- **`references/advanced-patterns.md`** - Advanced skill development patterns
  - Progressive disclosure strategies
  - Advanced metadata configuration
  - Remote deployment patterns
  - Multi-agent skill distribution
  - Security and performance optimization

- **`references/troubleshooting-guide.md`** - Common issues and solutions
  - Skill not loading issues
  - Deployment failures
  - Validation errors
  - Remote agent issues
  - Performance problems
  - Comprehensive diagnostic procedures

- **`references/real-world-examples.md`** - Production skill examples
  - Complete working examples from production
  - Deployment workflows (local/remote/multi-agent)
  - Pattern explanations and use cases

### Working Examples (`examples/`)

**Complete, copy-paste skill templates**:

- **`examples/behavioral-protocol.md`** - Category A: Always-on behavioral skill
  - Example: task-execution-protocol
  - Ultra-concise (<300 lines)
  - Imperative rules

- **`examples/tool-integration.md`** - Category B: Tool integration skill
  - Example: api-client-integration
  - Comprehensive trigger phrases
  - Tool-specific commands

- **`examples/user-command.md`** - Category C: User-invocable command
  - Example: deploy command
  - Interactive workflow
  - Error handling

- **`examples/self-improvement.md`** - Category D: Self-improvement skill
  - Example: self-evolve
  - Dual mode (heartbeat + deep)
  - Session log analysis

## Quick Reference

For comprehensive quick reference including:
- Minimal viable SKILL.md templates
- Common metadata patterns
- Validation checklists
- Deployment commands (local/remote/multi-agent)
- Troubleshooting one-liners
- Component organization guidelines
- Script usage examples

**Read**: `references/quick-reference.md`

---

For detailed patterns and techniques, consult the reference files and examples above.

## Skill 清单查询

需要查看当前已安装的所有 skill（workspace 级 + managed 级 + bundled 级）时，读取 `references/list-skills-runbook.md`。

