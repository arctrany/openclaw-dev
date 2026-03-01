#!/usr/bin/env python3
"""Convenience wrapper for model-routing-governor route_openclaw_agent.py.

Provides short presets for common scenarios while preserving full override support.
"""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from pathlib import Path
from typing import Dict


PRESETS: Dict[str, Dict[str, str]] = {
    "sensitive-research": {
        "scene": "work",
        "task_type": "deep_research",
        "sensitivity": "sensitive_research",
        "complexity": "high",
        "value": "high",
        "context_size": "long",
    },
    "research-cn": {
        "scene": "work",
        "task_type": "deep_research",
        "sensitivity": "normal",
        "provider_preference": "domestic_first",
        "complexity": "medium",
        "value": "normal",
    },
    "research-cn-high": {
        "scene": "work",
        "task_type": "deep_research",
        "sensitivity": "normal",
        "provider_preference": "domestic_first",
        "complexity": "high",
        "value": "high",
        "context_size": "long",
    },
    "coding-cn": {
        "scene": "work",
        "task_type": "coding",
        "provider_preference": "domestic_first",
        "complexity": "high",
        "value": "high",
        "context_size": "long",
    },
    "private": {
        "scene": "private",
        "sensitivity": "intimate",
        "task_type": "writing",
        "complexity": "low",
        "value": "normal",
        "privacy_requirement": "strict",
    },
    "private-complex": {
        "scene": "private",
        "sensitivity": "intimate",
        "task_type": "writing",
        "complexity": "high",
        "value": "high",
        "privacy_requirement": "strict",
    },
    "work-complex": {
        "scene": "work",
        "sensitivity": "normal",
        "task_type": "planning",
        "complexity": "high",
        "value": "high",
    },
}


LABEL_KEYS = [
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
]


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Shortcut wrapper for routed OpenClaw agent execution.",
        formatter_class=argparse.RawTextHelpFormatter,
        epilog=(
            "Examples:\n"
            "  oc-route.py sensitive-research -m '先给我一版调研框架' --pretty\n"
            "  oc-route.py coding-cn -m '重构这个模块并加测试' --run --pretty\n"
            "  oc-route.py research-cn --message '调研这个赛道' --run --to +15555550123 --deliver\n"
        ),
    )
    p.add_argument("preset", nargs="?", default="sensitive-research", help="Preset name (use --list-presets)")
    p.add_argument("--list-presets", action="store_true", help="List available presets and exit")
    p.add_argument("-m", "--message", help="Message text for OpenClaw agent")
    p.add_argument("--stdin-message", action="store_true", help="Read message body from stdin")
    p.add_argument("--run", action="store_true", help="Execute OpenClaw agent (default is dry-run)")
    p.add_argument("--pretty", action="store_true", help="Pretty-print JSON output")
    p.add_argument("--show-command", action="store_true", help="Print delegated command before execution")

    for key in LABEL_KEYS:
        cli = "--" + key.replace("_", "-")
        p.add_argument(cli, dest=key)

    p.add_argument("--to")
    p.add_argument("--session-id")
    p.add_argument("--local", action="store_true")
    p.add_argument("--deliver", action="store_true")
    p.add_argument("--timeout", type=int)
    p.add_argument("--thinking", choices=["off", "minimal", "low", "medium", "high"])
    p.add_argument("--json-output", action="store_true", help="Pass --json to openclaw agent")
    return p


def print_presets() -> None:
    print("Available presets:")
    for name in sorted(PRESETS):
        labels = " ".join(f"{k}={v}" for k, v in PRESETS[name].items())
        print(f"  {name:18} {labels}")


def main() -> None:
    args = build_parser().parse_args()
    if args.list_presets:
        print_presets()
        return

    if args.preset not in PRESETS:
        print(f"Unknown preset: {args.preset}", file=sys.stderr)
        print("Use --list-presets to see valid values.", file=sys.stderr)
        sys.exit(2)

    repo_root = Path(__file__).resolve().parents[1]
    route_script = repo_root / "skills" / "model-routing-governor" / "scripts" / "route_openclaw_agent.py"
    if not route_script.exists():
        print(f"Missing route script: {route_script}", file=sys.stderr)
        sys.exit(2)

    labels = dict(PRESETS[args.preset])
    for key in LABEL_KEYS:
        val = getattr(args, key)
        if val is not None:
            labels[key] = val

    cmd = [sys.executable, str(route_script), "--labels-json", json.dumps(labels)]
    if args.message:
        cmd.extend(["--message", args.message])
    if args.stdin_message:
        cmd.append("--stdin-message")
    if args.to:
        cmd.extend(["--to", args.to])
    if args.session_id:
        cmd.extend(["--session-id", args.session_id])
    if args.local:
        cmd.append("--local")
    if args.deliver:
        cmd.append("--deliver")
    if args.timeout is not None:
        cmd.extend(["--timeout", str(args.timeout)])
    if args.thinking:
        cmd.extend(["--thinking", args.thinking])
    if args.json_output:
        cmd.append("--json-output")
    if args.pretty:
        cmd.append("--pretty")
    if args.run:
        cmd.append("--run")

    default_preview_message = None
    if not args.message and not args.stdin_message:
        # Keep dry-run useful even without a message.
        default_preview_message = "(dry-run route preview)"
        cmd.extend(["--message", default_preview_message])

    if args.show_command:
        print(shlex.join(cmd), flush=True)

    proc = subprocess.run(cmd, text=True, input=None if not args.stdin_message else sys.stdin.read())
    raise SystemExit(proc.returncode)


if __name__ == "__main__":
    main()
