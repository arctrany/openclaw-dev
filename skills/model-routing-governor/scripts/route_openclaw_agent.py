#!/usr/bin/env python3
"""Select a route and optionally execute `openclaw agent` with the chosen agent.

This is a practical pre-router wrapper:
- uses select_model.py for model route reasoning
- chooses an OpenClaw agent via agent-routing rules
- prints a dry-run plan by default
- can execute `openclaw agent` with --run
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List


def _load_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        raise SystemExit(f"File not found: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}")


def _match_fields(labels: Dict[str, str], cond: Dict[str, Any]) -> bool:
    for k, v in cond.items():
        actual = labels.get(k)
        if isinstance(v, list):
            if actual not in v:
                return False
        else:
            if actual != v:
                return False
    return True


def _labels_from_args(args: argparse.Namespace, defaults: Dict[str, str]) -> Dict[str, str]:
    labels = dict(defaults)
    if args.labels_json:
        try:
            labels.update(json.loads(args.labels_json))
        except json.JSONDecodeError as exc:
            raise SystemExit(f"--labels-json invalid JSON: {exc}")
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
        val = getattr(args, key, None)
        if val is not None:
            labels[key] = val
    return {k: str(v) for k, v in labels.items()}


def _route_models(select_model: Path, labels: Dict[str, str]) -> Dict[str, Any]:
    cmd = [sys.executable, str(select_model), "--labels-json", json.dumps(labels)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode not in (0, 2):
        raise SystemExit(f"select_model failed rc={proc.returncode}: {proc.stderr.strip() or proc.stdout.strip()}")
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"select_model output is not JSON: {exc}")


def _pick_agent(agent_cfg: Dict[str, Any], labels: Dict[str, str]) -> Dict[str, Any]:
    defaults = agent_cfg.get("defaults", {})
    chosen = {
        "agent": defaults.get("agent", "annie"),
        "matched_rule": None,
        "notes": []
    }
    rules = sorted(agent_cfg.get("rules", []), key=lambda r: int(r.get("priority", 1000)))
    for rule in rules:
        if _match_fields(labels, rule.get("when", {})):
            chosen["agent"] = rule["agent"]
            chosen["matched_rule"] = rule.get("id")
            chosen["notes"] = list(rule.get("notes", []))
            break
    return chosen


def _pick_thinking(agent_cfg: Dict[str, Any], labels: Dict[str, str], override: str | None) -> str | None:
    if override:
        return override
    defaults = agent_cfg.get("defaults", {})
    by_value = defaults.get("thinking_by_value", {})
    by_complexity = defaults.get("thinking_by_complexity", {})
    value = labels.get("value")
    complexity = labels.get("complexity")
    if value in by_value:
        return by_value[value]
    if complexity in by_complexity:
        return by_complexity[complexity]
    return None


def _build_openclaw_cmd(args: argparse.Namespace, agent_id: str, thinking: str | None) -> List[str]:
    if not args.message and not args.stdin_message:
        raise SystemExit("Provide --message or --stdin-message when using this wrapper.")
    cmd = ["openclaw", "agent", "--agent", agent_id]
    if args.message:
        cmd.extend(["--message", args.message])
    if args.to:
        cmd.extend(["--to", args.to])
    if args.session_id:
        cmd.extend(["--session-id", args.session_id])
    if args.local:
        cmd.append("--local")
    if args.deliver:
        cmd.append("--deliver")
    if args.json_output:
        cmd.append("--json")
    if thinking:
        cmd.extend(["--thinking", thinking])
    if args.timeout is not None:
        cmd.extend(["--timeout", str(args.timeout)])
    return cmd


def _parse_args() -> argparse.Namespace:
    here = Path(__file__).resolve()
    skill_root = here.parents[1]
    p = argparse.ArgumentParser(description="Route labels to OpenClaw agent and optionally run.")
    p.add_argument("--select-model", default=str(skill_root / "scripts" / "select_model.py"))
    p.add_argument("--agent-routing", default=str(skill_root / "assets" / "openclaw-agent-routing.json"))
    p.add_argument("--policy", default=str(skill_root / "assets" / "routing-policy.json"))
    p.add_argument("--labels-json")
    p.add_argument("--scene")
    p.add_argument("--sensitivity")
    p.add_argument("--task-type", dest="task_type")
    p.add_argument("--modality")
    p.add_argument("--complexity")
    p.add_argument("--value")
    p.add_argument("--context-size", dest="context_size")
    p.add_argument("--language")
    p.add_argument("--latency-budget", dest="latency_budget")
    p.add_argument("--cost-budget", dest="cost_budget")
    p.add_argument("--privacy-requirement", dest="privacy_requirement")
    p.add_argument("--provider-preference", dest="provider_preference")
    p.add_argument("--message")
    p.add_argument("--stdin-message", action="store_true", help="Read message body from stdin.")
    p.add_argument("--to")
    p.add_argument("--session-id")
    p.add_argument("--local", action="store_true")
    p.add_argument("--deliver", action="store_true")
    p.add_argument("--timeout", type=int)
    p.add_argument("--thinking", choices=["off", "minimal", "low", "medium", "high"])
    p.add_argument("--json-output", action="store_true", help="Pass --json to openclaw agent")
    p.add_argument("--run", action="store_true", help="Execute openclaw agent. Default is dry-run.")
    p.add_argument("--pretty", action="store_true")
    return p.parse_args()


def main() -> None:
    args = _parse_args()
    policy = _load_json(Path(args.policy))
    labels = _labels_from_args(args, policy.get("defaults", {}))

    if args.stdin_message:
        args.message = sys.stdin.read().strip()

    model_route = _route_models(Path(args.select_model), labels)
    agent_cfg = _load_json(Path(args.agent_routing))
    agent_pick = _pick_agent(agent_cfg, labels)
    thinking = _pick_thinking(agent_cfg, labels, args.thinking)
    cmd = _build_openclaw_cmd(args, agent_pick["agent"], thinking)

    result: Dict[str, Any] = {
        "labels": labels,
        "agent": agent_pick["agent"],
        "agent_rule": agent_pick.get("matched_rule"),
        "agent_notes": agent_pick.get("notes", []),
        "thinking": thinking,
        "model_route": {
            "primary": model_route.get("primary"),
            "fallbacks": model_route.get("fallbacks", []),
            "stage_plan": model_route.get("stage_plan", []),
            "matched_rules": model_route.get("matched_rules", []),
            "matched_constraints": model_route.get("matched_constraints", []),
            "blocked_providers": model_route.get("blocked_providers", [])
        },
        "openclaw_command": cmd,
        "executed": False
    }

    if args.run:
        proc = subprocess.run(cmd, text=True, capture_output=True)
        result["executed"] = True
        result["returncode"] = proc.returncode
        result["stdout"] = proc.stdout
        result["stderr"] = proc.stderr
        if args.pretty:
            print(json.dumps(result, indent=2, ensure_ascii=False))
        else:
            print(json.dumps(result, ensure_ascii=False))
        sys.exit(proc.returncode)
    else:
        if args.pretty:
            print(json.dumps(result, indent=2, ensure_ascii=False))
        else:
            print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
