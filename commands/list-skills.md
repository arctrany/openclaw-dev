---
name: list-skills
description: List all OpenClaw skills across all agent workspaces, managed skills, and bundled skills. Shows which agent each skill belongs to and its configuration.
---

# List OpenClaw Skills

读取 `openclaw-skill-development` skill 的 `references/list-skills-runbook.md`，列出所有已安装的 skill。

## 快速参考

扫描 3 层:
1. Agent Workspace skills (`<workspace>/skills/`)
2. Managed skills (`~/.openclaw/skills/`)
3. Bundled skills (内置)

输出包含: Agent 名、Skill 名、always-on 状态、描述。

完整步骤见 `references/list-skills-runbook.md`。

## Fallback（reference 不可用时）

若无法加载 runbook，直接执行以下扫描：

```bash
# 1. 从 openclaw.json 获取 agent 列表和 workspace 路径
jq -r '.agents.list[] | "\(.id)\t\(.workspace)"' ~/.openclaw/openclaw.json

# 2. 扫描各 workspace 下的 skills/
for ws in $(jq -r '.agents.list[].workspace' ~/.openclaw/openclaw.json | sort -u); do
  ws_expanded=$(eval echo "$ws")
  echo "━━━ $ws_expanded/skills/ ━━━"
  ls "$ws_expanded/skills/" 2>/dev/null || echo "(empty or not found)"
done

# 3. 扫描 managed skills
echo "━━━ ~/.openclaw/skills/ ━━━"
ls ~/.openclaw/skills/ 2>/dev/null || echo "(empty or not found)"
```
