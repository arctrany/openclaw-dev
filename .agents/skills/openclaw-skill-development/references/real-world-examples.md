# Real-World OpenClaw Skill Examples

This document showcases actual OpenClaw skills from production deployments, demonstrating best practices and proven patterns.

## Example 1: Behavioral Protocol Skill (Always-On)

### hao-protocol (Task Execution Standard)

**File**: `hao-protocol/SKILL.md`

**Frontmatter**:
```yaml
---
name: hao-protocol
description: Task execution protocol. Classifies tasks by complexity, auto-delegates to coding agents or orchestration tools, handles errors with retry/fallback escalation, monitors long-running work, and reports only with verified evidence.
metadata: {"clawdbot":{"always":true,"emoji":"⚡"}}
---
```

**Key Features**:
- `always: true` - loaded in every session
- Ultra-concise (269 lines)
- Clear decision trees for task classification
- Defines agent's core behavior
- No `user-invocable` - not manually triggered

**Body Structure** (simplified):
```markdown
# Hao Protocol — Task Execution Standard

You follow this protocol for EVERY task. No exceptions.

## Rule 1: Evidence Only
- Never say "I will try"
- Verify before reporting: ls, cat, curl
- Every report includes proof

## Rule 2: Auto-Classify & Delegate
| Signal | Type | Action |
|--------|------|--------|
| Single-step | A (Simple) | Do → Verify → Report |
| Code task | B (Code) | Delegate to coding-agent |
| 2+ tasks | B (Parallel) | Orchestrate via tmux |

## Rule 3: Never Stop on Error
1. RETRY - adjust params
2. PLAN B - switch approach
3. REPORT - only after 1 & 2 fail

## Communication Format
[Structured templates for reports]
```

**Why This Works**:
- Extremely concise - must be loaded every session
- Imperative rules, not explanations
- Clear decision points
- Agent behavioral foundation

**When to Use This Pattern**:
- Core agent behavior protocols
- Communication standards
- Task execution workflows
- Always-on behavioral rules

---

## Example 2: Tool Integration Skill (Model-Triggered)

### coding-agent (AI Code Generation)

**Frontmatter**:
```yaml
---
name: coding-agent
description: "This skill should be used when the user asks to 'run codex', 'use AI coder', 'delegate to coding agent', 'write code with AI', 'generate implementation', or mentions code generation tasks requiring >20 lines of code or multi-file changes."
metadata: {"clawdbot":{"always":false,"emoji":"💻","requires":{"bins":["codex"]}}}
user-invocable: false
---
```

**Key Features**:
- `always: false` - loaded only when triggered
- Comprehensive trigger phrases
- Requires `codex` binary
- Not user-invocable (model decides)

**Body Structure** (simplified):
```markdown
# Coding Agent Integration

Use the codex binary for code generation tasks.

## When to Delegate
- Writing >20 lines of code
- Multi-file refactoring
- Building new features
- Complex algorithms

## Command Syntax
bash pty:true background:true workdir:<path> command:"codex exec --full-auto '<task>. When done, run: clawdbot gateway wake --text \"Done: <summary>\" --mode now'"

## Best Practices
1. Always background complex work
2. Always append wake trigger
3. Provide clear, specific prompts
4. Monitor progress with process action:poll

## Error Handling
[Retry strategies, fallback approaches]
```

**Why This Works**:
- Clear triggering conditions with examples
- Specific command syntax with wake triggers
- Progressive disclosure (detailed patterns in references/)
- Dependency checking (`requires.bins`)

**When to Use This Pattern**:
- External tool integrations
- API wrappers
- Service connectors
- Specialized code generators

---

## Example 3: User-Invocable Command Skill

### insights (Session Analytics)

**Frontmatter**:
```yaml
---
name: insights
description: "This skill should be used when the user asks to '/insights', 'analyze my sessions', 'show me patterns', 'what have I been working on', or wants analytics on conversation history."
metadata: {"clawdbot":{"always":false,"emoji":"📊","requires":{"bins":["jq","python3"]}}}
user-invocable: true
---
```

**Key Features**:
- `user-invocable: true` - accessible via /insights
- Can be model-triggered OR user-triggered
- Requires data processing tools
- Clear command syntax

**Body Structure** (simplified):
```markdown
# Insights - Session Analytics

User triggered this via /insights command.

## What This Does
Analyzes session logs to extract:
- Top topics discussed
- Frequently used tools
- Time distribution
- Error patterns

## Command Arguments
- `/insights` - Last 7 days
- `/insights --days 30` - Last 30 days
- `/insights --export` - Export to CSV

## Analysis Process
1. Read session logs from ~/.openclaw/agents/<id>/sessions/*.jsonl
2. Extract patterns with jq and python
3. Generate visualizations
4. Present summary

## Output Format
[Structured analytics report template]
```

