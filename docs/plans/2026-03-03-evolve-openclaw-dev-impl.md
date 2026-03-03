# openclaw-dev 自我进化系统 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 openclaw-dev 插件构建半自动自我进化能力，支持三条触发路径：GitHub Issues、agent session 日志（本地+SSH）、OpenClaw 版本更新。

**Architecture:** 两个命令分离职责——`/collect-signals` 负责从三条数据源采集原始信号，输出 `data/signals.json`；`/evolve-openclaw-dev` 负责读取信号、分析、生成优先级排序的改进报告。`collect-signals.py` 脚本实现 agent-aware 动态日志发现，不硬编码任何路径。

**Tech Stack:** bash, python3, gh CLI (GitHub Issues), ssh/scp (远程采集), jq

---

## Task 1: 更新 .gitignore 和初始化 data/ 目录

**Files:**
- Modify: `.gitignore`
- Create: `data/.gitkeep`

**Step 1: 添加 data/signals.json 到 .gitignore**

在 `.gitignore` 末尾追加：

```
# Evolution signals (contains user paths, not for repo)
data/signals.json
data/signals.*.json
```

**Step 2: 创建 data/ 目录占位文件**

```bash
mkdir -p data && touch data/.gitkeep
```

**Step 3: 验证**

```bash
echo '{"test": true}' > data/signals.json
git status  # data/signals.json 应显示为 ignored
rm data/signals.json
```

Expected: `data/signals.json` 不出现在 `git status` 输出中。

**Step 4: Commit**

```bash
git add .gitignore data/.gitkeep
git commit -m "chore: init data/ dir and gitignore signals.json"
```

---

## Task 2: 实现 `scripts/collect-signals.py`

**Files:**
- Create: `scripts/collect-signals.py`

核心脚本，三条采集路径：GitHub Issues、本地 agent 日志（动态发现）、SSH 远程节点。

**Step 1: 创建脚本骨架**

```python
#!/usr/bin/env python3
"""collect-signals.py — Collect evolution signals for openclaw-dev.

Usage:
  python3 scripts/collect-signals.py [--agent all|claude|codex|qwen|antigravity|iflow]
                                      [--host user@host] [--days 30] [--issues]
                                      [--output data/signals.json]
"""
import argparse, json, os, subprocess, sys, glob
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
    "/scaffold-agent", "/scaffold-plugin", "/sync-knowledge",
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
```

**Step 2: 实现 GitHub Issues 采集**

```python
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
```

**Step 3: 实现 agent 日志动态发现**

```python
def discover_log_files(agent_root: Path, days: int) -> list[Path]:
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


def analyze_log_files(log_files: list[Path]) -> dict:
    """Extract skill triggers, command uses, and errors from log files."""
    skill_signals = {s: {"triggered": 0, "errors": 0, "sessions": 0} for s in SKILL_NAMES}
    command_signals = {c: {"uses": 0} for c in COMMAND_NAMES}
    sessions_seen = set()

    for f in log_files:
        session_id = f.parent.name
        try:
            content = f.read_text(errors="ignore")
        except OSError:
            continue

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


def collect_local(agents: list[str], days: int) -> dict:
    """Collect from local agent log dirs."""
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
        result = analyze_log_files(log_files)
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
```

**Step 4: 实现 SSH 远程采集**

```python
def collect_remote(host: str, agents: list[str], days: int) -> dict:
    """Collect signals from a remote host via SSH."""
    # Upload and run this script remotely, capture JSON output
    script_path = Path(__file__).resolve()
    remote_tmp = "/tmp/collect-signals-remote.py"

    try:
        subprocess.run(["scp", "-q", str(script_path), f"{host}:{remote_tmp}"],
                       check=True, timeout=30)
        result = subprocess.run(
            ["ssh", host, f"python3 {remote_tmp} --agent {','.join(agents)} --days {days} --no-issues --output -"],
            capture_output=True, text=True, timeout=120
        )
        if result.returncode != 0:
            print(f"[warn] SSH {host} failed: {result.stderr.strip()}", file=sys.stderr)
            return {}
        return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, json.JSONDecodeError) as e:
        print(f"[warn] Remote collect from {host} failed: {e}", file=sys.stderr)
        return {}
```

**Step 5: 实现 OpenClaw 版本检测（第三触发源）**

```python
def collect_openclaw_version() -> dict:
    """Detect installed OpenClaw version and latest release."""
    local_version = None
    latest_version = None

    # Detect local version
    try:
        r = subprocess.run(["openclaw", "--version"], capture_output=True, text=True, timeout=10)
        if r.returncode == 0:
            local_version = r.stdout.strip().split()[-1]
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Fetch latest release from GitHub
    try:
        r = subprocess.run(
            ["gh", "release", "view", "--repo", "clawdbot/openclaw", "--json", "tagName"],
            capture_output=True, text=True, timeout=15
        )
        if r.returncode == 0:
            latest_version = json.loads(r.stdout).get("tagName", "").lstrip("v")
    except (FileNotFoundError, subprocess.TimeoutExpired, json.JSONDecodeError):
        pass

    return {
        "local_version": local_version,
        "latest_version": latest_version,
        "update_available": (
            local_version is not None and
            latest_version is not None and
            local_version != latest_version
        )
    }
```

