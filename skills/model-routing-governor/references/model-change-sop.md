# Model Change SOP (Standard Operating Procedure)

Use this procedure whenever a model is renamed, replaced, added, removed, or behaves differently (quality, latency, moderation, auth).

## Change Types

Classify the change first:

- `rename`: provider/model ID changed, capabilities mostly unchanged
- `upgrade`: new version should replace or precede existing version
- `deprecation`: existing model should be removed from slots
- `behavior_change`: moderation/quality/latency changed
- `availability_change`: auth missing, rate-limit, timeout spikes, regional outage

## Source of Truth

Treat these files as the routing source of truth:

- `assets/routing-policy.json` — slots, constraints, route rules, model metadata
- `assets/alias-map.json` — backwards-compatible naming and canonical IDs

Do not patch many docs first. Update policy + alias map, validate, then update docs if needed.

## Step-by-Step Procedure

### 1) Update aliases (if rename)

Edit `assets/alias-map.json`:
- add old name -> new canonical name
- keep old alias during migration window

Example:

```json
{
  "aliases": {
    "openai/gpt-5.3-codex": "openai-codex/gpt-5.3-codex"
  }
}
```

### 2) Update model metadata

Edit `assets/routing-policy.json`:
- add new model under `models`
- set provider + capability tags
- set cost/latency tiers

If removing a model, delete it from `slots` first, then remove from `models`.

### 3) Update slot candidates

Change only slot candidate ordering/candidates unless route logic truly changed.

Examples:
- new version preferred → put it first in relevant slots
- degraded provider → move lower in slot order
- moderation issues → remove from sensitive/private slots

### 4) Update constraints (if behavior changed)

If moderation or provider safety behavior changed:
- update `constraints`
- add/remove provider bans by sensitivity
- document the rationale in the commit or policy note

### 5) Validate policy

```bash
python3 skills/model-routing-governor/scripts/validate_policy.py
```

This catches:
- unknown slot references
- unknown models in slot candidates
- alias cycles
- malformed route rules

### 6) Run smoke tests

```bash
python3 skills/model-routing-governor/scripts/smoke_test_routes.py --pretty
```

Smoke tests should at minimum cover:
- sensitive deep research (must avoid blocked providers)
- private/intimate (must avoid Bailian/Qwen by default)
- coding high complexity (must include Codex critical route)
- domestic-first research/coding (must include domestic pool)

### 7) Runtime verification (optional but recommended)

If integrated with OpenClaw:
- verify `openclaw models list` auth/availability
- run one real route in each affected agent
- confirm fallback behavior if primary fails

### 8) Rollout strategy

Recommended rollout:
- apply to `annie-research` or a non-default agent first
- observe 1-3 days (failure rate, fallback rate, latency)
- promote to broader usage after stable results

### 9) Rollback plan

Keep rollback simple:
- revert `routing-policy.json` and/or `alias-map.json`
- rerun validator + smoke tests
- restore last known good slot order

## Decision Rules

### Rename only

- Usually update `alias-map.json` only
- no route rule changes
- smoke-test a couple of affected scenarios

### Version upgrade (same family)

- add new model metadata
- insert into existing slots ahead of old version
- keep old version as fallback
- smoke-test affected scenarios

### Provider moderation changed

- treat as constraint change, not prompt change
- update `constraints` or slot membership
- verify sensitive/private smoke tests

### Auth unavailable

- do not delete the model immediately if temporary
- prefer runtime availability filtering (available model list)
- downgrade slot order if persistent

## Documentation Update Rule

After policy changes:
- update `MODEL_USAGE_PROTOCOL.md` only if principles changed
- avoid duplicating exact candidate lists in prose docs
- point readers to routing policy files for current model lists

## Change Log Template (Recommended)

Copy into commit message or change note:

```text
Routing policy update
- Change type: upgrade | rename | behavior_change | deprecation
- Slots affected: ...
- Constraints affected: ...
- Alias changes: ...
- Validation: PASS
- Smoke tests: PASS (cases: ...)
- Rollout target: annie-research | annie-research-cn | all
- Rollback trigger: ...
```
