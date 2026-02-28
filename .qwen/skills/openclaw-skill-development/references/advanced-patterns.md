# Advanced OpenClaw Skill Patterns

This document covers advanced patterns and techniques for OpenClaw skill development.

## Progressive Disclosure Strategy

### Three-Tier Loading System

OpenClaw uses a sophisticated loading system to manage context efficiently:

**Tier 1: Metadata (~100 words, always loaded)**
- Loaded into every session's system prompt
- Includes: name, description, emoji, requirements
- Must be extremely concise
- Used for skill discovery and triggering

**Tier 2: SKILL.md Body (<5k words, loaded on trigger)**
- Loaded only when skill is triggered
- Core instructions and workflows
- Should be focused and actionable
- Target: 1,500-2,000 words ideal, 500 lines max

**Tier 3: References (unlimited, loaded on demand)**
- Agent loads these when needed
- Detailed patterns, troubleshooting, examples
- No size limits - can be extensive
- Files in `references/` directory

### When to Use Each Tier

**Put in Metadata (Tier 1)**:
- Trigger phrases ("create X", "configure Y")
- When to use this skill
- Required dependencies
- OS compatibility

**Put in SKILL.md Body (Tier 2)**:
- Core workflow steps
- Essential commands
- Critical decision points
- Pointers to references/

**Put in References (Tier 3)**:
- Detailed troubleshooting guides
- Edge case handling
- Historical context
- Alternative approaches
- Extensive examples

## Advanced Metadata Patterns

### Conditional Loading with Requirements

```yaml
metadata: {
  "clawdbot": {
    "always": false,
    "emoji": "🔧",
    "requires": {
      "bins": ["jq", "python3"],
      "anyBins": ["rsync", "scp"],
      "env": ["OPENCLAW_API_KEY"],
      "config": ["agents.list[0].workspace"]
    },
    "os": ["darwin", "linux"]
  }
}
```

**Field explanations**:
- `bins`: ALL listed binaries must exist
- `anyBins`: At least ONE must exist
- `env`: Required environment variables
- `config`: Required paths in openclaw.json (uses jq syntax)
- `os`: Skill only loads on these operating systems

### Auto-Installation Patterns

```yaml
metadata: {
  "clawdbot": {
    "install": [
      {
        "type": "brew",
        "package": "jq",
        "condition": "!which jq"
      },
      {
        "type": "npm",
        "package": "typescript@latest",
        "global": true
      },
      {
        "type": "download",
        "url": "https://example.com/tool.sh",
        "dest": "${SKILL_DIR}/scripts/tool.sh",
        "checksum": "sha256:abc123..."
      }
    ]
  }
}
```

**Supported install types**:
- `brew`: macOS Homebrew packages
- `npm`: Node.js packages
- `go`: Go modules (`go install`)
- `uv`: Python packages via uv
- `download`: Direct file downloads

## Skill Triggering Patterns

### Pattern 1: Always-On Behavioral Skills

Use for core behavioral protocols that should always influence the agent.

```yaml
name: task-execution-protocol
description: "Task execution standard. Defines how agent approaches all tasks."
metadata: {"clawdbot":{"always":true,"emoji":"⚡"}}
```

**Body structure**:
```markdown
# Task Execution Protocol

Follow this for EVERY task:

## Rule 1: Evidence Only
- Never say "I will try"
- Always verify before reporting
- Every report includes proof

## Rule 2: Auto-Classify & Delegate
[Clear decision tree]

## Rule 3: Never Stop on Error
[Escalation procedure]
```

**Characteristics**:
- `always: true` - loaded in every session
- No `user-invocable` - not manually triggered
- Extremely concise (<300 lines)
- Imperative rules, not explanations

### Pattern 2: Tool Integration Skills

Use for teaching agents to use specific tools or APIs.

```yaml
name: coding-agent-integration
description: "This skill should be used when the user asks to 'run codex', 'use coding-agent', 'delegate to coder', 'write code with AI', or mentions code generation tasks."
metadata: {"clawdbot":{"always":false,"emoji":"💻","requires":{"bins":["codex"]}}}
user-invocable: false
```

