#!/usr/bin/env python3
"""collect-signals.py — Collect evolution signals for openclaw-dev.

Usage:
  python3 scripts/collect-signals.py [--agent all|claude|codex|qwen|antigravity|iflow]
                                      [--host user@host] [--days 30] [--issues]
                                      [--project-root /path/to/openclaw-dev]
                                      [--output data/signals.json]
"""
import argparse, json, os, re, subprocess, sys
from datetime import datetime, timedelta
from pathlib import Path

SKILL_NAMES = [
    "openclaw-dev-knowledgebase",
    "openclaw-node-operations",
    "openclaw-skill-development",
    "model-routing-governor",
]

COMMAND_NAMES = [
    "/diagnose", "/diagnose-openclaw", "/setup-node", "/lint-config",
    "/openclaw-status", "/evolve-skill", "/evolve-openclaw-capability",
    "/create-skill", "/deploy-skill", "/validate-skill", "/list-skills",
    "/scaffold-agent", "/plugin", "/sync-knowledge",
    "/collect-signals", "/evolve-openclaw-dev",
]

# Known agent root dirs for dynamic discovery (not hardcoded log paths)
AGENT_ROOTS = {
    "claude":      "~/.claude",
    "codex":       "~/.codex",
    "qwen":        "~/.qwen",
    "antigravity": "~/.antigravity",
    "iflow":       "~/.iflow",
}


