---
name: model-routing-governor
description: Use this skill when the user asks to design, implement, audit, or evolve model routing policies across multiple providers/models (for example work/private routing, coding vs research routing, provider safety constraints, fallback chains, slot/alias-based routing, or future-proof model name migration). Includes a runnable router and policy validator.
metadata: {"clawdbot":{"always":false,"emoji":"🧭","requires":{"bins":["python3"]}}}
user-invocable: true
version: 0.2.0
---

# Model Routing Governor

## Purpose

This skill standardizes how to choose models across providers using:
- `slot`-based routing (stable intent labels, not hard-coded model names)
- `alias_map` compatibility (model renames and provider ID changes)
- explicit hard constraints (privacy/sensitive content/provider bans)
- task-specific fallback chains

Use this skill to build or maintain a routing system that can be shared across Claude/Codex/OpenClaw-style runtimes.

## When To Use

Use this skill when the user asks for any of the following:
- "Which model should I use for X?"
- "Design a routing policy across many models/providers"
- "Work/private/sensitive routing policy"
- "Coding should prefer domestic models, but escalate on hard tasks"
- "How do we handle future model name changes?"
- "Create a router script / policy config / fallback chain"
- "Audit current model routing"

## What This Skill Provides

- A reference task taxonomy and routing dimensions
- A provider-constraint reference (including moderation routing implications)
- A runnable router CLI: `scripts/select_model.py`
- A policy checker: `scripts/validate_policy.py`
- A smoke-test runner for standard scenarios: `scripts/smoke_test_routes.py`
- An OpenClaw route-and-run wrapper: `scripts/route_openclaw_agent.py`
- A short preset wrapper for daily use (repo root): `scripts/oc-route.py`
- A sample `slot + alias_map` policy in JSON

## Quick Start

1. Validate policy files:

```bash
python3 skills/model-routing-governor/scripts/validate_policy.py
```

2. Select a route for sensitive deep research:

```bash
python3 skills/model-routing-governor/scripts/select_model.py \
  --scene work \
  --task-type deep_research \
  --sensitivity sensitive_research \
  --complexity high \
  --value high \
  --context-size long \
  --pretty
```

3. Select a route for domestic-first coding:

```bash
python3 skills/model-routing-governor/scripts/select_model.py \
  --scene work \
  --task-type coding \
  --provider-preference domestic_first \
  --complexity high \
  --value high \
  --context-size long \
  --pretty
```

4. Run standard smoke tests after model updates:

```bash
python3 skills/model-routing-governor/scripts/smoke_test_routes.py --pretty
```

5. Route to an OpenClaw agent (dry-run first):

```bash
python3 skills/model-routing-governor/scripts/route_openclaw_agent.py \
  --scene work \
  --task-type deep_research \
  --sensitivity sensitive_research \
  --complexity high \
  --value high \
  --message "先给我一版调研框架" \
  --pretty
```

6. Use the short preset wrapper for daily usage:

```bash
oc-route sensitive-research -m "先给我一版调研框架" --pretty
oc-route research-cn -m "调研这个赛道" --run --pretty
oc-route coding-cn -m "重构模块并加测试" --run --pretty
```

If `oc-route` is not installed on PATH yet, use `python3 scripts/oc-route.py ...`.

## Router Workflow

### 1) Normalize labels

Collect or infer routing labels (see `references/task-taxonomy.md`):
- `scene`
- `sensitivity`
- `task_type`
- `modality`
- `complexity`
- `value`
- `context_size`
- `language`
- `latency_budget`
- `cost_budget`
- `privacy_requirement`
- `provider_preference`

### 2) Apply hard constraints first

Before ranking models, apply non-negotiable constraints:
- private/intimate blocks on certain providers
- sensitive research provider blocks
- modality requirements
- context requirements
- runtime availability/auth restrictions (when provided)

Provider-specific caveats are in `references/provider-constraints.md`.

### 3) Resolve route stages via slots

A route is a list of stages, each stage points to a `slot`:
- Example: sensitive deep research can use separate slots for:
  - primary investigation
  - text processing / summarization
  - high-value synthesis

Slots are stable intent labels. Their concrete candidates live in policy JSON.

### 4) Canonicalize model IDs via alias map

Always normalize model IDs through alias mapping before final output. This prevents policy drift when provider/model IDs change.

### 5) Emit route result

Return:
- normalized labels
- chosen stage plan (`stage -> slot`)
- `primary`
- `fallbacks`
- blocked providers/prefixes
- reasons / matched rules

## Files In This Skill

- `assets/routing-policy.json`
  - Source of truth for slots, constraints, route rules, and model metadata.
- `assets/alias-map.json`
  - Compatible aliases and canonical IDs.
- `scripts/select_model.py`
  - Resolves a route from labels.
- `scripts/validate_policy.py`
  - Validates policy structure and slot references.
- `scripts/smoke_test_routes.py`
  - Runs standard scenario smoke tests against the current router.
- `scripts/route_openclaw_agent.py`
  - Picks an OpenClaw agent based on labels and (optionally) runs `openclaw agent`.
- `scripts/oc-route.py` (repo root)
  - Short preset wrapper for common routed execution scenarios.
- `assets/smoke-routes.json`
  - Test cases + assertions used after model/policy changes.
- `assets/openclaw-agent-routing.json`
  - Agent selection rules (for example `annie-research` vs `annie-research-cn`).
- `references/task-taxonomy.md`
  - Label vocabulary and routing dimensions.
- `references/provider-constraints.md`
  - Provider safety and operational constraints.
- `references/model-change-sop.md`
  - Model rename/upgrade/deprecation procedure, rollout, rollback, and validation checklist.

## How To Extend

### Add a new model

1. Add model metadata to `assets/routing-policy.json` under `models`.
2. Add aliases (if needed) to `assets/alias-map.json`.
3. Add model to one or more `slots`.
4. Run validator.
5. Smoke-test relevant routes with `select_model.py`.

### Handle model rename / deprecation

1. Add alias old -> new in `assets/alias-map.json`
2. Update slot candidates to prefer the new canonical ID
3. Keep alias for backward compatibility during migration
4. Validate + smoke-test
5. Run `scripts/smoke_test_routes.py` before rollout

### Add a new task category

1. Add route rules in `assets/routing-policy.json`
2. Add slot(s) if needed
3. Document label expectations in `references/task-taxonomy.md`
4. Validate + smoke-test
5. Run `scripts/smoke_test_routes.py`

## Integration Guidance

This skill is the *knowledge + tooling* layer. For hard guarantees in production:
- Use a runtime pre-router (hook/script) **or**
- Use separate agents with different primaries

Do not rely on prompt-only routing if the runtime can dispatch to a blocked provider before the model reads the policy.

For ongoing maintenance, follow `references/model-change-sop.md`.

The provided `scripts/route_openclaw_agent.py` is the starter implementation for a pre-router wrapper around `openclaw agent`.
For day-to-day operator usage, prefer repo-root `scripts/oc-route.py` presets and override labels only when needed.

## Output Contract (Recommended)

When reporting a routing decision, return:
- labels used
- primary model
- fallbacks
- blocked providers/patterns
- why this route was chosen
- any runtime caveat (auth missing, provider unavailable, etc.)

Keep the explanation concise and operational.
