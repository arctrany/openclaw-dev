---
name: evolve-openclaw-capability
description: Run a diagnosis-fix-regression loop to improve an OpenClaw agent's capabilities using the QA plugin.
argument-hint: <agent-id> [focus-area]
---

# Evolve OpenClaw Capability

Use the QA plugin to diagnose, patch, and verify improvements for an OpenClaw agent.

## Inputs

- Required: `agent-id`
- Optional: `focus-area` (examples: `memory`, `skills`, `models`, `tools`, `multimodal`)

If missing required input, ask the user.

## Workflow

1. Run a baseline diagnosis (`--quick`)
2. Identify failures/warnings relevant to the focus area
3. Patch the smallest set of files needed (skills/config/scripts/docs)
4. Re-run `--quick` to confirm regression status
5. If user requests, run `--full`
6. Summarize what improved and what remains

## Execution (portable)

If `${CLAUDE_PLUGIN_ROOT}` exists, plugin root is `${CLAUDE_PLUGIN_ROOT}`.
Otherwise, infer plugin root from workspace path `plugins/qa`.

Baseline:

```bash
bash <PLUGIN_ROOT>/scripts/run-qa-tests.sh --agent "<agent-id>" --quick
```

Regression:

```bash
bash <PLUGIN_ROOT>/scripts/run-qa-tests.sh --agent "<agent-id>" --quick
```

Deep verification (optional):

```bash
bash <PLUGIN_ROOT>/scripts/run-qa-tests.sh --agent "<agent-id>" --full
```

## Output To User

- Findings first (ordered by severity)
- Changes made (files and rationale)
- Verification result after changes
- Remaining risks / next fixes
