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
