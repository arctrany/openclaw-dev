# OpenClaw Skill Troubleshooting Guide

This guide covers common issues when developing, deploying, and using OpenClaw skills.

## Skill Not Loading Issues

### Issue 1: Skill Not Found in Session

**Symptoms**:
- Skill deployed but not appearing in agent session
- `verify-skill-loaded.sh` returns "NOT LOADED"
- Agent doesn't respond to trigger phrases

**Diagnosis**:
```bash
# Check if skill file exists
ls -la ~/.openclaw/workspace-<agent-id>/skills/<skill-name>/SKILL.md

# Check if agent has active session
ls -la ~/.openclaw/agents/<agent-id>/sessions/sessions.json

# Check session snapshot
cat ~/.openclaw/agents/<agent-id>/sessions/sessions.json | jq '.["agent:<agent-id>:main"].skillsSnapshot.prompt' | grep <skill-name>
```

**Causes & Solutions**:

1. **Skill in wrong workspace**
   - Check agent's workspace path: `jq -r '.agents.list[] | select(.id=="<agent-id>") | .workspace' ~/.openclaw/openclaw.json`
   - Verify skill deployed to correct workspace
   - Fix: `./scripts/deploy-skill.sh <skill-source> <agent-id>`

2. **Session not refreshed**
   - Skills load during session creation, not real-time
   - Fix: Send `/new` to agent via messaging platform

3. **Skill name mismatch**
   - Frontmatter `name:` must match directory name exactly
   - Check: `head -20 SKILL.md | grep "^name:"`
   - Fix: Rename directory or update frontmatter

4. **Invalid YAML frontmatter**
   - Syntax errors prevent skill loading
   - Check: `./scripts/validate-skill.sh <skill-dir>`
   - Common issues: Missing quotes, invalid JSON in metadata

### Issue 2: Skill Loads But Doesn't Trigger

**Symptoms**:
- Skill appears in session snapshot
- Agent doesn't activate skill when expected
- Trigger phrases don't work

**Diagnosis**:
```bash
# Check description field
head -20 SKILL.md | grep "^description:"

# Verify trigger phrases are specific
```

**Causes & Solutions**:

1. **Vague description**
   ```yaml
   # Bad
   description: "Helps with tasks"

   # Good
   description: "This skill should be used when the user asks to 'create X', 'configure Y', 'deploy Z'..."
   ```
   - Fix: Add specific trigger phrases users would actually say

2. **Not using third-person format**
   ```yaml
   # Bad
   description: "Use when you need to..."

   # Good
   description: "This skill should be used when the user asks to..."
   ```
   - Fix: Rewrite in third person

3. **Missing trigger examples**
   - Description should include 3-5 concrete examples
   - Fix: Add example phrases in quotes

4. **Competing skills**
   - Another skill with similar description triggered instead
   - Check: Review other skills' descriptions
   - Fix: Make this skill's description more specific

### Issue 3: Skill Body Too Long

**Symptoms**:
- Skill loads but takes up too much context
- Agent slow to respond when skill active
- Warning: "over 500 lines"

**Causes & Solutions**:

1. **Too much detail in SKILL.md**
   - Move detailed content to `references/`
   - Keep SKILL.md under 500 lines
   - Fix:
     ```bash
     mkdir references/
     # Move sections to references/detailed-guide.md
     # Update SKILL.md to reference it
     ```

2. **Repeated examples**
   - Move examples to `examples/` directory
   - Reference them in SKILL.md
   - Fix: Create `examples/` with working code samples

3. **Embedded scripts**
   - Move long bash/python blocks to `scripts/`
   - Reference scripts in SKILL.md
   - Fix: Extract to executable scripts

## Deployment Issues

### Issue 4: Remote Deployment Fails

**Symptoms**:
- `deploy-skill.sh -r` fails
- SSH connection errors
- Permission denied errors

