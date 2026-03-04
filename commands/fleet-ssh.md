---
name: fleet-ssh
description: "Interactive SSH to OpenClaw Gateways — single target or tmux multi-pane for ALL"
argument-hint: "[gateway-name|ALL]"
user-invocable: true
---

# /fleet-ssh — 交互式 SSH 连接

连接到一个或多个 OpenClaw Gateway 的交互式 SSH 会话。

## 前置条件

读取 `.claude/openclaw-dev.local.md` 中的 `gateways:` 配置。如果未配置，提示用户参考 `openclaw-dev.local.md.example` 创建。

## Gateway 选择逻辑

1. 如果命令参数指定了 gateway 名称 → 直接使用该 gateway
2. 如果参数为 `ALL` → 选择所有 gateway
3. 如果只有 1 个 gateway → 直接使用
4. 否则 → Preflight 探测可达性，展示选择菜单

### Preflight 探测

对每个非本地 gateway 并行执行:

```bash
ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22} \
    ${ssh_user}@${host} "echo ok" 2>/dev/null
```

本地 gateway (host 为 127.0.0.1 或 localhost) 标记为 ● 可达。

### 选择菜单格式

使用 AskUserQuestion 展示:

```
1. local       127.0.0.1:18789        ● 可达
2. home-mac    192.168.1.100:18789    ● 可达
3. cloud-hk    10.0.0.5:18789         ○ 不可达
4. ALL（tmux 并行打开所有可达 gateway）
```

## 执行

### 单 gateway

直接 SSH 连接:

```bash
ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 \
    -o ServerAliveInterval=15 -o ServerAliveCountMax=2 \
    ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22} \
    ${ssh_user}@${host}
```

本地 gateway 则提示: "local gateway 无需 SSH，你已在本地。"

### ALL (tmux 模式)

1. 检测 tmux 是否可用:

```bash
command -v tmux >/dev/null 2>&1
```

如果不可用:
```
tmux 未安装。安装方式:
  macOS:  brew install tmux
  Linux:  sudo apt install tmux

降级为逐个连接模式。
```

2. 过滤出可达的远程 gateway (排除不可达和纯本地)

3. 检查可达 gateway 数量:
   - 0 个: 提示 "无可达的远程 gateway"
   - > 6 个: 警告 "超过 6 个 pane 可能过小，建议分批操作"

4. 创建 tmux session:

```bash
SESSION="openclaw-fleet-$(date +%s)"

# 第一个 gateway 占据第一个 pane
tmux new-session -d -s "$SESSION" \
    "ssh -o IdentitiesOnly=yes ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22} ${ssh_user}@${host}"

# 后续 gateway 各开一个 pane
for gw in "${REMAINING_GATEWAYS[@]}"; do
    tmux split-window -t "$SESSION" \
        "ssh -o IdentitiesOnly=yes ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22} ${ssh_user}@${host}"
done

# 均匀分布 pane
tmux select-layout -t "$SESSION" tiled

# 附加到 session
tmux attach -t "$SESSION"
```

5. 输出提示:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fleet SSH Session: $SESSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Panes: <N> gateways connected
Reattach: tmux attach -t $SESSION
Kill: tmux kill-session -t $SESSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
