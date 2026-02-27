---
name: openclaw-status
description: "Query OpenClaw Gateway status — agents, nodes, channels, sessions, plugins"
user-invocable: true
---

# /openclaw-status — 查询 OpenClaw 状态

查询指定 Gateway 的全面状态并格式化输出。

## 参数

- **host** (可选): Gateway 机器地址。默认为本地。
  - 本地: 直接执行 CLI
  - 远程: 通过 SSH 执行

## 执行逻辑

### 1. 确定连接方式

```bash
# 如果指定了 host, 通过 SSH
if [ -n "$HOST" ]; then
  CMD="ssh $HOST"
else
  CMD=""
fi
```

### 2. 收集状态

```bash
# Gateway 健康
$CMD openclaw health

# 深度状态
$CMD openclaw status --deep --all

# Agent 列表
$CMD openclaw agents list --bindings

# Channel 状态
$CMD openclaw channels status --probe

# Plugin 状态
$CMD openclaw plugins list

# 配置摘要
$CMD jq '{
  agents: [.agents.list[] | {id, name, model, workspace}],
  gateway: {port: .gateway.port, bind: .gateway.bind},
  activeChannels: [.channels | to_entries[] | select(.value.accounts // .value.botToken // .value.token) | .key]
}' ~/.openclaw/openclaw.json

# Tailscale 节点 (如果可用)
$CMD tailscale status --json 2>/dev/null | jq '.Peer[] | {Name: .HostName, IP: .TailscaleIPs[0], Online: .Online, OS: .OS}' 2>/dev/null

# Session 统计
$CMD bash -c 'for agent in $(jq -r ".agents.list[].id" ~/.openclaw/openclaw.json); do
  sessions=$(ls ~/.openclaw/agents/$agent/sessions/*.jsonl 2>/dev/null | wc -l | tr -d " ")
  echo "$agent: $sessions active sessions"
done'
```

### 3. 输出统一视图

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊  OpenClaw Fleet Status
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🌐 Gateway
   Host:    mac-cn (100.64.0.1)
   Status:  ✅ healthy
   Port:    18789
   Uptime:  3d 12h

🤖 Agents (3)
   ┌─────────┬─────────┬──────────────────────────┬──────────┐
   │ ID      │ Model   │ Workspace                │ Sessions │
   ├─────────┼─────────┼──────────────────────────┼──────────┤
   │ master  │ opus    │ ~/.openclaw/workspace-m  │ 12       │
   │ worker1 │ sonnet  │ ~/.openclaw/workspace-w1 │ 8        │
   │ worker2 │ sonnet  │ ~/.openclaw/workspace-w2 │ 3        │
   └─────────┴─────────┴──────────────────────────┴──────────┘

📡 Channels (3/4 online)
   ✅ whatsapp   (default)
   ✅ telegram   (default, alerts)
   ✅ discord    (default)
   ❌ webchat    (not configured)

🔌 Plugins (2 loaded)
   ✅ voice-call  v1.2.0
   ✅ memory-core v2.0.0

🌍 Network Nodes
   ┌──────────┬─────────────┬────────┬─────────┐
   │ Name     │ IP          │ OS     │ Status  │
   ├──────────┼─────────────┼────────┼─────────┤
   │ mac-cn   │ 100.64.0.1  │ macOS  │ ✅ self │
   │ mac-sg   │ 100.64.0.2  │ macOS  │ ✅ online│
   │ laptop   │ 100.64.0.3  │ macOS  │ ✅ online│
   └──────────┴─────────────┴────────┴─────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 多 Gateway 查询

如果用户有多个 Gateway，依次查询：

```bash
# /openclaw-status --hosts mac-cn,mac-sg
for host in mac-cn mac-sg; do
  echo "=== $host ==="
  ssh $host "openclaw status --deep"
done
```
