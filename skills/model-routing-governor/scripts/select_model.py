#!/usr/bin/env python3
"""Select a primary model and fallback chain from routing labels.

This script intentionally uses only the Python standard library.
Policy and alias config are JSON for zero-dependency portability.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple


def _load_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        raise SystemExit(f"File not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}")


def _canonicalize(model_id: str, alias_map: Dict[str, str]) -> str:
    seen = set()
    cur = model_id
    while cur in alias_map and cur not in seen:
        seen.add(cur)
        cur = alias_map[cur]
    return cur


def _match_fields(labels: Dict[str, str], cond: Dict[str, Any]) -> bool:
    for key, expected in cond.items():
        actual = labels.get(key)
        if isinstance(expected, list):
            if actual not in expected:
                return False
        else:
            if actual != expected:
                return False
    return True


def _rule_matches(labels: Dict[str, str], rule: Dict[str, Any]) -> bool:
    if "when" in rule and not _match_fields(labels, rule["when"]):
        return False
    if "when_any" in rule:
        any_ok = False
        for cond in rule["when_any"]:
            if _match_fields(labels, cond):
                any_ok = True
                break
        if not any_ok:
            return False
    return True


def _stage_key(stage: Dict[str, Any]) -> Tuple[str, str]:
    return (stage.get("name", "primary"), stage["slot"])


def _apply_stage_augmentation(stages: List[Dict[str, Any]], aug: Dict[str, Any]) -> List[Dict[str, Any]]:
    position = aug.get("position", "append")
    new_stage = {k: v for k, v in aug.items() if k != "position"}
    if position == "prepend":
        return [new_stage] + stages
    return stages + [new_stage]


def _dedupe_stage_list(stages: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    seen = set()
    out = []
    for stage in stages:
        key = _stage_key(stage)
        if key in seen:
            continue
        seen.add(key)
        out.append(stage)
    return out


def _provider_of(model_id: str, policy_models: Dict[str, Any]) -> str:
    return str(policy_models.get(model_id, {}).get("provider", model_id.split("/", 1)[0]))


def _blocked_model(model_id: str, provider: str, constraint_ctx: Dict[str, Any]) -> Tuple[bool, str]:
    for banned_provider in constraint_ctx["ban_providers"]:
        if provider == banned_provider:
            return True, f"provider:{banned_provider}"
    for prefix in constraint_ctx["ban_model_prefixes"]:
        if model_id.startswith(prefix):
            return True, f"prefix:{prefix}"
    return False, ""


def _parse_args() -> argparse.Namespace:
    here = Path(__file__).resolve()
    skill_root = here.parents[1]
    parser = argparse.ArgumentParser(description="Resolve model route from labels.")
    parser.add_argument("--policy", default=str(skill_root / "assets" / "routing-policy.json"))
    parser.add_argument("--aliases", default=str(skill_root / "assets" / "alias-map.json"))
    parser.add_argument("--labels-json", help="JSON object with routing labels")
    parser.add_argument("--scene")
    parser.add_argument("--sensitivity")
    parser.add_argument("--task-type", dest="task_type")
    parser.add_argument("--modality")
    parser.add_argument("--complexity")
    parser.add_argument("--value")
    parser.add_argument("--context-size", dest="context_size")
    parser.add_argument("--language")
    parser.add_argument("--latency-budget", dest="latency_budget")
    parser.add_argument("--cost-budget", dest="cost_budget")
    parser.add_argument("--privacy-requirement", dest="privacy_requirement")
    parser.add_argument("--provider-preference", dest="provider_preference")
    parser.add_argument("--available-model", action="append", default=[], help="Repeatable. Only these canonical models are allowed if provided.")
    parser.add_argument("--deny-model-prefix", action="append", default=[], help="Extra banned model prefixes.")
    parser.add_argument("--pretty", action="store_true")
    return parser.parse_args()


def _merge_labels(defaults: Dict[str, str], args: argparse.Namespace) -> Dict[str, str]:
    labels = dict(defaults)
    if args.labels_json:
        try:
            labels.update(json.loads(args.labels_json))
        except json.JSONDecodeError as exc:
            raise SystemExit(f"--labels-json is not valid JSON: {exc}")
    for key in [
        "scene",
        "sensitivity",
        "task_type",
        "modality",
        "complexity",
        "value",
        "context_size",
        "language",
        "latency_budget",
        "cost_budget",
        "privacy_requirement",
        "provider_preference",
    ]:
        value = getattr(args, key, None)
        if value is not None:
            labels[key] = value
    return {k: str(v) for k, v in labels.items()}


def _resolve_route(policy: Dict[str, Any], labels: Dict[str, str]) -> Tuple[List[Dict[str, Any]], List[str], List[str], Dict[str, Any]]:
    rules = sorted(policy["route_rules"], key=lambda r: int(r.get("priority", 1000)))
    constraints = policy.get("constraints", [])

    stages: List[Dict[str, Any]] = []
    matched_rules: List[str] = []
    notes: List[str] = []

    constraint_ctx = {
        "ban_providers": [],
        "ban_model_prefixes": [],
        "prefer_providers": []
    }
    matched_constraints: List[str] = []

    for c in constraints:
        if _rule_matches(labels, c):
            matched_constraints.append(c.get("id", "unnamed_constraint"))
            constraint_ctx["ban_providers"].extend(c.get("ban_providers", []))
            constraint_ctx["ban_model_prefixes"].extend(c.get("ban_model_prefixes", []))
            constraint_ctx["prefer_providers"].extend(c.get("prefer_providers", []))
            if c.get("reason"):
                notes.append(c["reason"])

    for rule in rules:
        if not _rule_matches(labels, rule):
            continue
        matched_rules.append(rule.get("id", "unnamed_rule"))
        if "stages" in rule:
            stages = [dict(s) for s in rule["stages"]]
        for aug in rule.get("augment_stages", []):
            stages = _apply_stage_augmentation(stages, aug)
        notes.extend(rule.get("notes", []))

    stages = _dedupe_stage_list(stages)
    return stages, matched_rules, matched_constraints, constraint_ctx


def _expand_candidates(
    policy: Dict[str, Any],
    alias_map: Dict[str, str],
    stages: List[Dict[str, Any]],
    constraint_ctx: Dict[str, Any],
    available: Iterable[str],
    extra_deny_prefixes: List[str]
) -> Dict[str, Any]:
    slots = policy["slots"]
    models = policy.get("models", {})
    available_set = set(available)
    enforce_available = bool(available_set)
    extra_deny_prefixes = list(extra_deny_prefixes)

    stage_plan = []
    flattened: List[str] = []
    blocked: List[Dict[str, str]] = []

    for stage in stages:
        slot_id = stage["slot"]
        slot = slots.get(slot_id)
        if not slot:
            stage_plan.append({
                "stage": stage.get("name", "primary"),
                "slot": slot_id,
                "candidates": [],
                "warning": "missing_slot"
            })
            continue

        kept_candidates: List[str] = []
        for raw_model in slot.get("candidates", []):
            model_id = _canonicalize(raw_model, alias_map)
            provider = _provider_of(model_id, models)
            is_blocked, why = _blocked_model(model_id, provider, constraint_ctx)
            if not is_blocked:
                for prefix in extra_deny_prefixes:
                    if model_id.startswith(prefix):
                        is_blocked = True
                        why = f"cli_prefix:{prefix}"
                        break
            if is_blocked:
                blocked.append({"model": model_id, "reason": why, "stage": stage.get("name", "primary")})
                continue
            if enforce_available and model_id not in available_set:
                blocked.append({"model": model_id, "reason": "not_in_available_set", "stage": stage.get("name", "primary")})
                continue
            kept_candidates.append(model_id)

        # Soft reordering for preferred providers.
        preferred = constraint_ctx.get("prefer_providers", [])
        if preferred:
            preferred_set = set(preferred)
            kept_candidates = sorted(
                kept_candidates,
                key=lambda m: (0 if _provider_of(m, models) in preferred_set else 1, kept_candidates.index(m))
            )

        stage_plan.append({
            "stage": stage.get("name", "primary"),
            "slot": slot_id,
            "candidates": kept_candidates
        })
        flattened.extend(kept_candidates)

    deduped_flat: List[str] = []
    seen = set()
    for m in flattened:
        if m in seen:
            continue
        seen.add(m)
        deduped_flat.append(m)

    primary = deduped_flat[0] if deduped_flat else None
    fallbacks = deduped_flat[1:] if len(deduped_flat) > 1 else []
    return {
        "stage_plan": stage_plan,
        "primary": primary,
        "fallbacks": fallbacks,
        "blocked": blocked
    }


def main() -> None:
    args = _parse_args()
    policy_path = Path(args.policy)
    aliases_path = Path(args.aliases)

    policy = _load_json(policy_path)
    aliases = _load_json(aliases_path).get("aliases", {})

    labels = _merge_labels(policy.get("defaults", {}), args)
    stages, matched_rules, matched_constraints, constraint_ctx = _resolve_route(policy, labels)
    result = _expand_candidates(
        policy=policy,
        alias_map=aliases,
        stages=stages,
        constraint_ctx=constraint_ctx,
        available=[_canonicalize(x, aliases) for x in args.available_model],
        extra_deny_prefixes=args.deny_model_prefix
    )

    output = {
        "labels": labels,
        "matched_rules": matched_rules,
        "matched_constraints": matched_constraints,
        "blocked_providers": sorted(set(constraint_ctx["ban_providers"])),
        "blocked_model_prefixes": sorted(set(constraint_ctx["ban_model_prefixes"] + args.deny_model_prefix)),
        "primary": result["primary"],
        "fallbacks": result["fallbacks"],
        "stage_plan": result["stage_plan"],
        "blocked_models": result["blocked"]
    }

    if args.pretty:
        print(json.dumps(output, indent=2, ensure_ascii=False))
    else:
        print(json.dumps(output, ensure_ascii=False))

    if not result["primary"]:
        sys.exit(2)


if __name__ == "__main__":
    main()
