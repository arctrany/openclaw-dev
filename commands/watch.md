---
name: watch
description: "Fleet 实时监控面板 — 持久化分屏界面，实时查看远程节点状态。打开即常驻，所有远程操作可视化。"
argument-hint: "[gateway-name|ALL|stop]"
user-invocable: true
---

# /watch — Fleet 实时监控面板

持久化 tmux 分屏监控界面。打开后常驻，所有远程操作实时可视化（只读）。

**与 `/status` 的关系**：`/status` = 快照（查一次看一次），`/watch` = 持久监视（开了就不关）。

---

## 架构

```
                    ┌─────────────────────────────────────────┐
                    │  tmux session: openclaw-fleet (持久化)    │
                    │                                         │
                    │  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
                    │  │ mini    │  │ sophia  │  │ ...     │ │
                    │  │ tail -f │  │ tail -f │  │ tail -f │ │
                    │  └────▲────┘  └────▲────┘  └────▲────┘ │
                    └───────┼────────────┼────────────┼───────┘
                            │            │            │
                    /tmp/fleet-*.log (append-only)
                            ▲            ▲            ▲
                            │            │            │
主 Agent ──ssh──> 远程节点执行命令 ──> 输出追加到对应 log
```

五个正交模块：

| 模块 | 职责 |
|------|------|
| **Session 管理** | 创建、复用、销毁 tmux session |
| **SSH 连接层** | 免密检测、连接复用、keepalive |
| **Watch Loop** | 周期性健康检测，保持面板活跃 |
| **命令路由** | 其他命令的远程输出同步到面板 |
| **错误可见化** | 连接失败、命令超时等异常在面板中可见 |

---

## Session 生命周期

### 创建条件

| 状态 | 行为 |
|------|------|
| 无已有 session | 创建新 session |
| 已有 session 存活 | **复用**：直接 reattach，不重建 |
| 已有 session + 参数不同 | 提示用户选择：扩展已有 / 重建 |

检测已有 session：

```bash
tmux has-session -t openclaw-fleet 2>/dev/null && echo "EXISTS" || echo "NONE"
```

已有 session 时，直接 reattach 并在 log 中追加分隔线：

```bash
echo "" >> "$LOG"
echo "━━━ $(date '+%H:%M:%S') Session reattached ━━━" >> "$LOG"
```

### 销毁条件

**铁律：只有用户显式请求时才销毁。** Session 存活不依赖 Claude Code 对话。

| 场景 | 行为 |
|------|------|
| Claude Code 对话结束 | session **继续存活**（tmux 独立进程） |
| 用户关闭终端窗口 | session **继续存活**（tmux detach） |
| 用户执行 `/watch stop` | 销毁 session + 清理 log |
| 用户手动 `tmux kill-session` | session 销毁 |

销毁命令：

```bash
tmux kill-session -t "openclaw-fleet" 2>/dev/null
rm -f /tmp/fleet-openclaw-fleet-*.log
```

---

## 前置条件

读取 `.claude/openclaw-dev.local.md` 中的 `gateways:` 配置。如果未配置，提示用户参考 `openclaw-dev.local.md.example` 创建。

---

## 执行流程

### 1. 参数解析

| 参数 | 行为 |
|------|------|
| 无参数 | 若已有 session → reattach；否则选择 gateway |
| `<name>` | 指定 gateway 创建/扩展面板 |
| `ALL` | 所有远程 gateway |
| `stop` | 销毁 session 并清理 |

### 2. Gateway 选择（无已有 session 时）

1. 如果参数指定了 gateway 名称 → 使用该 gateway
2. 如果参数为 `ALL` → 选择所有远程 gateway
3. 如果只有 1 个远程 gateway → 直接使用
4. 否则 → 展示 AskUserQuestion 选择菜单

过滤掉本地 gateway（host 为 127.0.0.1 或 localhost）。

### 3. SSH 免密检测与设置

对每个选中的远程 gateway，检测 SSH BatchMode：

```bash
bash scripts/fleet-ssh-setup.sh "${ssh_user}@${host}" "${ssh_port}" "${ssh_key}"
```

如果 BatchMode 不可用且需要首次设置：

1. 使用 AskUserQuestion 询问用户该节点的 SSH 密码
2. 调用 `fleet-ssh-setup.sh` 并传入密码（第 4 个参数）
3. 密码仅在内存中使用，不落盘
4. 如果 sshpass 未安装，提示安装命令后退出

### 4. 统一 SSH 选项

所有 SSH 命令使用统一选项模板（与 `/status` 共用）：

```bash
SSH_OPTS="-o IdentitiesOnly=yes -o ConnectTimeout=10"
SSH_OPTS="$SSH_OPTS -o ServerAliveInterval=15 -o ServerAliveCountMax=2"
SSH_OPTS="$SSH_OPTS -o ControlMaster=auto"
SSH_OPTS="$SSH_OPTS -o ControlPath=/tmp/oc-ssh-%r@%h:%p"
SSH_OPTS="$SSH_OPTS -o ControlPersist=300"
SSH_OPTS="$SSH_OPTS ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22}"
```

### 5. 创建监控面板

检测终端环境，选择最佳打开方式：

