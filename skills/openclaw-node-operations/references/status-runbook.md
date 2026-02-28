# 状态查询 Runbook

查询指定 Gateway 的全面状态并格式化输出。

## 参数

- **host** (可选): Gateway 机器地址。默认为本地。

## 执行逻辑

### 0. 确认执行环境

```bash
echo "🖥️ 当前: $(hostname) | $(whoami) | $(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')"
```

### 1. 确定连接方式

```bash
if [ -n "$HOST" ]; then
  CMD="ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 $HOST"
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
   Host:    <hostname> (<ip>)
   Status:  ✅ healthy
   Port:    18789
   Uptime:  <uptime>

🤖 Agents (<N>)
   ┌─────────┬─────────┬──────────────────────────┬──────────┐
   │ ID      │ Model   │ Workspace                │ Sessions │
   ├─────────┼─────────┼──────────────────────────┼──────────┤
   │ ...     │ ...     │ ...                      │ ...      │
   └─────────┴─────────┴──────────────────────────┴──────────┘

📡 Channels (<online>/<total> online)
   ✅ whatsapp   (default)
   ✅ telegram   (default, alerts)
   ❌ webchat    (not configured)

🔌 Plugins (<N> loaded)
   ✅ voice-call  v1.2.0
   ✅ memory-core v2.0.0

🌍 Network Nodes
   ┌──────────┬─────────────┬────────┬─────────┐
   │ Name     │ IP          │ OS     │ Status  │
   ├──────────┼─────────────┼────────┼─────────┤
   │ ...      │ ...         │ ...    │ ...     │
   └──────────┴─────────────┴────────┴─────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 多 Gateway 查询

如果用户有多个 Gateway，依次查询：

```bash
for host in mac-cn mac-sg; do
  echo "=== $host ==="
  ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 $host "openclaw status --deep"
done
```