def collect_issues(repo="arctrany/openclaw-dev"):
    """Fetch open issues via gh CLI."""
    try:
        result = subprocess.run(
            ["gh", "issue", "list", "--repo", repo, "--state", "open",
             "--json", "number,title,labels,createdAt,comments", "--limit", "100"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode != 0:
            print(f"[warn] gh issue list failed: {result.stderr.strip()}", file=sys.stderr)
            return []
        issues = json.loads(result.stdout)
        now = datetime.now()
        for issue in issues:
            created = datetime.fromisoformat(issue["createdAt"].replace("Z", "+00:00")).replace(tzinfo=None)
            issue["age_days"] = (now - created).days
            issue["label_names"] = [l["name"] for l in issue.get("labels", [])]
        return issues
    except (FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"[warn] Issues skipped: {e}", file=sys.stderr)
        return []


def discover_log_files(agent_root: Path, days: int) -> list:
    """Dynamically find log files under agent_root by extension and recency."""
    cutoff = datetime.now() - timedelta(days=days)
    log_files = []
    for ext in ("*.jsonl", "*.log", "*.json"):
        for f in agent_root.rglob(ext):
            try:
                if datetime.fromtimestamp(f.stat().st_mtime) >= cutoff:
                    log_files.append(f)
            except OSError:
                continue
    return log_files


def normalize_project_aliases(project_root: str | None) -> list[str]:
    """Build a small alias set so moved mounts/symlinks still match logs."""
    if not project_root:
        return []

    path = Path(project_root).expanduser()
    candidates = []

    for candidate in (path, path.resolve()):
        text = str(candidate)
        if text not in candidates:
            candidates.append(text)

    name = path.name
    if name and name not in candidates:
        candidates.append(name)

    return candidates


def content_matches_project(content: str, project_aliases: list[str]) -> bool:
    """Return True when log content appears to belong to the target project."""
    if not project_aliases:
        return True

    lowered = content.lower()
    for alias in project_aliases:
        if alias.lower() in lowered:
            return True

    return False


def analyze_log_files(log_files: list, project_aliases: list[str] | None = None) -> dict:
    """Extract skill triggers, command uses, and errors from log files."""
    project_aliases = project_aliases or []
    skill_signals = {s: {"triggered": 0, "errors": 0, "sessions": 0} for s in SKILL_NAMES}
    command_signals = {c: {"uses": 0} for c in COMMAND_NAMES}
    sessions_seen = set()

    for f in log_files:
        try:
            content = f.read_text(errors="ignore")
        except OSError:
            continue

        if not content_matches_project(content, project_aliases):
            continue

        session_id = f.parent.name

        sessions_seen.add(session_id)
        for skill in SKILL_NAMES:
            if skill in content:
                skill_signals[skill]["triggered"] += 1
            if '"type":"error"' in content or '"type": "error"' in content:
                skill_signals[skill]["errors"] += 1
        for cmd in COMMAND_NAMES:
            command_signals[cmd]["uses"] += content.count(cmd)

    total_sessions = len(sessions_seen)
    for skill in skill_signals:
        skill_signals[skill]["sessions"] = total_sessions

    return {"skill_signals": skill_signals, "command_signals": command_signals,
            "sessions_total": total_sessions}


def collect_local(agents: list, days: int, project_root: str | None = None) -> dict:
    """Collect from local agent log dirs."""
    project_aliases = normalize_project_aliases(project_root)
    all_skill = {s: {"triggered": 0, "errors": 0, "sessions": 0} for s in SKILL_NAMES}
    all_cmd = {c: {"uses": 0} for c in COMMAND_NAMES}
    sources = []
    total_sessions = 0

    for agent in agents:
        root = Path(AGENT_ROOTS.get(agent, f"~/.{agent}")).expanduser()
        if not root.exists():
            continue
        log_files = discover_log_files(root, days)
        if not log_files:
            continue
        result = analyze_log_files(log_files, project_aliases)
        if result["sessions_total"] == 0:
            continue
        sources.append(f"{agent}-local")
        total_sessions += result["sessions_total"]
        for s in SKILL_NAMES:
            for k in ("triggered", "errors"):
                all_skill[s][k] += result["skill_signals"][s][k]
        for c in COMMAND_NAMES:
            all_cmd[c]["uses"] += result["command_signals"][c]["uses"]

    for s in SKILL_NAMES:
        all_skill[s]["sessions"] = total_sessions

    return {"skill_signals": all_skill, "command_signals": all_cmd,
            "sessions_total": total_sessions, "sources": sources}


def collect_remote(host: str, agents: list, days: int, project_root: str | None = None) -> dict:
    """Collect signals from a remote host via SSH."""
    script_path = Path(__file__).resolve()
    remote_tmp = "/tmp/collect-signals-remote.py"

    try:
        subprocess.run(["scp", "-q", str(script_path), f"{host}:{remote_tmp}"],
                       check=True, timeout=30)
        remote_cmd = [
            "python3", remote_tmp,
            "--agent", ",".join(agents),
            "--days", str(days),
            "--no-issues",
            "--output", "-",
        ]
        if project_root:
            remote_cmd += ["--project-root", project_root]
        result = subprocess.run(
            ["ssh", host, *remote_cmd],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode != 0:
            print(f"[warn] SSH {host} failed: {result.stderr.strip()}", file=sys.stderr)
            return {}
        return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"[warn] Remote collect from {host} failed: {e}", file=sys.stderr)
        return {}


def collect_openclaw_version() -> dict:
    """Detect installed OpenClaw version and latest release."""
    local_version = None
    latest_version = None
    release_notes = None

    try:
        r = subprocess.run(["openclaw", "--version"], capture_output=True, text=True, timeout=10)
        if r.returncode == 0:
            match = re.search(r"OpenClaw\s+([0-9][0-9A-Za-z.\-]+)", r.stdout)
            if match:
                local_version = match.group(1)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    try:
        r = subprocess.run(
            ["openclaw", "update", "status", "--json"],
            capture_output=True, text=True, timeout=15
        )
        if r.returncode == 0:
            data = json.loads(r.stdout)
            latest_version = (
                data.get("update", {})
                .get("registry", {})
                .get("latestVersion")
            ) or data.get("availability", {}).get("latestVersion")
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
        pass

    if latest_version is None:
        try:
            r = subprocess.run(
                ["npm", "view", "openclaw", "version", "--json"],
                capture_output=True, text=True, timeout=15
            )
            if r.returncode == 0:
                latest_version = json.loads(r.stdout)
        except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
            pass

    return {
        "local_version": local_version,
        "latest_version": latest_version,
        "update_available": (
            local_version is not None and
            latest_version is not None and
            local_version != latest_version
        ),
        "release_notes": release_notes,
    }


def merge_signals(base: dict, remote: dict) -> dict:
    """Merge remote signals into base."""
    if not remote:
        return base
    for s in SKILL_NAMES:
        for k in ("triggered", "errors", "sessions"):
            base["skill_signals"][s][k] += remote.get("skill_signals", {}).get(s, {}).get(k, 0)
    for c in COMMAND_NAMES:
        base["command_signals"][c]["uses"] += remote.get("command_signals", {}).get(c, {}).get("uses", 0)
    base["sources"] += remote.get("sources", [])
    return base


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--agent", default="all")
    parser.add_argument("--host", action="append", default=[])
    parser.add_argument("--days", type=int, default=30)
    parser.add_argument("--issues", action="store_true", default=True)
    parser.add_argument("--no-issues", dest="issues", action="store_false")
    parser.add_argument("--project-root", default=None)
    parser.add_argument("--output", default="data/signals.json")
    args = parser.parse_args()

    agents = list(AGENT_ROOTS.keys()) if args.agent == "all" else args.agent.split(",")

    print(
        f"[collect-signals] agents={agents} days={args.days} "
        f"hosts={args.host} project_root={args.project_root}"
    )

    signals = collect_local(agents, args.days, project_root=args.project_root)
    signals.setdefault("sources", [])

    for host in args.host:
        remote = collect_remote(host, agents, args.days, project_root=args.project_root)
        signals = merge_signals(signals, remote)
        if remote:
            signals["sources"].append(f"ssh:{host}")

    signals["issues"] = collect_issues() if args.issues else []
    signals["openclaw_version"] = collect_openclaw_version()
    signals["project_root"] = args.project_root
    signals["collected_at"] = datetime.now().isoformat()
    signals["window_days"] = args.days

    if args.output == "-":
        print(json.dumps(signals))
    else:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(signals, indent=2, ensure_ascii=False))
        print(f"[collect-signals] Written → {out}")


if __name__ == "__main__":
    main()