**Step 6: 实现 main() 和 JSON 输出**

```python
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
    parser.add_argument("--output", default="data/signals.json")
    args = parser.parse_args()

    agents = list(AGENT_ROOTS.keys()) if args.agent == "all" else args.agent.split(",")

    print(f"[collect-signals] agents={agents} days={args.days} hosts={args.host}")

    signals = collect_local(agents, args.days)
    signals.setdefault("sources", [])

    for host in args.host:
        remote = collect_remote(host, agents, args.days)
        signals = merge_signals(signals, remote)
        if remote:
            signals["sources"].append(f"ssh:{host}")

    signals["issues"] = collect_issues() if args.issues else []
    signals["openclaw_version"] = collect_openclaw_version()
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
```

**Step 7: 设为可执行并验证语法**

```bash
chmod +x scripts/collect-signals.py
python3 -m py_compile scripts/collect-signals.py && echo "OK: syntax valid"
```

Expected: `OK: syntax valid`

**Step 8: 冒烟测试（不需要 gh CLI）**

```bash
python3 scripts/collect-signals.py --agent claude --no-issues --output /tmp/test-signals.json
cat /tmp/test-signals.json | python3 -c "import sys,json; d=json.load(sys.stdin); print('skills:', list(d['skill_signals'].keys()))"
```

Expected: 打印 4 个 skill 名称。

**Step 9: Commit**

```bash
git add scripts/collect-signals.py
git commit -m "feat: add collect-signals.py — agent-aware log collection + SSH + issues"
```

---

## Task 3: 实现 `/collect-signals` 命令

**Files:**
- Create: `commands/collect-signals.md`

**Step 1: 创建命令文件**

```markdown
---
name: collect-signals
description: "Collect evolution signals for openclaw-dev from GitHub Issues, local agent logs (Claude Code, Codex, Qwen, Antigravity, iFlow), and optional SSH remote nodes. Run before /evolve-openclaw-dev. Triggers: 'collect signals', 'gather data', 'update signals', 'prepare evolution data'."
argument-hint: "[--agent all|claude|codex|qwen|antigravity|iflow] [--host user@remote] [--days 30] [--no-issues]"
user-invocable: true
---

# /collect-signals — 采集进化信号

从 GitHub Issues、本地 agent 日志、SSH 远程节点收集信号，输出 `data/signals.json`。

## 运行

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/collect-signals.py \
  --agent all \
  --days 30 \
  [--host user@remote] \
  [--no-issues]
```

Fallback（workspace 运行时）:

```bash
python3 scripts/collect-signals.py --agent all --days 30
```

## 参数说明

| 参数 | 默认 | 说明 |
|------|------|------|
| `--agent` | `all` | agent 范围：all / claude / codex / qwen / antigravity / iflow |
| `--host` | 无 | SSH 远程节点，可多次指定 |
| `--days` | 30 | 分析时间窗口（天） |
| `--no-issues` | — | 跳过 GitHub Issues 采集（无 gh CLI 时使用） |

## 采集完成后

运行 `/evolve-openclaw-dev` 读取 `data/signals.json` 进行分析。
```

**Step 2: 验证 frontmatter**

```bash
head -10 commands/collect-signals.md | grep -E "^name:|^user-invocable:" | wc -l
```

Expected: `2`

**Step 3: Commit**

```bash
git add commands/collect-signals.md
git commit -m "feat: add /collect-signals command"
```

---

## Task 4: 实现 `/evolve-openclaw-dev` 命令

**Files:**
- Create: `commands/evolve-openclaw-dev.md`

**Step 1: 创建命令文件**

```markdown
---
name: evolve-openclaw-dev
description: "Analyze collected signals (from /collect-signals) and generate a prioritized Evolution Report for openclaw-dev skills and commands. Triggers: 'evolve openclaw-dev', 'analyze signals', 'skill improvement report', 'what needs fixing', 'generate evolution report'."
user-invocable: true
---

# /evolve-openclaw-dev — 分析 + 生成进化报告

读取 `data/signals.json`，输出优先级排序的改进建议。

**前置条件**: 先运行 `/collect-signals`。

## 分析流程

### 1. 检查信号文件

```bash
[ -f data/signals.json ] || { echo "请先运行 /collect-signals"; exit 1; }
python3 -c "import json; d=json.load(open('data/signals.json')); print(f'采集时间: {d[\"collected_at\"]}  窗口: {d[\"window_days\"]}天  节点: {len(d[\"sources\"])}')"
```

### 2. OpenClaw 版本检查

读取 `signals["openclaw_version"]`：
- `update_available: true` → 说明 openclaw-dev 的 knowledgebase / node-operations skill 可能有过时内容
- 将此列为 P0 issue：**需要同步新版本 API/命令变更**

### 3. Issue 聚类分析

按 `label_names` 分组，计算各 skill/command 被提及次数：
- bug + age_days > 7 → P0
- bug + age_days ≤ 7 → P1
- enhancement → P2