**Diagnosis**:
```bash
# Test SSH connection
ssh user@remote-host echo "SSH works"

# Check remote agent config
ssh user@remote-host "cat ~/.openclaw/openclaw.json"

# Check remote workspace permissions
ssh user@remote-host "ls -la ~/.openclaw/workspace-<agent-id>/skills/"
```

**Causes & Solutions**:

1. **SSH authentication failure**
   - Fix: Set up SSH key authentication
   ```bash
   ssh-copy-id user@remote-host
   ```

2. **Remote workspace doesn't exist**
   - Fix: Create workspace directory
   ```bash
   ssh user@remote-host "mkdir -p ~/.openclaw/workspace-<agent-id>/skills"
   ```

3. **Permission issues**
   - Fix: Set correct ownership
   ```bash
   ssh user@remote-host "chown -R user:group ~/.openclaw/workspace-<agent-id>"
   ```

4. **Hardcoded paths in scripts**
   - All paths must be dynamic
   - Fix: Use `$HOME/.openclaw/` or resolve from config
   - Check: `grep -r "^/" scripts/`

### Issue 5: Git Deployment Conflicts

**Symptoms**:
- `deploy-skill.sh -m git` fails
- Merge conflicts on remote
- "Not a git repository" error

**Causes & Solutions**:

1. **Workspace not a git repo**
   - Fix: Initialize git
   ```bash
   cd ~/.openclaw/workspace-<agent-id>
   git init
   git remote add origin <url>
   ```

2. **Merge conflicts**
   - Fix: Resolve conflicts manually
   ```bash
   ssh remote-host
   cd workspace
   git status
   # Resolve conflicts, then commit
   ```

3. **Diverged branches**
   - Fix: Pull before push
   ```bash
   git pull --rebase origin main
   git push origin main
   ```

## Validation Issues

### Issue 6: Metadata JSON Invalid

**Symptoms**:
- `validate-skill.sh` shows "invalid metadata JSON"
- Skill loads but metadata ignored
- Features don't work (emoji, requirements)

**Diagnosis**:
```bash
# Extract and test metadata
head -20 SKILL.md | grep "^metadata:" | sed 's/metadata: *//' | jq .
```

**Causes & Solutions**:

1. **Syntax errors**
   ```yaml
   # Bad
   metadata: {clawdbot:{always:false}}  # Missing quotes

   # Good
   metadata: {"clawdbot":{"always":false}}
   ```

2. **Trailing commas**
   ```json
   {"clawdbot":{"always":false,}}  # Bad
   {"clawdbot":{"always":false}}   # Good
   ```

3. **Not a single line**
   - Metadata must be on one line in frontmatter
   - Fix: Compact JSON to single line

4. **Special characters not escaped**
   - Escape quotes in JSON strings
   - Fix: Use single quotes around entire JSON, double quotes inside

### Issue 7: Dependencies Not Found

**Symptoms**:
- Skill requires binary but fails
- "command not found" errors
- Skill doesn't load on some systems

**Diagnosis**:
```bash
# Check required binaries
META=$(head -20 SKILL.md | grep "^metadata:" | sed 's/metadata: *//')
echo "$META" | jq -r '.clawdbot.requires.bins[]?'

# Check if they exist
which jq python3 rsync
```

**Causes & Solutions**:

1. **Binary not installed**
   - Fix: Install required tools
   ```bash
   # macOS
   brew install jq python3

   # Linux
   apt-get install jq python3
   ```

2. **Binary name differs by OS**
   - Use `anyBins` instead of `bins`
   ```yaml
   metadata: {"clawdbot":{"requires":{"anyBins":["python3","python"]}}}
   ```

3. **PATH issues**
   - Fix: Use full paths or add to PATH
   ```bash
   export PATH="/usr/local/bin:$PATH"
   ```

## Remote Agent Issues

### Issue 8: Remote Agent Not Receiving Updates

**Symptoms**:
- Skill deployed to remote server
- Agent still using old version
- Changes not reflected

