#!/usr/bin/env python3
"""Run standard smoke tests against the routing policy."""

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


def _parse_args() -> argparse.Namespace:
    here = Path(__file__).resolve()
    skill_root = here.parents[1]
    p = argparse.ArgumentParser(description="Run routing smoke tests.")
    p.add_argument("--cases", default=str(skill_root / "assets" / "smoke-routes.json"))
    p.add_argument("--router", default=str(skill_root / "scripts" / "select_model.py"))
    p.add_argument("--case-id", action="append", default=[], help="Run only specific case id(s)")
    p.add_argument("--pretty", action="store_true", help="Pretty-print failures/results")
    return p.parse_args()


def _run_router(router: Path, labels: Dict[str, Any]) -> Dict[str, Any]:
    cmd = [sys.executable, str(router), "--labels-json", json.dumps(labels)]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode not in (0, 2):
        raise RuntimeError(f"router failed rc={proc.returncode}: {proc.stderr.strip() or proc.stdout.strip()}")
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"router output is not JSON: {exc}: {proc.stdout[:500]}")


def _flatten_models(out: Dict[str, Any]) -> List[str]:
    models = []
    if out.get("primary"):
        models.append(out["primary"])
    models.extend(out.get("fallbacks", []))
    return models


def _stage_slots(out: Dict[str, Any]) -> List[str]:
    return [s.get("slot") for s in out.get("stage_plan", []) if s.get("slot")]


def _assert_case(case: Dict[str, Any], out: Dict[str, Any]) -> List[str]:
    errs: List[str] = []
    a = case.get("assertions", {})
    primary = out.get("primary")
    all_models = _flatten_models(out)
    blocked_providers = set(out.get("blocked_providers", []))
    slots = set(_stage_slots(out))

    if "primary_in" in a and primary not in set(a["primary_in"]):
        errs.append(f"primary {primary!r} not in primary_in")

    if "primary_in_prefixes" in a:
        prefixes = a["primary_in_prefixes"]
        if primary is None or not any(str(primary).startswith(p) for p in prefixes):
            errs.append(f"primary {primary!r} does not match any required prefix {prefixes!r}")

    if "blocked_providers_contains" in a:
        for p in a["blocked_providers_contains"]:
            if p not in blocked_providers:
                errs.append(f"blocked_providers missing {p!r}")

    if "must_not_include_prefixes" in a:
        for m in all_models:
            for prefix in a["must_not_include_prefixes"]:
                if m.startswith(prefix):
                    errs.append(f"route includes forbidden model prefix {prefix!r}: {m}")

    if "stage_slots_include" in a:
        for slot in a["stage_slots_include"]:
            if slot not in slots:
                errs.append(f"stage slots missing {slot!r}")

    if "list_includes" in a:
        all_set = set(all_models)
        for m in a["list_includes"]:
            if m not in all_set:
                errs.append(f"route models missing required candidate {m!r}")

    return errs


def main() -> None:
    args = _parse_args()
    cases_doc = _load_json(Path(args.cases))
    router = Path(args.router)
    selected = set(args.case_id)

    cases = cases_doc.get("cases", [])
    if selected:
        cases = [c for c in cases if c.get("id") in selected]
        missing = sorted(selected - {c.get("id") for c in cases})
        if missing:
            print(f"ERROR: Unknown case id(s): {', '.join(missing)}")
            sys.exit(2)

    failures = 0
    results = []
    for case in cases:
        cid = case.get("id", "unknown")
        try:
            out = _run_router(router, case.get("labels", {}))
            errs = _assert_case(case, out)
        except Exception as exc:
            errs = [str(exc)]
            out = None
        results.append((cid, errs, out))
        if errs:
            failures += 1

    if args.pretty:
        for cid, errs, out in results:
            status = "PASS" if not errs else "FAIL"
            print(f"[{status}] {cid}")
            if errs:
                for e in errs:
                    print(f"  - {e}")
            if out is not None:
                print(f"  primary: {out.get('primary')}")
                print(f"  matched_rules: {', '.join(out.get('matched_rules', []))}")
                print(f"  stage_slots: {', '.join(_stage_slots(out))}")
    else:
        summary = {
            "total": len(results),
            "failures": failures,
            "results": [
                {
                    "id": cid,
                    "ok": not errs,
                    "errors": errs,
                    "primary": (out or {}).get("primary"),
                    "stage_slots": _stage_slots(out or {})
                }
                for cid, errs, out in results
            ]
        }
        print(json.dumps(summary, ensure_ascii=False))

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
