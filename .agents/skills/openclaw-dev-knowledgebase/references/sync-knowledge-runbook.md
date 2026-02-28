# 知识库同步 Runbook

将 openclaw-dev 的知识库与上游 OpenClaw 文档同步更新。

## 前提

```bash
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

```bash
LAST_SYNC=$(stat -f %m skills/openclaw-dev-knowledgebase/SKILL.md 2>/dev/null || stat -c %Y skills/openclaw-dev-knowledgebase/SKILL.md)

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

Affected references:
  references/agent-config.md      ← needs review
  references/core-concepts.md     ← needs review

No changes needed:
  references/networking.md
  (... N more)

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
bash scripts/validate-skill.sh skills/openclaw-dev-knowledgebase/
wc -l skills/openclaw-dev-knowledgebase/SKILL.md
```
