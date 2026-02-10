---
name: list-skills
description: List all OpenClaw skills across all agent workspaces, managed skills, and bundled skills. Shows which agent each skill belongs to and its configuration.
---

# List OpenClaw Skills

Show a comprehensive view of all installed skills.

## Execution

Run this analysis:

```bash
echo "=== Agent Workspaces ==="
for agent in $(jq -r '.agents.list[].id' ~/.openclaw/openclaw.json); do
  ws=$(jq -r ".agents.list[] | select(.id==\"$agent\") | .workspace // empty" ~/.openclaw/openclaw.json)
  ws=$(eval echo "$ws")
  if [ -n "$ws" ] && [ -d "$ws/skills" ]; then
    echo ""
    echo "Agent: $agent (workspace: $ws)"
    for skill_dir in "$ws/skills"/*/; do
      if [ -f "$skill_dir/SKILL.md" ]; then
        name=$(head -10 "$skill_dir/SKILL.md" | grep "^name:" | sed 's/name: *//')
        desc=$(head -10 "$skill_dir/SKILL.md" | grep "^description:" | sed 's/description: *//' | cut -c1-80)
        meta=$(head -10 "$skill_dir/SKILL.md" | grep "^metadata:" | sed 's/metadata: *//')
        always=$(echo "$meta" | jq -r '.clawdbot.always // false' 2>/dev/null)
        echo "  - $name [always=$always] $desc"
      fi
    done
  fi
done

echo ""
echo "=== Managed Skills (~/.openclaw/skills/) ==="
if [ -d ~/.openclaw/skills ]; then
  for skill_dir in ~/.openclaw/skills/*/; do
    if [ -f "$skill_dir/SKILL.md" ]; then
      name=$(head -10 "$skill_dir/SKILL.md" | grep "^name:" | sed 's/name: *//')
      echo "  - $name"
    fi
  done
else
  echo "  (none)"
fi

echo ""
echo "=== Bundled Skills ==="
BUNDLED=$(dirname $(which openclaw-gateway 2>/dev/null || echo "/Users/$(whoami)/.bun/install/global/node_modules/openclaw/bin/openclaw-gateway"))/../skills
if [ -d "$BUNDLED" ]; then
  ls "$BUNDLED" | head -20
  TOTAL=$(ls "$BUNDLED" | wc -l | tr -d ' ')
  echo "  ($TOTAL total bundled skills)"
else
  echo "  (bundled path not found)"
fi
```

## Output Format

Present as a structured table:
```
OpenClaw Skills Overview

Agent Skills:
| Agent | Skill | Always | Description |
|-------|-------|--------|-------------|
| ...   | ...   | ...    | ...         |

Managed Skills (global):
| Skill | Description |
|-------|-------------|
| ...   | ...         |

Bundled: N skills (use `ls <path>` to see all)
```
