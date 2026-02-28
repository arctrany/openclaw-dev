# Skill 分析脚本文档

## skill-usage-report.py

分析所有 agent session 日志，输出 skill 使用统计。

### 用法

```bash
python3 scripts/skill-usage-report.py --days 30
python3 scripts/skill-usage-report.py --agent momiji --days 7
```

### 输出示例

```
Skill Usage Report (last 30 days)
─────────────────────────────────
Agent: momiji (42 sessions)

| Skill               | Triggered | Errors | Avg Duration | Tokens |
|---------------------|-----------|--------|--------------|--------|
| coding-agent        | 28        | 2      | 45s          | 12.3k  |
| web-search          | 15        | 0      | 12s          | 3.1k   |
| email-compose       | 8         | 1      | 22s          | 5.2k   |
| unused-skill        | 0         | 0      | -            | -      |

Recommendations:
- 🔴 unused-skill: 0 triggers in 30 days — consider removing
- ⚠️ coding-agent: 7% error rate — analyze errors
- ✅ web-search: 0% error rate, efficient token usage
```

### 实现要点

```python
import json, glob, os
from datetime import datetime, timedelta

def load_sessions(agent_id, days=30):
    """加载指定 agent 的 session 日志"""
    session_dir = os.path.expanduser(
        f"~/.openclaw/agents/{agent_id}/sessions"
    )
    cutoff = datetime.now() - timedelta(days=days)
    sessions = []
    for f in glob.glob(f"{session_dir}/*.jsonl"):
        mtime = datetime.fromtimestamp(os.path.getmtime(f))
        if mtime >= cutoff:
            events = []
            with open(f) as fh:
                for line in fh:
                    try:
                        events.append(json.loads(line.strip()))
                    except json.JSONDecodeError:
                        continue
            sessions.append(events)
    return sessions

def analyze_skill_usage(sessions):
    """统计 skill 触发、错误、token 使用"""
    stats = {}
    for session in sessions:
        for event in session:
            meta = event.get("metadata", {})
            skill = meta.get("skill_triggered")
            if skill:
                if skill not in stats:
                    stats[skill] = {"triggered": 0, "errors": 0, "tokens": 0}
                stats[skill]["triggered"] += 1
                if event.get("type") == "error":
                    stats[skill]["errors"] += 1
                tokens = meta.get("tokens", {})
                stats[skill]["tokens"] += tokens.get("input", 0) + tokens.get("output", 0)
    return stats
```

---

## analyze-triggers.py

分析 skill 触发模式——哪些用户查询触发了 skill，哪些应该触发但没有。

```bash
python3 scripts/analyze-triggers.py --skill coding-agent --days 14
```

## analyze-errors.py

分析 skill 活跃时的错误模式——重复错误、缺失信息、工具失败。

```bash
python3 scripts/analyze-errors.py --skill coding-agent --days 14
```

## analyze-performance.py

分析性能指标——耗时、token 效率、工具调用次数、重试。

```bash
python3 scripts/analyze-performance.py --skill coding-agent --days 14
```

> **注意**: 这些脚本需要实际 session 日志数据。首次运行前确保目标 agent 有足够的 session 历史。
