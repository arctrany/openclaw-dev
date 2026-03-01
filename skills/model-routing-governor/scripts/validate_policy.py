#!/usr/bin/env python3
"""Validate model routing policy and alias files."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List


def load_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        raise SystemExit(f"File not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}")


def parse_args() -> argparse.Namespace:
    here = Path(__file__).resolve()
    skill_root = here.parents[1]
    p = argparse.ArgumentParser(description="Validate routing policy JSON and alias map JSON.")
    p.add_argument("--policy", default=str(skill_root / "assets" / "routing-policy.json"))
    p.add_argument("--aliases", default=str(skill_root / "assets" / "alias-map.json"))
    return p.parse_args()


def validate(policy: Dict[str, Any], alias_cfg: Dict[str, Any]) -> List[str]:
    errors: List[str] = []

    for key in ["defaults", "models", "slots", "constraints", "route_rules"]:
        if key not in policy:
            errors.append(f"Missing top-level key: {key}")

    if "aliases" not in alias_cfg or not isinstance(alias_cfg["aliases"], dict):
        errors.append("alias-map.json must contain object key 'aliases'")

    models = policy.get("models", {})
    slots = policy.get("slots", {})
    route_rules = policy.get("route_rules", [])
    aliases = alias_cfg.get("aliases", {})

    if not isinstance(models, dict):
        errors.append("'models' must be an object")
        models = {}
    if not isinstance(slots, dict):
        errors.append("'slots' must be an object")
        slots = {}
    if not isinstance(route_rules, list):
        errors.append("'route_rules' must be an array")
        route_rules = []

    for slot_id, slot in slots.items():
        if "candidates" not in slot or not isinstance(slot["candidates"], list):
            errors.append(f"Slot {slot_id} must have list field 'candidates'")
            continue
        for model_id in slot["candidates"]:
            if not isinstance(model_id, str):
                errors.append(f"Slot {slot_id} has non-string candidate: {model_id!r}")
                continue
            # Allow aliases, but require either canonical model entry or alias target to exist later.
            target = aliases.get(model_id, model_id)
            if target not in models:
                errors.append(f"Slot {slot_id} candidate {model_id!r} resolves to unknown model {target!r}")

    for idx, rule in enumerate(route_rules):
        rid = rule.get("id", f"route_rules[{idx}]")
        if "stages" not in rule and "augment_stages" not in rule:
            errors.append(f"Rule {rid} must contain 'stages' or 'augment_stages'")
        for field in ["stages", "augment_stages"]:
            if field not in rule:
                continue
            if not isinstance(rule[field], list):
                errors.append(f"Rule {rid} field {field} must be a list")
                continue
            for stage in rule[field]:
                if "slot" not in stage:
                    errors.append(f"Rule {rid} has stage without 'slot'")
                    continue
                if stage["slot"] not in slots:
                    errors.append(f"Rule {rid} references unknown slot {stage['slot']!r}")

    # Alias loop detection
    for src in aliases:
        seen = set()
        cur = src
        while cur in aliases:
            if cur in seen:
                errors.append(f"Alias cycle detected starting at {src!r}")
                break
            seen.add(cur)
            cur = aliases[cur]

    return errors


def main() -> None:
    args = parse_args()
    policy = load_json(Path(args.policy))
    aliases = load_json(Path(args.aliases))
    errors = validate(policy, aliases)
    if errors:
        for err in errors:
            print(f"ERROR: {err}")
        sys.exit(1)
    print("OK: policy and alias map are structurally valid")


if __name__ == "__main__":
    main()
