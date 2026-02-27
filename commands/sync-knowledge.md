---
name: sync-knowledge
description: "Sync openclaw-dev knowledge base with upstream OpenClaw documentation changes"
user-invocable: true
---

# /sync-knowledge — 同步知识库

将 openclaw-dev 的知识库与上游 OpenClaw 文档同步更新。

## 前提

需要能访问上游 OpenClaw 仓库:
```bash
# 检查上游仓库
UPSTREAM="${OPENCLAW_REPO:-$HOME/openclaw}"
if [ ! -d "$UPSTREAM/docs" ]; then
  echo "ERROR: OpenClaw repo not found at $UPSTREAM"
  echo "Set OPENCLAW_REPO env var or clone: git clone https://github.com/openclaw/openclaw.git ~/openclaw"
  exit 1
fi
```

## 流程

### 1. 拉取上游最新

```bash
cd "$UPSTREAM" && git pull origin main
```

### 2. 比较变更

扫描上游自上次同步以来的文档变更:

```bash
# 找到上次同步时间 (用 knowledgebase SKILL.md 的 mtime)
LAST_SYNC=$(stat -f %m skills/openclaw-dev-knowledgebase/SKILL.md 2>/dev/null || stat -c %Y skills/openclaw-dev-knowledgebase/SKILL.md)

# 列出上游变更的文档
cd "$UPSTREAM"
git log --since="$(date -r $LAST_SYNC '+%Y-%m-%d')" --name-only --pretty=format: -- docs/ | sort -u | grep ".md$"
```

### 3. 对照 Reference 映射

| 上游文档路径 | 知识库 Reference |
|-------------|-----------------|
| `docs/concepts/*` | `references/core-concepts.md` |
| `docs/gateway/remote.md`, `docs/gateway/tailscale.md` | `references/multi-node-networking.md` |
| `docs/gateway/configuration*.md` | `references/core-concepts.md` |
| `docs/concepts/session*.md` | `references/sessions-memory-automation-security.md` |
| `docs/gateway/protocol.md` | `references/networking.md` |
| `docs/install/*` | `references/install-and-debug.md` |
| `docs/platforms/*` | `references/install-and-debug.md` |
| `docs/refactor/plugin-sdk.md` | `references/plugin-api.md` |
| `docs/concepts/multi-agent.md` | `references/agent-config.md` |

### 4. 生成差异报告

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📖 Knowledge Sync Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Upstream changes since last sync:
  docs/concepts/multi-agent.md    (modified)
  docs/gateway/configuration.md   (modified)
  docs/install/installer.md       (modified)

Affected references:
  references/agent-config.md      ← needs review
  references/core-concepts.md     ← needs review
  references/install-and-debug.md ← needs review

No changes needed:
  references/networking.md
  references/plugin-api.md
  (... 10 more)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 5. 逐个更新

For each affected reference:
1. Read the upstream doc changes
2. Check if the reference needs updating
3. Apply updates, keeping the reference format consistent
4. Verify accuracy

### 6. 验证

```bash
# Validate skill after updates
bash scripts/validate-skill.sh skills/openclaw-dev-knowledgebase/

# Check line count still under 500
wc -l skills/openclaw-dev-knowledgebase/SKILL.md
```
