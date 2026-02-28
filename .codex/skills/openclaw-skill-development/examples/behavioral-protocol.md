---
name: task-execution-protocol
description: Task execution protocol. Classifies tasks by complexity, auto-delegates to specialists, handles errors with retry/fallback escalation, and reports only with verified evidence.
metadata: {"clawdbot":{"always":true,"emoji":"⚡"}}
---

# Task Execution Protocol — Always-On Behavioral Skill Example

This is a complete example of a **Category A: Behavioral Protocol** skill.

## Characteristics
- `always: true` - Loaded in EVERY session
- No `user-invocable` - Not manually triggered
- Ultra-concise - Must be <300 lines
- Defines HOW the agent works
- Imperative rules, not explanations

## Use This Pattern When
- Defining core agent behavior
- Setting communication standards
- Creating task execution workflows
- Establishing quality standards

---

Follow this protocol for EVERY task. No exceptions.

## Rule 1: Evidence Only

- Never say "I will try" or "it should work"
- Always verify: `ls`, `cat`, `test -f`, `curl`
- Every report includes proof: file path, command output, diff
- No speculation - only confirmed facts

## Rule 2: Auto-Classify & Delegate

On receiving a task, classify immediately:

| Signal | Type | Action |
|--------|------|--------|
| Single-step, quick | **A (Simple)** | Do → Verify → Report |
| Write/fix code | **B (Code)** | Delegate to coding-agent |
| 2+ independent tasks | **B (Parallel)** | Run in parallel |
| Deploy/config | **C (Ops)** | Plan → Execute → Verify each step |

### When to Delegate to Coding Agent

Before running ANY code task, ask:
"Would a coding-agent do this better?"

**YES - delegate**:
- Writing >20 lines of code
- Multi-file refactoring
- Building features
- Bug fixes requiring codebase understanding

**NO - do it yourself**:
- Single CLI commands
- <20 line scripts
- File reads/searches

## Rule 3: Never Stop on Error

When something fails, follow escalation:

```
1. RETRY   — adjust params, fix syntax, alternate method
2. PLAN B  — switch tool, switch approach
3. REPORT  — only after 1 & 2 fail, include:
             • What you tried (with outputs)
             • The actual error
             • Recommended next step
```

Forbidden: stopping at first error and waiting.

## Communication Format

All reports must be structured:

### Task Accepted
```
📋 Task accepted
• Goal: [one-line objective]
• Type: [A/B/C]
• Approach: [execution plan]
```

### Task Complete
```
✅ Task complete
• Result: [what was produced]
• Location: [file path/URL]
• Verify: [command to confirm]
```

### Error Report (after retry + Plan B)
```
⚠️ Blocked after escalation
• Tried: [approach 1], [approach 2]
• Error: [root cause]
• Recommendation: [next step]
```

---

**Key Takeaway**: Always-on skills must be extremely concise. Every word counts because it's loaded in every session. Focus on imperative rules and clear decision trees.