**Body structure**:
```markdown
# Coding Agent Integration

Use the `codex` binary for code generation tasks.

## When to Delegate
- Writing >20 lines of code
- Multi-file refactoring
- Building new features

## Command Syntax
bash pty:true background:true workdir:<path> command:"codex exec --full-auto '<task>'"

## Best Practices
[Tool-specific tips]
```

**Characteristics**:
- `always: false` - loaded only when triggered
- Comprehensive `description` with trigger phrases
- Includes specific command syntax
- May have `scripts/` for tool wrappers

### Pattern 3: User-Invocable Commands

Use for skills users trigger manually via slash commands.

```yaml
name: deploy-agent
description: "This skill should be used when the user asks to '/deploy', 'deploy agent', 'push to production', or mentions deployment workflows."
metadata: {"clawdbot":{"always":false,"emoji":"🚀"}}
user-invocable: true
```

**Body structure**:
```markdown
# Deploy Agent

User triggered this via /deploy command.

## Deployment Checklist
1. Validate configuration
2. Run tests
3. Create backup
4. Deploy
5. Verify

## Arguments
- `/deploy production` - Deploy to production
- `/deploy staging` - Deploy to staging
```

**Characteristics**:
- `user-invocable: true` - accessible via /skill-name
- Clear command syntax documentation
- May also be model-triggered if description matches

### Pattern 4: Self-Improvement Skills

Use for skills that analyze and optimize the agent itself.

```yaml
name: self-evolve
description: "Agent self-improvement and optimization. This skill should be used when the agent needs to analyze its own performance or when user asks to 'improve yourself', 'analyze sessions', 'optimize behavior'."
metadata: {"clawdbot":{"always":true,"emoji":"🧠"}}
user-invocable: true
```

**Body structure**:
```markdown
# Self-Evolve Protocol

## Heartbeat Mode (always: true)
Every 50 messages, analyze:
- Patterns in user feedback
- Recurring errors
- Efficiency opportunities

## Deep Mode (user-invocable: true)
When user triggers /self-evolve:
1. Read session logs
2. Identify improvement areas
3. Propose memory updates
4. Update MEMORY.md

## Session Log Analysis
Read from: ~/.openclaw/agents/<id>/sessions/*.jsonl
```

**Characteristics**:
- Both `always: true` AND `user-invocable: true`
- Reads session logs and memory files
- Updates agent's own configuration
- Tracks state in `memory/` directory

## Remote Deployment Patterns

### Pattern 1: Git-Based Deployment

For production environments with version control.

**Setup**:
```bash
# Development machine
cd /path/to/openclaw-workspace
git init
git remote add origin git@github.com:user/openclaw-workspace.git

# Add skills
git add skills/
git commit -m "Add skill: skill-name"
git push origin main

# Remote server
ssh user@remote-server
cd ~/.openclaw/workspace-agent-name
git pull origin main
# Send /new to agent
```

**Advantages**:
- Version controlled
- Easy rollback
- Audit trail
- Team collaboration

**When to use**:
- Production deployments
- Multi-agent environments
- Team development

### Pattern 2: SSH + Rsync Deployment

For rapid iteration during development.

**Using deploy-skill.sh**:
```bash
# Deploy single skill
./scripts/deploy-skill.sh -r user@remote-host skill-name agent-id

# Deploy with verbose output
./scripts/deploy-skill.sh -r user@remote-host -v skill-name agent-id
```

**Advantages**:
- Fast incremental updates
- No git required
- Good for development

**When to use**:
- Active development
- Quick iterations
- Testing on remote agents

### Pattern 3: OpenClaw Gateway API

For programmatic deployments via API.

**Concept** (if OpenClaw Gateway supports it):
```bash
# Package skill
tar -czf skill-name.tar.gz -C skills/ skill-name/

# Deploy via API
curl -X POST https://gateway.openclaw.example/api/skills/deploy \
  -H "Authorization: Bearer $TOKEN" \
  -F "agentId=agent-name" \
  -F "skillArchive=@skill-name.tar.gz"
```

