---
name: self-evolve
description: "Agent self-improvement and optimization. This skill should be used when the agent needs to analyze its own performance, when user asks to 'improve yourself', 'optimize behavior', 'analyze sessions', 'learn from mistakes', or periodically for heartbeat analysis."
metadata: {"clawdbot":{"always":true,"emoji":"🧠"}}
user-invocable: true
---

# Self-Evolve — Self-Improvement Skill Example

This is a complete example of a **Category D: Self-Improvement (Hybrid)** skill.

## Characteristics
- Both `always: true` AND `user-invocable: true`
- Dual mode: heartbeat (automatic) + deep analysis (manual)
- Reads session logs and memory files
- Writes to agent's memory
- Self-analyzing and adaptive

## Use This Pattern When
- Building agent self-improvement systems
- Creating session analytics
- Implementing adaptive learning
- Managing agent memory

---

This skill operates in two modes: Heartbeat (automatic) and Deep (user-triggered).

## Heartbeat Mode (always: true)

Every 50 messages, automatically analyze:

### 1. User Feedback Patterns
```bash
# Extract user feedback from recent messages
tail -100 ~/.openclaw/agents/<agent-id>/sessions/*.jsonl | \
  jq -r 'select(.message.role=="user") | .message.content[].text' | \
  grep -iE "(good|great|perfect|thanks|wrong|bad|error|fix)"
```

Look for:
- Positive feedback → Reinforce successful patterns
- Negative feedback → Flag failed approaches
- Repeated corrections → Identify blind spots

### 2. Recurring Errors
```bash
# Find repeated error patterns
tail -500 ~/.openclaw/agents/<agent-id>/sessions/*.jsonl | \
  jq -r 'select(.message.content[].type=="tool_result") | .message.content[] | select(.is_error==true) | .content' | \
  sort | uniq -c | sort -rn | head -10
```

Actions:
- If same error 3+ times → Update memory/failures.md
- If tool usage error → Update TOOLS.md with correct pattern
- If workflow issue → Update relevant skill

### 3. Efficiency Opportunities
```bash
# Identify slow operations
tail -200 ~/.openclaw/agents/<agent-id>/sessions/*.jsonl | \
  jq -r 'select(.timing) | "\(.timing.duration_ms)ms - \(.message.content[].type)"' | \
  sort -rn | head -20
```

Look for:
- Repeated slow searches → Create reference file
- Multiple tool calls for same info → Cache in memory
- Long context → Archive old sessions

### 4. Update Memory

If patterns found, update MEMORY.md:
```markdown
# MEMORY.md
Last updated: 2026-02-10

## Successful Patterns
- [Pattern identified in heartbeat analysis]

## Failed Approaches
- [Approach that caused errors, avoid]

## User Preferences
- [Preference learned from feedback]
```

**Heartbeat frequency**: Every 50 messages
**Keep it lightweight**: Max 5 minutes analysis time
**Update only if needed**: Don't write if no new learnings

## Deep Mode (user-invocable: true)

When user triggers `/self-evolve`, run comprehensive analysis:

### 1. Read All Session Logs

```bash
# Get session log directory
AGENT_ID="<agent-id>"
SESSION_DIR="$HOME/.openclaw/agents/$AGENT_ID/sessions"

# Read all sessions
for session_file in $SESSION_DIR/*.jsonl; do
  echo "Analyzing: $(basename $session_file)"

  # Extract all messages
  cat "$session_file" | jq -r '.message'
done
```

### 2. Comprehensive Analysis

**User satisfaction metrics**:
- Count positive vs negative feedback
- Identify most appreciated behaviors
- Find frustration points

**Task success rate**:
- Tasks completed successfully
- Tasks failed or abandoned
- Common failure modes

**Tool usage patterns**:
- Most frequently used tools
- Tool error rates
- Unused available tools

**Communication effectiveness**:
- Average response length
- Use of structured formats
- Clarity of explanations

### 3. Generate Report

```markdown
# Self-Evolution Analysis Report
Date: 2026-02-10
Sessions analyzed: 47
Messages analyzed: 3,421

## Performance Metrics
✅ Task success rate: 89% (305/342 tasks)
📊 Avg response time: 3.2s
💬 User satisfaction: High (87% positive feedback)

## Top Successful Patterns
1. Using structured reporting format (92% positive feedback)
2. Verifying before claiming completion (prevents 87% of rework)
3. Delegating complex coding to coding-agent (2x faster)

## Areas for Improvement
1. **Over-explaining simple tasks** (15 instances of "too verbose")
   - Action: Be more concise for simple confirmations
   - Update: SOUL.md → Add "brevity for simple tasks" rule

2. **Missing edge cases** (12 instances of "didn't handle X")
   - Action: Add edge case checklist to task protocol
   - Update: task-execution-protocol skill

3. **Not catching hardcoded paths** (8 instances)
   - Action: Add path validation to pre-commit checks
   - Update: Create validate-paths.sh script

## Proposed Memory Updates
Should I update these files?
- memory/successful-patterns.md (add 3 new patterns)
- memory/failed-approaches.md (add 2 approaches to avoid)
- SOUL.md (add brevity guideline)
```