### 4. Skill 触发质量

```python
import json
d = json.load(open("data/signals.json"))
for skill, sig in d["skill_signals"].items():
    sessions = max(sig["sessions"], 1)
    rate = sig["triggered"] / sessions * 100
    err_rate = sig["errors"] / max(sig["triggered"], 1) * 100
    flag = ""
    if rate < 20: flag += " ⚠️ 低触发"
    if err_rate > 15: flag += " ⚠️ 高错误"
    if sig["triggered"] == 0: flag += " ❌ 从未触发"
    print(f"{skill}: 触发率{rate:.0f}% 错误率{err_rate:.0f}%{flag}")
```

阈值：
- 触发率 < 20% → description 缺关键词
- 错误率 > 15% → 指令不清晰
- 从未触发 → 功能重叠 or 废弃候选

### 5. Command 使用率

```python
for cmd, sig in d["command_signals"].items():
    if sig["uses"] == 0:
        print(f"{cmd}: 0次 → 考虑删除或重命名")
```

### 6. 生成报告

按以下格式输出 Evolution Report，然后逐条询问开发者是否应用：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧬 openclaw-dev Evolution Report
   采集时间: <collected_at> | 节点数: <n> | Sessions: <total>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔄 OpenClaw 版本
   本地: <local> | 最新: <latest>
   [如有更新] ⚠️ 需要同步新版本变更到 knowledgebase / node-operations

📋 GitHub Issues (<n> open)
   P0: #xx "..." [bug, <n>天]
   P1: #xx "..." [bug]
   P2: #xx "..." [enhancement]

📊 Skill 触发质量
   <skill>: 触发率 x%, 错误率 y%  [状态]

📉 Command 使用率 (零使用)
   /xxx: 0次 → 评估是否保留

💡 改进建议 (优先级排序)
   1. [P0] ...
   2. [P1] ...

⚡ 下一步
   应用建议 → 逐条确认后编辑 SKILL.md / commands/
   验证     → bash scripts/skill-lint.sh skills/<name>
   发版     → git tag v2.x.x && git push && bash install.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
```

**Step 2: Commit**

```bash
git add commands/evolve-openclaw-dev.md
git commit -m "feat: add /evolve-openclaw-dev command"
```

---

## Task 5: 更新设计文档（补充 OpenClaw 版本触发源）

**Files:**
- Modify: `docs/plans/2026-03-03-evolve-openclaw-dev-design.md`

**Step 1: 补充第三触发源到设计文档**

在数据源表格中新增一行：

```markdown
| OpenClaw 版本更新 | `openclaw --version` + `gh release view` | 本地版本 vs 最新版，检测是否有 API 变更需同步 |
```

在总体架构图中更新：

```
数据源
────────────────────
GitHub Issues  ─────┐
本地 agent 日志 ────┼──→  /collect-signals  ──→  signals.json  ──→  /evolve-openclaw-dev
远程 SSH 节点  ─────┤
OpenClaw 版本  ─────┘
```

**Step 2: Commit**

```bash
git add docs/plans/2026-03-03-evolve-openclaw-dev-design.md
git commit -m "docs: add OpenClaw version update as third evolution trigger"
```

---

## Task 6: 端到端验证 + 最终 push

**Step 1: 运行安全扫描**

```bash
bash scripts/security-scan.sh
```

Expected: 无 FAIL 输出。

**Step 2: Skill lint**

```bash
bash scripts/skill-lint.sh skills/openclaw-dev-knowledgebase
bash scripts/skill-lint.sh skills/openclaw-node-operations
```

Expected: 全部 OK。

**Step 3: 验证命令文件**

```bash
for f in commands/collect-signals.md commands/evolve-openclaw-dev.md; do
  head -8 "$f" | grep "^name:" && echo "OK: $f"
done
```

Expected: 两个文件各打印 `name:` 行。

**Step 4: 端到端冒烟**

```bash
python3 scripts/collect-signals.py --agent claude --no-issues --output /tmp/smoke-signals.json
python3 -c "
import json; d=json.load(open('/tmp/smoke-signals.json'))
assert 'skill_signals' in d
assert 'command_signals' in d
assert 'openclaw_version' in d
assert set(d['skill_signals'].keys()) == {
  'openclaw-dev-knowledgebase','openclaw-node-operations',
  'openclaw-skill-development','model-routing-governor'
}
print('OK: signals structure valid')
"
```

Expected: `OK: signals structure valid`

**Step 5: Push**

```bash
git log --oneline -6  # 确认所有 commit 就位
git push
```

---

## 进化闭环使用方式（完成后）

```bash
# 定期运行（或 OpenClaw 有新版本时）
openclaw-dev   # 启动插件 session

/collect-signals --agent all --days 30
# 可选远程节点:
/collect-signals --agent all --host user@my-server --days 30

/evolve-openclaw-dev
# → 查看报告，逐条确认改进建议
# → 手动编辑 SKILL.md / commands/
# → bash scripts/skill-lint.sh 验证
# → git tag v2.x.x && git push && bash install.sh
```
