# OpenClaw Skill Development - Quick Reference

Quick reference for common patterns, commands, and checklists.

## Minimal Viable SKILL.md

```yaml
---
name: skill-name
description: "This skill should be used when the user asks to 'trigger phrase 1', 'trigger phrase 2', 'trigger phrase 3'..."
metadata: {"clawdbot":{"always":false,"emoji":"🔧"}}
---

# Skill Title

Instructions in imperative form...
```

## Common Metadata Patterns

```yaml
# Basic skill
metadata: {"clawdbot":{"always":false,"emoji":"🔧"}}

# With dependencies
metadata: {"clawdbot":{"always":false,"emoji":"🔧","requires":{"bins":["jq","python3"]}}}

# With environment variables
metadata: {"clawdbot":{"always":false,"emoji":"🔧","requires":{"env":["API_KEY"]}}}

# OS-specific
metadata: {"clawdbot":{"always":false,"emoji":"🔧","os":["darwin","linux"]}}

# User-invocable
user-invocable: true
```

## Validation Checklist

Before deploying a skill:

- [ ] `name` matches directory name exactly
- [ ] `description` uses third-person format ("This skill should be used when...")
- [ ] `description` includes 3+ specific trigger phrases in quotes
- [ ] `metadata` is valid JSON (test: `echo '<metadata>' | jq .`)
- [ ] Body uses imperative voice ("Run X", not "You should run X")
- [ ] Under 500 lines (or uses `references/` for progressive disclosure)
- [ ] No hardcoded paths (use dynamic resolution from `openclaw.json`)
- [ ] Run `./scripts/validate-skill.sh <skill-dir>` - passes

## Deployment Commands

### Local Deployment

```bash
# Deploy to local agent
./scripts/deploy-skill.sh ./skill-name agent-id

# Verify loaded
./scripts/verify-skill-loaded.sh -a agent-id skill-name
```

### Remote Deployment

```bash
# Deploy to remote agent via rsync
./scripts/deploy-skill.sh -r user@remote-host ./skill-name agent-id

# Deploy to remote agent via git
./scripts/deploy-skill.sh -m git -r user@remote-host skill-name agent-id

# Verify on remote
./scripts/verify-skill-loaded.sh -r user@remote-host -a agent-id skill-name
```

### Multi-Agent Deployment

```bash
# Deploy to all agents
for agent in $(jq -r '.agents.list[].id' ~/.openclaw/openclaw.json); do
  ./scripts/deploy-skill.sh skill-name $agent
done
```

## Troubleshooting One-Liners

```bash
# Find agent workspace path
jq -r '.agents.list[] | select(.id=="<agent-id>") | .workspace' ~/.openclaw/openclaw.json

# Check if skill file exists (local)
ls -la ~/.openclaw/workspace-<agent-id>/skills/<skill-name>/SKILL.md

# Check if skill file exists (remote)
ssh user@remote-host "ls -la ~/.openclaw/workspace-<agent-id>/skills/<skill-name>/SKILL.md"

# Check if skill loaded in session
cat ~/.openclaw/agents/<agent-id>/sessions/sessions.json | jq -r '.["agent:<agent-id>:main"].skillsSnapshot.prompt' | grep <skill-name>

# Validate metadata JSON
head -20 SKILL.md | grep "^metadata:" | sed 's/metadata: *//' | jq .

# Count skill lines
wc -l SKILL.md

# Find hardcoded paths
grep -r "^/" scripts/ references/ examples/

# Restart gateway (after config changes)
pkill -TERM openclaw-gateway
```

## Component Organization Guidelines

### Put in `scripts/`
- Validation utilities
- Deployment automation
- Testing helpers
- Reusable code that would be rewritten each time

### Put in `references/`
- Detailed patterns and techniques
- Troubleshooting guides
- Advanced configurations
- Long documentation (>2,000 words)

### Put in `examples/`
- Complete, working SKILL.md examples
- Template files users can copy
- Real-world implementations

### Put in SKILL.md
- Core workflow (5 phases)
- Essential instructions
- Pointers to scripts/references/examples
- Keep under 500 lines

## Script Usage Examples

### Validation Script

```bash
# Local validation
./scripts/validate-skill.sh /path/to/skill-name

# Validate in agent workspace
./scripts/validate-skill.sh -a momiji skill-name

# Validate on remote agent
./scripts/validate-skill.sh -r user@remote-host -a momiji skill-name
```

### Deployment Script

```bash
# Deploy locally
./scripts/deploy-skill.sh ./my-skill momiji

# Deploy to remote agent (rsync)
./scripts/deploy-skill.sh -r user@remote-host ./my-skill momiji

# Deploy to remote agent (git)
./scripts/deploy-skill.sh -m git -r user@remote-host my-skill momiji
```

### Verification Script

```bash
# Verify local agent
./scripts/verify-skill-loaded.sh -a momiji skill-name

# Verify remote agent
./scripts/verify-skill-loaded.sh -r user@remote-host -a momiji skill-name
```

## Key Script Features

- ✅ No hardcoded paths - all paths resolved dynamically
- ✅ Support for remote OpenClaw agents via SSH
- ✅ 3 deployment methods: rsync/scp/git
- ✅ Comprehensive validation and verification
