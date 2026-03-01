---
name: evolve-openclaw-capability
description: Diagnose, patch, and regress-test OpenClaw capabilities using the toolkit's QA module.
argument-hint: <agent-id> [focus-area]
---

# Evolve OpenClaw Capability (Toolkit)

Run a diagnosis-fix-regression loop using `plugins/qa`.

## Inputs

- Required: `agent-id`
- Optional: `focus-area` (`memory`, `skills`, `models`, `tools`, `multimodal`)

If `agent-id` is missing, ask the user.

## Workflow

1. Baseline diagnosis (`--quick`)
2. Prioritize failures/warnings (P0/P1 first)
3. Apply smallest viable fixes
4. Re-run `--quick`
5. Run `--full` if requested or before closing high-impact work
6. Summarize improvements and remaining risks

## Execution

Claude/OpenClaw runtime:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/plugins/qa/scripts/run-qa-tests.sh --agent "<agent-id>" --quick
```

Fallback (workspace runtime / Codex-style execution):

```bash
bash plugins/qa/scripts/run-qa-tests.sh --agent "<agent-id>" --quick
```

## Output To User

- Findings (severity-ordered)
- Fixes applied (files + rationale)
- Verification results
- Remaining issues and suggested next fixes
