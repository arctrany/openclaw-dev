# 状态查询 Runbook

## 设计原则

本 runbook 遵循 FSFR (Fewer Steps, Faster Results) 原则：
- 分层递进，每层独立产出可用结果
- 弱模型（Haiku 级别）只需执行 Layer 0 + Layer 1 即可完成
- 强模型可选择性执行 Layer 2 获取更多细节

## 参数

- **host** (可选): Gateway 机器地址。默认为本地。

## 确定连接方式

```bash
if [ -n "$HOST" ]; then
  CMD="ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 $HOST"
else
  CMD=""
fi
```

## Layer 0: 环境探测（必执行）

用 **1 个命令** 确定 3 个布尔状态：

```bash
echo "===ENV===" && hostname && whoami && \
(command -v openclaw && openclaw --version 2>/dev/null || echo "NO_OPENCLAW") && \
(test -f ~/.openclaw/openclaw.json && echo "HAS_CONFIG" || echo "NO_CONFIG") && \
echo "===END==="
```

**降级策略表**（查表选路径，不需要"理解"）:

| has_openclaw | has_config | 执行路径 |
|:---:|:---:|---|
| true | true | → Layer 1A（正常路径） |
| true | false | 提示: "openclaw 已安装但未初始化，运行 `openclaw onboard`" → **停止** |
| false | true | → Layer 1B（降级路径） |
| false | false | 提示: "OpenClaw 未安装，使用 `/setup-node` 安装" → **停止** |

## Layer 1A: 正常状态查询（1 个命令）

```bash
$CMD openclaw health 2>&1; echo "===SEP==="; $CMD openclaw status --deep --all 2>&1
```

`openclaw status --deep --all` 是 OpenClaw 的原生综合命令，已包含 agents、channels、plugins 的完整信息。**不需要** 单独执行 `openclaw agents list`、`openclaw channels status --probe`、`openclaw plugins list`。

## Layer 1B: 降级路径（1 个命令）

openclaw CLI 不可用但 config 存在时，直接读 JSON 生成静态摘要：

```bash
$CMD jq '{
  gateway: {port: .gateway.port, bind: .gateway.bind},
  agents: [.agents.list[] | {id, name, model}],
  channels: [.channels | to_entries[] | select(.value.accounts // .value.botToken // .value.token) | .key]
}' ~/.openclaw/openclaw.json
```

输出时标注: "[降级模式] Gateway 进程状态未知，以下为配置文件静态信息"

## Layer 2: 深度补充（可选）

仅在以下情况执行:
- 用户明确要求 channel 连通性探测
- 用户明确要求 session 统计

```bash
# Channel 实际连通性（Layer 1 只能看到配置，这里探测实际连接）
$CMD openclaw channels status --probe

# Session 活跃度
$CMD bash -c 'for agent in $(jq -r ".agents.list[].id" ~/.openclaw/openclaw.json); do
  sessions=$(ls ~/.openclaw/agents/$agent/sessions/*.jsonl 2>/dev/null | wc -l | tr -d " ")
  echo "$agent: $sessions active sessions"
done'
```

## 输出模板

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

## 多 Gateway 查询

如果用户有多个 Gateway，并行查询所有可达节点:

```bash
for gw_name in "${GATEWAYS[@]}"; do
  (
    ssh $SSH_OPTS ${ssh_user}@${host} \
      "openclaw health 2>&1; openclaw status --deep --all 2>&1"
  ) > "/tmp/oc-status-$gw_name" 2>&1 &
done
wait
```