**Why This Works**:
- Dual triggering (user + model)
- Clear command syntax documentation
- Specific data sources (session logs path)
- Actionable output

**When to Use This Pattern**:
- User commands (/deploy, /test, /analyze)
- Interactive workflows
- Reporting tools
- On-demand operations

---

## Example 4: Self-Improvement Skill (Hybrid)

### self-evolve (Agent Optimization)

**Frontmatter**:
```yaml
---
name: self-evolve
description: "Agent self-improvement and optimization. This skill should be used when the agent needs to analyze its own performance, when user asks to 'improve yourself', 'optimize behavior', 'analyze sessions', or periodically for heartbeat analysis."
metadata: {"clawdbot":{"always":true,"emoji":"🧠"}}
user-invocable: true
---
```

**Key Features**:
- Both `always: true` AND `user-invocable: true`
- Dual mode: heartbeat (automatic) + deep analysis (user-triggered)
- Reads and writes memory files
- Self-modifying behavior

**Body Structure** (simplified):
```markdown
# Self-Evolve Protocol

## Heartbeat Mode (always: true)
Every 50 messages, analyze:
- Patterns in user feedback
- Recurring errors
- Efficiency opportunities
- Update MEMORY.md with learnings

## Deep Mode (user-invocable: true)
When user triggers /self-evolve:
1. Read ALL session logs
2. Identify improvement areas
3. Propose memory updates
4. Update SOUL.md if personality drift detected

## Session Log Analysis
Read from: ~/.openclaw/agents/<id>/sessions/*.jsonl
Parse JSON lines:
- Extract user feedback
- Identify successful patterns
- Flag failed approaches

## Memory Update Protocol
Update files:
- MEMORY.md - High-level index
- memory/patterns.md - Successful patterns
- memory/failures.md - Failed approaches to avoid
```

**Why This Works**:
- Dual mode operation (passive + active)
- Self-analyzing and self-improving
- Persistent learning via memory files
- Balances automatic and manual optimization

**When to Use This Pattern**:
- Agent self-improvement
- Session analytics
- Memory management
- Adaptive learning systems

---

## Example 5: Progressive Disclosure Skill

### openclaw-skill-development (This Skill!)

**Frontmatter**:
```yaml
---
name: openclaw-skill-development
description: "Guided workflow for creating, validating, and deploying OpenClaw (clawdbot) skills. This skill should be used when the user asks to create a skill for OpenClaw, build a SKILL.md, develop an agent skill, or mentions openclaw/clawdbot skill development. Covers the full lifecycle: requirements gathering, SKILL.md scaffolding, frontmatter validation, workspace deployment, gateway restart, and session verification."
metadata: {"clawdbot":{"always":false,"emoji":"🛠️","requires":{"bins":["jq"]}}}
user-invocable: true
---
```

**Directory Structure**:
```
openclaw-skill-development/
├── SKILL.md (279 lines - core workflow)
├── scripts/
│   ├── validate-skill.sh (validation)
│   ├── deploy-skill.sh (deployment)
│   └── verify-skill-loaded.sh (verification)
├── references/
│   ├── advanced-patterns.md (advanced techniques)
│   ├── troubleshooting-guide.md (issue resolution)
│   └── real-world-examples.md (this file)
└── examples/
    ├── behavioral-protocol.md
    ├── tool-integration.md
    ├── user-command.md
    └── self-improvement.md
```

**Key Features**:
- Lean SKILL.md (279 lines) with clear 5-phase workflow
- Detailed content in references/ (loaded on-demand)
- Working scripts in scripts/ (executable utilities)
- Complete examples in examples/ (copy-paste starting points)

**Why This Works**:
- Perfect progressive disclosure
- Core workflow always available
- Deep content when needed
- Practical utilities ready to use

---

## Example 6: Multi-Agent Coordination Skill

### agent-handoff (Task Delegation)

**Frontmatter**:
```yaml
---
name: agent-handoff
description: "This skill should be used when the task requires expertise outside current agent's domain. Examples: 'This needs a specialist', 'hand off to expert', 'delegate to another agent', 'coordinate with team'."
metadata: {"clawdbot":{"always":true,"emoji":"🔄"}}
---
```