**Diagnosis**:
```bash
# Check file timestamp on remote
ssh remote-host "ls -la ~/.openclaw/workspace-<agent-id>/skills/<skill-name>/SKILL.md"

# Check agent's active session
ssh remote-host "cat ~/.openclaw/agents/<agent-id>/sessions/sessions.json | jq '.\"agent:<agent-id>:main\".skillsSnapshot.timestamp'"
```

**Causes & Solutions**:

1. **Session not refreshed**
   - Agent loads skills at session start, not dynamically
   - Fix: Send `/new` to agent via messaging platform

2. **Gateway not restarted**
   - Gateway caches skill snapshots
   - Fix: Restart gateway
   ```bash
   ssh remote-host "pkill -TERM openclaw-gateway"
   # Wait for auto-restart
   ```

3. **File transfer incomplete**
   - Verify checksum
   ```bash
   LOCAL_SUM=$(sha256sum SKILL.md | awk '{print $1}')
   REMOTE_SUM=$(ssh remote-host "sha256sum ~/.openclaw/workspace-<agent-id>/skills/<skill-name>/SKILL.md" | awk '{print $1}')
   [ "$LOCAL_SUM" = "$REMOTE_SUM" ] && echo "✅ Match" || echo "❌ Mismatch"
   ```

4. **Skill precedence issue**
   - Higher precedence skill shadowing this one
   - Check: Workspace skill > Managed skill > Bundled skill
   - Fix: Deploy to correct location (workspace has highest precedence)

### Issue 9: Hardcoded Paths Breaking Remote Deployment

**Symptoms**:
- Skill works locally but fails remotely
- "No such file or directory" errors
- Path-related errors on remote agent

**Diagnosis**:
```bash
# Find hardcoded paths
grep -r "/Users/" <skill-dir>/
grep -r "/home/" <skill-dir>/
grep -r "^/" <skill-dir>/scripts/
```

**Causes & Solutions**:

1. **Absolute paths in scripts**
   ```bash
   # Bad
   cat /Users/hao/.openclaw/config.json

   # Good
   cat ~/.openclaw/config.json
   # or
   cat $HOME/.openclaw/config.json
   ```

2. **Hardcoded workspace paths**
   ```bash
   # Bad
   WORKSPACE="/Users/hao/.openclaw/workspace-momiji"

   # Good
   WORKSPACE=$(jq -r '.agents.list[] | select(.id=="momiji") | .workspace' ~/.openclaw/openclaw.json)
   WORKSPACE=$(eval echo "$WORKSPACE")
   ```

3. **Config paths not resolved**
   - Always resolve paths from `openclaw.json`
   - Never hardcode workspace locations

## Performance Issues

### Issue 10: Agent Slow After Loading Skill

**Symptoms**:
- Agent response time increases
- High memory usage
- Timeouts on complex queries

**Diagnosis**:
```bash
# Check skill size
wc -l SKILL.md
du -sh references/

# Check total context size
cat ~/.openclaw/agents/<agent-id>/sessions/sessions.json | jq '.["agent:<agent-id>:main"].skillsSnapshot.prompt' | wc -c
```

**Causes & Solutions**:

1. **SKILL.md too large**
   - Target: <500 lines, 1,500-2,000 words
   - Fix: Move content to `references/`

2. **Too many always-on skills**
   - Every `always: true` skill loaded in every session
   - Fix: Change to `always: false` for optional skills

3. **Large references not lazy-loaded**
   - References should be loaded on-demand, not all at once
   - Fix: Structure SKILL.md to reference specific files when needed
   ```markdown
   # Good
   For error handling, read: references/error-handling.md

   # Bad (loads all references)
   [Entire error handling guide pasted in SKILL.md]
   ```

## Agent Behavior Issues

### Issue 11: Skill Triggers Too Often

**Symptoms**:
- Skill activates on unrelated queries
- Wastes context on irrelevant tasks
- Agent slower due to unnecessary skill loading

**Causes & Solutions**:

