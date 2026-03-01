---
name: diagnose-openclaw
description: Diagnose an OpenClaw agent's capability health (gateway, models, memory, skills, tools) and summarize actionable fixes.
argument-hint: <agent-id> [--quick|--full]
---

# Diagnose OpenClaw Capability

Run the QA framework against an OpenClaw agent and produce a diagnosis report summary.

## Inputs

- Required: `agent-id`
- Optional: `--quick` (default) or `--full`

If `agent-id` is missing, ask the user which agent to diagnose.

## Execution

Determine plugin root:

- If `${CLAUDE_PLUGIN_ROOT}` is available, use it (Claude/OpenClaw plugin runtime)
- Otherwise, if current directory is plugin root, use `$(pwd)`
- Otherwise, use workspace-relative `plugins/qa`

Run:

```bash
bash <PLUGIN_ROOT>/scripts/run-qa-tests.sh --agent "<agent-id>" <mode>
```

Mode rules:
- Default to `--quick`
- Use `--full` when user asks for regression verification or deep diagnosis

## Output To User

1. State pass/fail summary (passed/failed/warnings/success rate)
2. List top issues first (P0/P1), with likely root cause
3. Point to generated report path (`reports/qa-report-*.md`)
4. Offer to fix issues immediately (config/skills/scripts)

## Important

- Treat `run-qa-tests.sh` as the execution engine; this command is the plugin-facing workflow entry
- Prefer minimal repro and targeted fixes, then rerun `--quick`
