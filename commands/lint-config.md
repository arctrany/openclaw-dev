---
name: lint-config
description: "Validate openclaw.json syntax and semantics before applying — prevent configuration corruption"
user-invocable: true
---

# /lint-config — 配置验证

在修改 openclaw.json 前后验证配置正确性，防止配置损坏导致 Agent 全部终止。

## 用法

```
/lint-config                    # 验证当前配置
/lint-config --fix              # 验证 + 尝试自动修复
/lint-config <path>             # 验证指定文件
```

## 检查项

### 1. JSON 语法

```bash
CONFIG="${1:-$HOME/.openclaw/openclaw.json}"
if ! jq . "$CONFIG" > /dev/null 2>&1; then
  # 获取具体错误位置
  jq . "$CONFIG" 2>&1
  echo ""
  echo "💡 尝试: 检查上述行号附近的逗号、引号、括号"

  # 有 .bak 可恢复?
  LATEST_BAK=$(ls -t "$CONFIG".bak* 2>/dev/null | head -1)
  [ -n "$LATEST_BAK" ] && echo "💡 最近备份: $LATEST_BAK ($(stat -f '%Sm' "$LATEST_BAK" 2>/dev/null || stat -c '%y' "$LATEST_BAK" 2>/dev/null))"
  exit 1
fi
echo "✅ JSON 语法正确"
```

### 2. 必要字段

```bash
# agents.list 非空
AGENT_COUNT=$(jq '.agents.list | length' "$CONFIG")
[ "$AGENT_COUNT" -eq 0 ] && echo "❌ agents.list 为空" || echo "✅ agents.list: $AGENT_COUNT 个 agent"

# 每个 agent 有 id
jq -r '.agents.list[] | select(.id == null or .id == "") | "❌ Agent 缺少 id: " + (.name // "unknown")' "$CONFIG"

# model 配置
jq -r '.agents.list[] | select(.model == null) | "⚠️  Agent \(.id) 无 model (使用默认)"' "$CONFIG"
```

### 3. 安全审计

```bash
# Gateway 绑定检查
BIND=$(jq -r '.gateway.bind // "loopback"' "$CONFIG")
[ "$BIND" = "0.0.0.0" ] && echo "⚠️  Gateway 绑定 0.0.0.0 (LAN 暴露!) — 建议改为 loopback"

# 端口间距 (多 profile)
PORT=$(jq -r '.gateway.port // 18789' "$CONFIG")
echo "ℹ️  Gateway 端口: $PORT"
```

### 4. 路径可达性

```bash
# Workspace 路径
jq -r '.agents.list[] | "\(.id)|\(.workspace // "")"' "$CONFIG" | while IFS='|' read id ws; do
  [ -z "$ws" ] && continue
  ws=$(eval echo "$ws")
  [ -d "$ws" ] && echo "✅ $id workspace: $ws" || echo "❌ $id workspace 不存在: $ws"
done

# Node 二进制路径 (不应在外接硬盘)
NODE_PATH=$(which node 2>/dev/null)
echo "$NODE_PATH" | grep -q "/Volumes/" && echo "⚠️  node 在外接硬盘: $NODE_PATH — 断开会导致 crash loop!"
```

### 5. Auth Profile

```bash
jq -r '.agents.list[].id' "$CONFIG" | while read id; do
  AUTH="$HOME/.openclaw/agents/$id/agent/auth-profiles.json"
  if [ -f "$AUTH" ]; then
    jq . "$AUTH" > /dev/null 2>&1 && echo "✅ $id auth-profile 有效" || echo "❌ $id auth-profile JSON 损坏"
  else
    echo "⚠️  $id 无 auth-profile (会继承默认)"
  fi
done
```

## 输出

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔍 Config Lint: openclaw.json
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ JSON 语法正确
✅ agents.list: 3 个 agent
✅ master workspace: ~/.openclaw/workspace-master
✅ worker-cn workspace: ~/.openclaw/workspace-worker-cn
❌ worker-sg workspace 不存在: ~/.openclaw/workspace-worker-sg
⚠️  node 在外接硬盘: /Volumes/EXT/envs/homebrew/.../node
✅ Lint 完成: 4 pass, 1 fail, 1 warn
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 建议使用场景

- 每次手动编辑 `openclaw.json` 后立即运行
- 在 `/diagnose` 流程中自动调用
- CI/自动化场景中作为 pre-deploy 检查