1. **Description too broad**
   ```yaml
   # Bad - triggers on anything
   description: "Helps with development tasks"

   # Good - specific triggers
   description: "This skill should be used when the user asks to 'create OpenClaw skill', 'validate SKILL.md', 'deploy to agent workspace'"
   ```

2. **Generic keywords**
   - Avoid: "help", "task", "work", "do"
   - Use: Specific domain terms and exact phrases

3. **Missing exclusions**
   - Add what NOT to trigger on
   ```yaml
   description: "... Use for OpenClaw skill development. Do NOT use for general coding tasks or plugin commands."
   ```

### Issue 12: Skill Never Triggers

**Symptoms**:
- Manually loading works (`/skill-name`)
- Automatic triggering fails
- Agent asks how to do task that skill covers

**Causes & Solutions**:

1. **Trigger phrases don't match user language**
   - Test with actual user queries
   - Add variations: "create skill", "make a skill", "build new skill", "add skill"

2. **Description buried in long text**
   - Put trigger phrases early in description
   - Format: "This skill should be used when the user asks to 'X', 'Y', 'Z'..."

3. **Competing skill wins**
   - Check other skills' descriptions
   - Make this skill's triggers more specific
   - Use domain-specific terms

## Multi-Agent Issues

### Issue 13: Skill Works for One Agent, Not Another

**Symptoms**:
- Same skill, different agents
- One agent uses it correctly, another doesn't
- Inconsistent behavior

**Diagnosis**:
```bash
# Compare agent workspaces
diff -r ~/.openclaw/workspace-agent1/skills/skill-name \
         ~/.openclaw/workspace-agent2/skills/skill-name

# Check agent configs
jq '.agents.list[] | {id, workspace, model}' ~/.openclaw/openclaw.json
```

**Causes & Solutions**:

1. **Different skill versions**
   - Agents have different versions of the skill
   - Fix: Deploy same version to both
   ```bash
   for agent in agent1 agent2; do
     ./scripts/deploy-skill.sh skill-name $agent
   done
   ```

2. **Different models**
   - Some models better at skill triggering
   - Haiku may miss nuanced triggers
   - Fix: Use Sonnet or Opus for agents that need reliable triggering

3. **Agent personality conflicts**
   - Agent's SOUL.md may override skill behavior
   - Check: Read agent's SOUL.md for conflicts
   - Fix: Adjust SOUL.md or skill to be compatible

## Common Mistakes Checklist

When troubleshooting, check these common mistakes:

- [ ] **Frontmatter syntax**: Valid YAML with `---` delimiters
- [ ] **Name matches directory**: `name:` in frontmatter = directory name
- [ ] **Third-person description**: Starts with "This skill should be used when..."
- [ ] **Specific trigger phrases**: 3-5 concrete examples in quotes
- [ ] **Valid JSON metadata**: Test with `echo '<metadata>' | jq .`
- [ ] **No hardcoded paths**: Use `~/.openclaw/` or resolve from config
- [ ] **Imperative voice in body**: "Run X", not "You should run X"
- [ ] **Under 500 lines**: Or use progressive disclosure with references/
- [ ] **Session refreshed**: Send `/new` after deployment
- [ ] **Correct workspace**: Deployed to agent's actual workspace path

## Getting Help

If issues persist:

1. **Run validation script**:
   ```bash
   ./scripts/validate-skill.sh <skill-dir>
   ```

2. **Check gateway logs**:
   ```bash
   tail -f ~/.openclaw/logs/gateway.log
   ```

3. **Verify with skill-loaded script**:
   ```bash
   ./scripts/verify-skill-loaded.sh -a <agent-id> <skill-name>
   ```

4. **Review session logs**:
   ```bash
   tail -100 ~/.openclaw/agents/<agent-id>/sessions/*.jsonl | jq -r 'select(.message.role=="assistant") | .message.content[].text'
   ```

5. **Test in isolation**:
   - Create test agent with only this skill
   - Verify triggering works
   - Add other skills incrementally

---

For advanced patterns, see references/advanced-patterns.md
For real-world examples, see references/real-world-examples.md
