---
name: diagnose-openclaw
description: Diagnose an OpenClaw agent's capability health using the bundled QA module and summarize actionable fixes.
argument-hint: <agent-id> [--quick|--full]
---

# Diagnose OpenClaw Capability (Toolkit)

Use the bundled QA module (`plugins/qa`) to diagnose an OpenClaw agent.

## Inputs

- Required: `agent-id`
- Optional: `--quick` (default) or `--full`

If `agent-id` is missing, ask the user which agent to diagnose.

## Execution

Preferred execution engine:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/plugins/qa/scripts/run-qa-tests.sh --agent "<agent-id>" <mode>
```

If `${CLAUDE_PLUGIN_ROOT}` is unavailable (non-Claude runtime), infer plugin root from workspace and use:

```bash
bash plugins/qa/scripts/run-qa-tests.sh --agent "<agent-id>" <mode>
```

Mode rules:
- Default to `--quick`
- Use `--full` for deep regression verification

## Output To User

1. Findings first (severity-ordered)
2. Summary metrics (pass/fail/warnings/success rate)
3. Report path (`plugins/qa/reports/qa-report-*.md`)
4. Offer to patch and rerun