**When to use**:
- CI/CD pipelines
- Automated deployments
- Multi-agent deployments

## Multi-Agent Skill Distribution

### Shared Skills vs Per-Agent Skills

**Shared skills** (managed location: `~/.openclaw/skills/`):
- Available to all agents
- Good for universal capabilities
- Example: git-workflow, email-integration

**Per-agent skills** (workspace: `<workspace>/skills/`):
- Specific to one agent
- Agent personality and role-specific
- Example: customer-support-protocol, devops-automation

**Deployment strategy**:
```bash
# Deploy to all agents
for agent in $(jq -r '.agents.list[].id' ~/.openclaw/openclaw.json); do
  ./scripts/deploy-skill.sh skill-name $agent
done

# Deploy to specific agents only
for agent in momiji sakura; do
  ./scripts/deploy-skill.sh skill-name $agent
done
```

### Skill Precedence in Multi-Agent Systems

OpenClaw resolves skills in this order:
1. Workspace skills (highest precedence)
2. Managed skills
3. Bundled skills (lowest precedence)

**Use case**: Override global skill for specific agent:
```bash
# Global skill for all agents
cp -r skill-name ~/.openclaw/skills/

# Override for specific agent
cp -r skill-name-custom ~/.openclaw/workspace-agent-x/skills/skill-name/
# This agent gets customized version, others get global version
```

## Skill Composition Patterns

### Pattern: Skill References Skill

One skill can instruct the agent to load another skill when needed.

**Example** (openclaw-skill-development references other plugin-dev skills):
```markdown
# OpenClaw Skill Development

## Phase 3: Implement

When creating commands, load the command-development skill:
"Load the command-development skill to understand command structure."

When creating agents, load the agent-development skill:
"Load the agent-development skill for agent creation guidance."
```

**Benefits**:
- Keeps individual skills lean
- Modular knowledge
- Context-aware loading

### Pattern: Conditional Skill Loading

Skills can include logic for when to load references.

```markdown
# API Integration Skill

## When Working with REST APIs
Read: references/rest-api-patterns.md

## When Working with GraphQL
Read: references/graphql-patterns.md

## When Working with gRPC
Read: references/grpc-patterns.md
```

**Benefits**:
- Load only relevant documentation
- Saves context window space
- Faster agent responses

## Testing and Validation Patterns

### Automated Validation Pipeline

```bash
#!/bin/bash
# validate-all-skills.sh

for skill_dir in skills/*/; do
    skill_name=$(basename "$skill_dir")
    echo "Validating: $skill_name"

    ./scripts/validate-skill.sh "$skill_dir"

    if [ $? -eq 0 ]; then
        echo "✅ $skill_name passed"
    else
        echo "❌ $skill_name failed"
        exit 1
    fi
done
```

### Pre-Deployment Testing

```bash
# Test locally before remote deployment
./scripts/validate-skill.sh skills/skill-name/
./scripts/deploy-skill.sh skills/skill-name/ test-agent
# Test with test-agent
./scripts/deploy-skill.sh -r prod-server skills/skill-name/ prod-agent
```

### Integration Testing

Create test cases that verify skill triggering:

```bash
# test-skill-triggering.sh
echo "Test 1: Trigger with phrase A"
# Send message to agent with trigger phrase
# Verify skill loaded

echo "Test 2: Trigger with phrase B"
# Send message with alternative trigger
# Verify skill loaded

echo "Test 3: No trigger"
# Send unrelated message
# Verify skill NOT loaded (saves context)
```

## Performance Optimization Patterns

### Minimize Context Bloat

**Anti-pattern**:
```markdown
# Bad: Everything in SKILL.md (3,000 lines)
[All patterns, all edge cases, all examples]
```

**Best practice**:
```markdown
# Good: SKILL.md (500 lines)
[Core workflow and pointers]

For advanced patterns: references/advanced-patterns.md
For troubleshooting: references/troubleshooting.md
For examples: examples/
```

### Lazy Loading References