### 4. Propose Updates

Wait for user approval before modifying files.

**If approved**:
```bash
# Update memory files
echo "Pattern: [new pattern]" >> memory/successful-patterns.md
echo "Avoid: [failed approach]" >> memory/failed-approaches.md

# Update SOUL.md if personality drift detected
# (only with explicit user permission)
```

### 5. Track Improvement Over Time

```bash
# Create evolution log
echo "$(date): Self-evolution analysis complete" >> memory/evolution-log.md
echo "  - Task success rate: 89% (was 82% last month)" >> memory/evolution-log.md
echo "  - Updated 3 memory files" >> memory/evolution-log.md
```

## Session Log Analysis Patterns

### Extract User Messages
```bash
cat session.jsonl | jq -r 'select(.message.role=="user") | .message.content[].text'
```

### Extract Assistant Messages
```bash
cat session.jsonl | jq -r 'select(.message.role=="assistant") | .message.content[] | select(.type=="text") | .text'
```

### Extract Tool Calls
```bash
cat session.jsonl | jq -r 'select(.message.content[].type=="tool_use") | .message.content[] | "\(.name) - \(.input)"'
```

### Extract Tool Results
```bash
cat session.jsonl | jq -r 'select(.message.content[].type=="tool_result") | .message.content[] | {tool: .tool_use_id, error: .is_error, content: .content}'
```

### Find Error Patterns
```bash
cat session.jsonl | \
  jq -r 'select(.message.content[].is_error==true) | .message.content[].content' | \
  grep -oE "Error: [^\"]*" | \
  sort | uniq -c | sort -rn
```

## Memory File Structure

Maintain these files in agent workspace:

### MEMORY.md (Index)
```markdown
# Agent Memory Index

Last updated: 2026-02-10

## Quick Links
- [Successful Patterns](memory/successful-patterns.md)
- [Failed Approaches](memory/failed-approaches.md)
- [User Preferences](memory/user-preferences.md)
- [Evolution Log](memory/evolution-log.md)

## Key Learnings
1. [Top learning 1]
2. [Top learning 2]
3. [Top learning 3]
```

### memory/successful-patterns.md
```markdown
# Successful Patterns

Patterns that consistently work well:

## Task Execution
- Always verify before reporting completion
- Use structured formats for complex reports
- Delegate code tasks to coding-agent

## Communication
- Start with brief summary, offer details if needed
- Use emojis sparingly (only in structured reports)
- Include verification commands in completion reports
```

### memory/failed-approaches.md
```markdown
# Failed Approaches

Approaches that didn't work, avoid these:

## Task Execution
- ❌ Claiming completion without verification
- ❌ Retrying same command 5+ times without adjustment
- ❌ Hardcoding paths in scripts

## Communication
- ❌ Over-explaining simple confirmations
- ❌ Using raw logs instead of summaries
- ❌ Asking too many questions at once
```

### memory/user-preferences.md
```markdown
# User Preferences

Learned preferences for this user:

## Communication Style
- Prefers: Concise, structured reports
- Dislikes: Verbose explanations for simple tasks
- Language: English with occasional Chinese OK

## Workflow
- Wants: Evidence-based reporting
- Wants: Proactive error handling
- Wants: Remote deployment support
```

## Best Practices

1. **Heartbeat should be lightweight**
   - Max 5 minutes analysis
   - Only update if new learnings
   - Don't interrupt ongoing work

2. **Deep analysis requires approval**
   - Show proposed changes before applying
   - Wait for explicit "yes"
   - Never modify SOUL.md without permission

3. **Track improvements over time**
   - Log each evolution analysis
   - Compare metrics month-over-month
   - Celebrate progress

4. **Balance stability and adaptation**
   - Don't change core behavior too often
   - Keep successful patterns stable
   - Only adapt when clear benefit

## Progressive Disclosure

For session log analysis techniques:
- Read: `references/session-analysis.md`

For memory management strategies:
- Read: `references/memory-management.md`

---

**Key Takeaway**: Self-improvement skills operate in dual mode (automatic + manual), read session logs and memory files, and update agent behavior based on analysis. Always get user approval before modifying core files like SOUL.md.
