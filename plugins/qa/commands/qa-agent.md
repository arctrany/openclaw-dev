---
name: qa-agent
description: "Diagnose and optionally fix an OpenClaw agent's capability health (gateway, models, memory, skills, tools). Default: diagnosis only. Use --fix for diagnosis-fix-regression loop."
argument-hint: <agent-id> [--quick|--full] [--fix] [focus-area]
---

# /qa-agent — OpenClaw Agent 能力诊断与修复

Run the QA framework against an OpenClaw agent. Default: diagnosis report. With `--fix`: diagnosis-fix-regression loop.

## Inputs

- Required: `agent-id`
- Optional: `--quick` (default) or `--full`
- Optional: `--fix` to enter fix loop
- Optional: `focus-area` (`memory`, `skills`, `models`, `tools`, `multimodal`)

If `agent-id` is missing, ask the user.

## Execution (portable)

If `${CLAUDE_PLUGIN_ROOT}` exists, plugin root is `${CLAUDE_PLUGIN_ROOT}`.
Otherwise, infer plugin root from workspace path `plugins/qa`.

```bash
bash <PLUGIN_ROOT>/scripts/run-qa-tests.sh --agent "<agent-id>" <mode>
```

Mode rules:
- Default to `--quick`
- Use `--full` for deep regression verification

## Diagnosis Mode (default)

1. Run QA tests
2. State pass/fail summary (passed/failed/warnings/success rate)
3. List top issues first (P0/P1), with likely root cause
4. Point to generated report path (`reports/qa-report-*.md`)
5. Offer to run again with `--fix` for automatic patching

## Fix Mode (--fix)

1. Baseline diagnosis (`--quick`)
2. Identify failures/warnings relevant to the focus area
3. Patch the smallest set of files needed (skills/config/scripts/docs)
4. Re-run `--quick` to confirm regression status
5. If user requests, run `--full`
6. Summarize what improved and what remains

## Output

- Findings (severity-ordered)
- Fixes applied (files + rationale) — only in `--fix` mode
- Verification results
- Remaining issues and suggested next fixes
