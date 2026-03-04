---
name: status
description: "Query OpenClaw Gateway status — agents, channels, sessions, plugins. Supports remote Gateways with adaptive display."
argument-hint: "[gateway-name|ALL]"
user-invocable: true
---

# /status — 查询 OpenClaw 状态

## Gateway 选择

读取 `.claude/openclaw-dev.local.md` 中的 `gateways:` 配置。

1. **有参数** (`/status home-mac`) → 直接指定目标 gateway
2. **参数为 ALL** (`/status ALL`) → 并行查询所有可达 gateway
3. **无 gateways 配置或只有 1 个** → 直接查询本地
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

## 单 Gateway 查询 — 分层执行

> **FSFR**: 按层递进，每层独立产出可用结果。弱模型只需 Step 1 + Step 2 即可完成。

### Step 1: 环境探测（必执行，1 个命令）

```bash
echo "===ENV===" && hostname && whoami && \
(command -v openclaw && openclaw --version 2>/dev/null || echo "NO_OPENCLAW") && \
(test -f ~/.openclaw/openclaw.json && echo "HAS_CONFIG" || echo "NO_CONFIG") && \
echo "===END==="
```

根据输出**查表选择路径**:

| openclaw 可用 | config 存在 | 下一步 |
|:---:|:---:|---|
| 是 | 是 | → Step 2A（正常模式） |
| 是 | 否 | 告知用户: "openclaw 已安装但未初始化，运行 `openclaw onboard`"，**结束** |
| 否 | 是 | → Step 2B（降级模式） |
| 否 | 否 | 告知用户: "OpenClaw 未安装，使用 `/setup-node` 安装"，**结束** |

### Step 2A: 正常状态查询（1 个命令）

```bash
openclaw health 2>&1; echo "===SEP==="; openclaw status --deep --all 2>&1
```

`openclaw status --deep --all` 已包含 agents、channels、plugins 的完整信息（Native first 原则）。

### Step 2B: 降级模式（1 个命令）

```bash
jq '{
  gateway: {port: .gateway.port, bind: .gateway.bind},
  agents: [.agents.list[] | {id, name, model}],
  channels: [.channels | to_entries[] | select(.value.accounts // .value.botToken // .value.token) | .key]
}' ~/.openclaw/openclaw.json
```

标注: "[降级模式] Gateway 进程状态未知，以下为配置文件静态信息"

### Step 3: 格式化输出

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OpenClaw Status  <hostname>  <日期时间>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Gateway    ● healthy   port:<port>   uptime:<uptime>

Agents (<N>)
  <id>        <model>            <workspace 短路径>

Channels (<online>/<total>)
  ✅ webchat    connected
  ✅ telegram   connected
  ❌ whatsapp   not configured

Plugins (<N> loaded, <M> errors)
  ✅ voice-call  v1.2.0
  ✅ memory-core v2.0.0

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 4: 深度补充（可选，仅在用户明确要求时执行）

```bash
# Channel 实际连通性探测
openclaw channels status --probe

# Session 活跃度统计
for agent in $(jq -r '.agents.list[].id' ~/.openclaw/openclaw.json); do
  echo "$agent: $(ls ~/.openclaw/agents/$agent/sessions/*.jsonl 2>/dev/null | wc -l | tr -d ' ') sessions"
done
```

## 远程 Gateway 查询

对远程 gateway，所有 Step 的命令通过 SSH 执行:
```bash
SSH_OPTS="-o IdentitiesOnly=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=2"
SSH_OPTS="$SSH_OPTS -o ControlMaster=auto -o ControlPath=/tmp/openclaw-ssh-%r@%h:%p -o ControlPersist=300"
SSH_OPTS="$SSH_OPTS ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22}"
HOST="${ssh_user}@${host}"
CMD="ssh $SSH_OPTS $HOST"
```

## ALL 模式（折叠汇总）

并行查询所有可达 gateway，输出折叠表格:

```bash
for gw_name in "${GATEWAYS[@]}"; do
  (
    ssh $SSH_OPTS ${ssh_user}@${host} \
      "openclaw health 2>&1; openclaw status --deep --all 2>&1"
  ) > "/tmp/oc-status-$gw_name" 2>&1 &
done
wait
```

折叠视图格式:
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