```markdown
# Skill Body

## When Error Occurs
If you encounter error X, read: references/error-handling.md

## When Optimizing
For optimization strategies, read: references/optimization.md
```

**Benefit**: References load only when agent determines they're needed.

## Security Patterns

### Credential Management

**Never hardcode credentials**:
```yaml
# Bad
metadata: {"clawdbot":{"apiKey":"sk-abc123..."}}

# Good
metadata: {"clawdbot":{"primaryEnv":"OPENCLAW_API_KEY","requires":{"env":["OPENCLAW_API_KEY"]}}}
```

**In skill body**:
```markdown
Use environment variable: $OPENCLAW_API_KEY
Never log or expose the key value.
```

### Path Security

**Never hardcode paths**:
```bash
# Bad
cp skill.md ~/.openclaw/skills/

# Good
WORKSPACE=$(jq -r ".agents.list[] | select(.id==\"$AGENT_ID\") | .workspace" ~/.openclaw/openclaw.json)
WORKSPACE=$(eval echo "$WORKSPACE")
cp skill.md "$WORKSPACE/skills/"
```

### Remote Execution Safety

When deploying to remote agents:
- Validate SSH host keys
- Use SSH key authentication (not passwords)
- Verify file integrity after transfer
- Use checksums for critical scripts

```bash
# Example: Verify after deployment
CHECKSUM=$(sha256sum skill.md | awk '{print $1}')
ssh remote-host "sha256sum workspace/skills/skill-name/SKILL.md" | grep $CHECKSUM
```

## Maintenance Patterns

### Skill Versioning

Include version in metadata for tracking:
```yaml
name: skill-name
description: "..."
version: 2.1.0
metadata: {"clawdbot":{"always":false,"emoji":"🔧"}}
```

**Semantic versioning**:
- MAJOR: Breaking changes (skill structure changes)
- MINOR: New features (new sections, references)
- PATCH: Bug fixes (typos, corrections)

### Deprecation Strategy

When replacing a skill:
1. Create new skill with improved version
2. Mark old skill as deprecated in description
3. Provide migration guide in references/
4. Keep old skill for 2-3 versions
5. Remove after confirmation no agents use it

```yaml
# Old skill
name: old-skill
description: "DEPRECATED: Use new-skill instead. This skill should be used when... See references/migration-guide.md"
```

### Skill Health Monitoring

Track skill usage and effectiveness:
```bash
# Count skill triggers in session logs
grep "openclaw-skill-development" ~/.openclaw/agents/*/sessions/*.jsonl | wc -l

# Find which agents use which skills
for agent in ~/.openclaw/agents/*/; do
    agent_id=$(basename "$agent")
    skills=$(cat "$agent/sessions/sessions.json" | jq -r ".\"agent:${agent_id}:main\".skillsSnapshot.prompt" | grep -o "name: [a-z-]*" | cut -d' ' -f2)
    echo "$agent_id: $skills"
done
```

## Advanced Use Cases

### Multi-Language Skills

For agents operating in multiple languages:
```yaml
name: customer-support
description: "Customer support protocol. Multilingual (EN/ZH/JA)."
metadata: {"clawdbot":{"always":true,"emoji":"💬"}}
```

**Structure**:
```
customer-support/
├── SKILL.md              # Core protocol (language-agnostic)
├── references/
│   ├── responses-en.md   # English responses
│   ├── responses-zh.md   # Chinese responses
│   └── responses-ja.md   # Japanese responses
```

**In SKILL.md**:
```markdown
Detect user language, then load:
- English: references/responses-en.md
- Chinese: references/responses-zh.md
- Japanese: references/responses-ja.md
```

### Agent Handoff Skills

For multi-agent workflows:
```yaml
name: agent-handoff
description: "Coordinate handoffs between specialized agents."
metadata: {"clawdbot":{"always":true,"emoji":"🔄"}}
```

**Workflow**:
```markdown
When task requires expertise outside your domain:
1. Identify specialist agent
2. Package context
3. Hand off via OpenClaw Gateway
4. Monitor progress
5. Resume when complete
```

---

This reference covers advanced patterns. For basic workflows, see main SKILL.md.
