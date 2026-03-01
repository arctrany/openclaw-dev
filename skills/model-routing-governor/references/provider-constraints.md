# Provider Constraints (Operational)

This file captures routing-relevant provider constraints. Keep it short and practical.

## Principle

Treat provider moderation behavior as a routing input, not a prompt problem.

If a provider blocks a category at the platform level, solve it by:
- routing to a different provider/model, or
- splitting workflows into separate agents/sessions

Do not assume prompt edits can reliably bypass provider-side red lines.

## Common Constraint Types

- `moderation_redline`: provider may block input/output based on full context
- `auth_missing`: model is configured but not currently usable
- `rate_limit`: temporary throttling
- `timeout_risk`: unstable latency for large prompts
- `modality_gap`: model lacks required modality support

## Recommended Policy Encoding

Encode constraints in policy, not prose-only docs:
- provider bans by sensitivity (`intimate`, `sensitive_research`)
- context-size requirements
- modality requirements
- auth/availability filtering (runtime input)

## Example Operational Rule

- `sensitive_research`:
  - prefer non-Bailian/Qwen providers
  - use long-context + strong synthesis models
  - keep text processing in a cheaper compatible slot

## Model Change SOP (Short)

When a model changes:
1. Update `alias-map.json`
2. Update slot candidates in `routing-policy.json`
3. Validate policy
4. Run smoke routes for affected task types
5. Roll forward or revert

This keeps route logic stable while model names evolve.