**Body Structure**:
```markdown
# Agent Handoff Protocol

## When to Hand Off
Task requires expertise in:
- Domain outside your skills
- Language you don't speak fluently
- Tools you don't have access to
- Time zone better suited to another agent

## Handoff Process
1. Identify specialist agent
   Read: ~/.openclaw/openclaw.json → agents.list
2. Package context
   - User request
   - Work done so far
   - Specific question for specialist
3. Hand off via OpenClaw Gateway API
4. Monitor progress
5. Resume when specialist responds

## Context Packaging Format
[JSON structure for handoff]
```

**Why This Works**:
- Always-on for seamless coordination
- Clear handoff criteria
- Structured process
- Enables multi-agent workflows

---

## Example 7: Remote Deployment Skill

### deploy-to-production (Production Deployment)

**Frontmatter**:
```yaml
---
name: deploy-to-production
description: "This skill should be used when the user asks to 'deploy to production', 'push to prod', 'release to live', or mentions production deployment workflows."
metadata: {"clawdbot":{"always":false,"emoji":"🚀","requires":{"bins":["rsync","ssh"],"env":["PROD_SERVER"]}}}
user-invocable: true
---
```

**Body Structure**:
```markdown
# Deploy to Production

## Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Code reviewed and approved
- [ ] Database migrations ready
- [ ] Rollback plan prepared

## Deployment Process
1. Validate configuration
2. Run pre-deployment tests
3. Create backup
4. Deploy via rsync to $PROD_SERVER
5. Restart services
6. Run post-deployment verification
7. Monitor for errors

## Remote Deployment Command
rsync -avz --progress \
  ./build/ \
  $PROD_SERVER:/var/www/production/

## Rollback Procedure
[Emergency rollback steps]
```

**Why This Works**:
- Requires environment variable for safety
- Clear checklist prevents mistakes
- Structured process
- Rollback ready

---

## Common Patterns Summary

### Pattern 1: Always-On Behavioral
- `always: true`, no `user-invocable`
- <300 lines, ultra-concise
- Example: hao-protocol

### Pattern 2: Tool Integration
- `always: false`, comprehensive description
- Tool-specific commands and examples
- Example: coding-agent

### Pattern 3: User Command
- `user-invocable: true`
- Clear command syntax
- Example: insights

### Pattern 4: Self-Improving
- Both `always: true` AND `user-invocable: true`
- Reads/writes memory files
- Example: self-evolve

### Pattern 5: Progressive Disclosure
- Lean SKILL.md + rich references/
- Executable scripts/
- Example: openclaw-skill-development

### Pattern 6: Multi-Agent
- Always-on for coordination
- Structured handoff process
- Example: agent-handoff

### Pattern 7: Remote Operations
- Requires SSH/rsync
- Environment variables for safety
- Example: deploy-to-production

---

## Deployment Examples

### Local Deployment
```bash
# Deploy skill to local agent
./scripts/deploy-skill.sh skills/my-skill/ momiji

# Verify loaded
./scripts/verify-skill-loaded.sh -a momiji my-skill
```

### Remote Deployment (Single Agent)
```bash
# Deploy to remote agent via rsync
./scripts/deploy-skill.sh -r user@remote-host skills/my-skill/ momiji

# Verify on remote
./scripts/verify-skill-loaded.sh -r user@remote-host -a momiji my-skill
```

### Remote Deployment (Multiple Agents)
```bash
# Deploy to all agents
for agent in $(jq -r '.agents.list[].id' ~/.openclaw/openclaw.json); do
  ./scripts/deploy-skill.sh -r user@remote-host skills/my-skill/ $agent
done

# Verify all
for agent in $(jq -r '.agents.list[].id' ~/.openclaw/openclaw.json); do
  ./scripts/verify-skill-loaded.sh -r user@remote-host -a $agent my-skill
done
```

### Git-Based Deployment
```bash
# Commit and push
git add skills/my-skill/
git commit -m "Add my-skill"
git push origin main

# Deploy to remote via git pull
./scripts/deploy-skill.sh -m git -r user@remote-host my-skill momiji
```

---

## Key Takeaways

1. **Match pattern to use case**: Always-on vs on-demand, user vs model triggered
2. **Progressive disclosure**: Keep SKILL.md lean, use references/ for details
3. **No hardcoded paths**: All paths resolved dynamically for remote support
4. **Clear triggering**: Specific phrases users actually say
5. **Executable utilities**: Extract reusable scripts to scripts/
6. **Third-person format**: "This skill should be used when..."
7. **Imperative voice**: "Run X", not "You should run X"

For more patterns, see references/advanced-patterns.md
For troubleshooting, see references/troubleshooting-guide.md
