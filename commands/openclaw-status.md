---
name: openclaw-status
description: "Query OpenClaw Gateway status — agents, channels, sessions, plugins. Supports remote Gateways with adaptive display."
argument-hint: "[gateway-name|ALL]"
user-invocable: true
---

# /openclaw-status — 查询 OpenClaw 状态

## Gateway 选择

读取 `.claude/openclaw-dev.local.md` 中的 `gateways:` 配置。

1. **有参数** (`/openclaw-status home-mac`) → 直接指定目标 gateway
2. **参数为 ALL** (`/openclaw-status ALL`) → 并行查询所有可达 gateway
3. **无 gateways 配置或只有 1 个** → 直接查询本地（现有行为）
4. **多个 gateway，无参数** → Preflight 探测可达性，展示选择菜单

### Preflight 探测

对每个非本地 gateway 并行执行:
```bash
ssh -o ConnectTimeout=5 -o BatchMode=yes \
    ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22} \
    ${ssh_user}@${host} "echo ok" 2>/dev/null
```

### 选择菜单

使用 AskUserQuestion:
```
1. local       127.0.0.1:18789        ● 可达
2. home-mac    192.168.1.100:18789    ● 可达
3. cloud-hk    10.0.0.5:18789         ○ 不可达
4. ALL（并行查询所有可达 gateway，汇总表格）
```

## 单 Gateway 查询（展开视图）

读取 `openclaw-node-operations` skill 的 `references/status-runbook.md`，收集并格式化输出全组件状态。

对远程 gateway，使用 SSH 连接:
```bash
SSH_OPTS="-o IdentitiesOnly=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=2"
SSH_OPTS="$SSH_OPTS -o ControlMaster=auto -o ControlPath=/tmp/openclaw-ssh-%r@%h:%p -o ControlPersist=300"
SSH_OPTS="$SSH_OPTS ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22}"
HOST="${ssh_user}@${host}"
CMD="ssh $SSH_OPTS $HOST"
```

展开视图格式:
```
● home-mac (192.168.1.100:18789)  UP 3d
  Agents:   developer (active)
  Channels:
    ├─ webchat    ✓ connected   http://...:18789/
    └─ telegram   ✗ error       Token expired
  Plugins:  3 loaded, 0 errors
  Model:    anthropic/claude-sonnet-4-5
```

完整步骤和输出模板见 `references/status-runbook.md`。

## ALL 模式（折叠汇总）

并行查询所有可达 gateway，输出折叠表格:

```bash
for gw_name in "${GATEWAYS[@]}"; do
  (
    ssh $SSH_OPTS ${ssh_user}@${host} \
      "openclaw health 2>&1; openclaw status --deep --all 2>&1; openclaw channels status --probe 2>&1"
  ) > "/tmp/openclaw-status-$gw_name" 2>&1 &
done
wait
```

折叠视图格式（多 channel 用缩写 + ✓/✗）:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fleet Status  <日期时间>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Gateway      Status  Agents  Channels               Uptime
───────────  ──────  ──────  ─────────────────────  ──────
local        ● UP    3       web✓ tg✓ wa✓           12h
home-mac     ● UP    1       web✓ tg✗              3d
cloud-hk     ○ DOWN  -       -                      -
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总计: 2/3 在线
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