```bash
# 检测终端
if [[ "$TERM_PROGRAM" == "iTerm.app" ]] || pgrep -q iTerm2; then
    # iTerm2: 使用 tmux -CC 控制模式（原生 tab/split）
    tmux -CC attach -t openclaw-fleet 2>/dev/null || \
    tmux -CC new-session -s openclaw-fleet ...
elif [[ "$(uname)" == "Darwin" ]]; then
    # macOS Terminal.app: osascript 打开新 tab
    osascript -e '...'
else
    # Linux / SSH: 打印 attach 指令
    echo "Attach: tmux attach -t openclaw-fleet"
fi
```

构造节点 JSON 并调用脚本：

```bash
NODES_JSON='[{"name":"node-a","user":"your-user","host":"10.0.0.1","port":"22","key":""}]'
bash scripts/fleet-tmux.sh "openclaw-fleet" "$NODES_JSON"
```

脚本会：
- 创建 tmux session，每个节点一个 pane（最多 4 个）
- 每个 pane 运行 `tail -f /tmp/fleet-<session>-<name>.log`
- pane 顶部显示节点名

### 6. 初始诊断

面板创建后，对所有节点**并行**执行初始诊断：

```bash
SESSION="openclaw-fleet"
LOG="/tmp/fleet-${SESSION}-${NODE_NAME}.log"

echo "━━━ $(date '+%H:%M:%S') openclaw health ━━━" >> "$LOG"
ssh $SSH_OPTS "${ssh_user}@${host}" "openclaw health" >> "$LOG" 2>&1 || \
  echo "[ERROR] $(date '+%H:%M:%S') SSH failed for ${NODE_NAME}" >> "$LOG"

echo "━━━ $(date '+%H:%M:%S') openclaw status --deep ━━━" >> "$LOG"
ssh $SSH_OPTS "${ssh_user}@${host}" "openclaw status --deep" >> "$LOG" 2>&1 || \
  echo "[ERROR] $(date '+%H:%M:%S') SSH failed for ${NODE_NAME}" >> "$LOG"
```

### 7. Watch Loop（持久监控）

初始诊断完成后，启动后台 watch loop，定期刷新健康状态：

```bash
# 在后台运行，每 60 秒执行一次 health check
while tmux has-session -t openclaw-fleet 2>/dev/null; do
    sleep 60
    echo "" >> "$LOG"
    echo "━━━ $(date '+%H:%M:%S') [heartbeat] openclaw health ━━━" >> "$LOG"
    ssh $SSH_OPTS "${ssh_user}@${host}" "openclaw health" >> "$LOG" 2>&1 || \
      echo "[ERROR] $(date '+%H:%M:%S') Node unreachable" >> "$LOG"
done &
```

Watch loop 生命周期与 tmux session 绑定：session 销毁时，loop 条件不满足，自动退出。

### 8. 后续交互

面板运行中，用户可以要求主 agent 在指定节点上执行任意命令：

```bash
echo "━━━ $(date '+%H:%M:%S') <用户请求的命令> ━━━" >> "$LOG"
ssh $SSH_OPTS "${ssh_user}@${host}" "<command>" >> "$LOG" 2>&1
```

---

## 跨命令集成

**核心原则：当 fleet session 活跃时，所有远程操作都同步到面板。**

其他命令（`/status`、`/diagnose`）检测 fleet session 是否活跃：

```bash
tmux has-session -t openclaw-fleet 2>/dev/null
```

若活跃，远程命令输出**双写**：
1. 正常输出到 Claude Code 对话（用于 AI 分析）
2. 同时 append 到对应节点的 fleet log（用于面板可视化）

```bash
# 双写模板
OUTPUT=$(ssh $SSH_OPTS "${ssh_user}@${host}" "openclaw health" 2>&1)
echo "$OUTPUT"  # 对话输出

# 若 fleet session 活跃，同步到面板
if tmux has-session -t openclaw-fleet 2>/dev/null; then
    LOG="/tmp/fleet-openclaw-fleet-${NODE_NAME}.log"
    echo "" >> "$LOG"
    echo "━━━ $(date '+%H:%M:%S') [/status] openclaw health ━━━" >> "$LOG"
    echo "$OUTPUT" >> "$LOG"
fi
```

---

## 错误可见化

| 场景 | 面板中显示 |
|------|-----------|
| SSH 连接失败 | `[ERROR] HH:MM:SS SSH connection failed for <node>` |
| 命令执行超时 | `[TIMEOUT] HH:MM:SS Command timed out after 30s` |
| 节点不可达 | `[UNREACHABLE] HH:MM:SS Node <name> unreachable` |
| 连接恢复 | `[RECOVERED] HH:MM:SS Node <name> reconnected` |

heartbeat 在面板中提供生命信号——如果超过 2 分钟没有新行出现，说明 watch loop 已终止。

---

## 依赖

| 工具 | 用途 | 安装 |
|------|------|------|
| tmux | 分屏终端 | `brew install tmux` / `apt install tmux` |
| jq | JSON 解析 | `brew install jq` / `apt install jq` |
| sshpass | 首次密码认证 | `brew install hudochenkov/sshpass/sshpass` / `apt install sshpass` |

sshpass 仅在首次设置免密登录时需要，后续不再使用。
