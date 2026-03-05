---
name: status
description: "Query OpenClaw Gateway status — fleet overview, gateway detail, and per-resource drill-down. Supports local cache and remote Gateways."
argument-hint: "[gateway-name|ALL] [agents|channels|plugins|nodes]"
user-invocable: true
---

# /status — OpenClaw 状态查询

五个独立功能模块，正交设计：

| 模块 | 职责 |
|------|------|
| **缓存层** | 读写 `.claude/openclaw-dev.local.md`，加速重复调用 |
| **L0 Fleet** | 汇总所有已知 gateway 的一行概览 |
| **L1 Gateway** | 单个 gateway 的完整状态（Agents/Channels/Plugins/Nodes 摘要） |
| **L2 资源** | 单类资源的详细列表（agents/channels/plugins/nodes 之一） |
| **意图层** | 双层记忆（YAML 聚合表 + 事件日志），学习用户实际行为，推断下一步 |

---

## 缓存层 — 读取

在任何探测命令之前，先读 `.claude/openclaw-dev.local.md` YAML frontmatter：

```
control_center_status: not_installed | installed
gateways:            # 与 gateways 配置块共用，缓存已知节点
```

**路由决策表（根据参数 + 缓存）：**

| 参数 | 缓存状态 | 执行路径 |
|------|---------|---------|
| 无参数，无 gateways | 任意 | → 本地环境探测，输出 L0（仅 control-center） |
| 无参数，有 gateways | 任意 | → 并行查所有 gateways → L0 Fleet 视图 |
| `<name>` | 任意 | → 查指定 gateway → L1 Gateway 视图 |
| `<name> agents\|channels\|plugins\|nodes` | 任意 | → 查指定 gateway 指定资源 → L2 资源视图 |
| `ALL` | 任意 | → 并行查所有可达 → L0 Fleet 视图 |

缓存命中 `control_center_status` 时，**跳过**本地 bash 环境探测，直接使用缓存值渲染 control-center 行。

---

## 本地环境探测（无缓存时执行）

```bash
echo "===ENV===" && hostname && whoami && \
(command -v openclaw && openclaw --version 2>/dev/null || echo "NO_OPENCLAW") && \
(test -f ~/.openclaw/openclaw.json && echo "HAS_CONFIG" || echo "NO_CONFIG") && \
echo "===END==="
```

**探测结果处理：**

| openclaw | config | control_center_status | 下一步 |
|:---:|:---:|---|---|
| 是 | 是 | `installed` | 写缓存，执行正常查询 |
| 是 | 否 | `installed` | 写缓存，提示 `openclaw onboard` 初始化 |
| 否 | 否 | `not_installed` | 写缓存，渲染 Onboarding 视图 |

探测完成后立即写缓存（见"缓存层 — 写入"）。

---

## L0: Fleet 视图

**触发条件：** 无参数 + 有 gateways 配置，或参数为 `ALL`

**Step 1: control-center 行**

从缓存读取 `control_center_status`（或刚完成的探测结果），生成本机行：

```
control-center   ✗ 未安装   —        —          —
control-center   ● UP       <N>      <ch>       <uptime>
```

**Step 2: 并行查询所有 remote gateways**

对每个 gateway 并行执行（SSH 或本地）：

```bash
openclaw health 2>&1 | tail -1; echo "===SEP==="; \
openclaw status --deep --all 2>&1
```

SSH 命令模板（远程 gateway）：

```bash
SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes -o ControlMaster=auto \
  -o ControlPath=/tmp/oc-ssh-%r@%h:%p -o ControlPersist=60"
SSH_OPTS="$SSH_OPTS ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22}"
ssh $SSH_OPTS ${ssh_user}@${host} "<命令>"
```

**Step 3: 汇总输出**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fleet Status   <日期时间>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Gateway          Status    Agents  Channels    Uptime
───────────────  ────────  ──────  ──────────  ──────
sophia-mini      ● UP      3       web✓ tg✓    12h
mini             ● UP      1       web✓        3d
control-center   ✗ 未安装   —       —           —
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
在线: 2/3   运行 /status <gateway-name> 下钻详情
```

不可达 gateway 显示 `○ 不可达`，不报错。

输出完成后执行**意图层**：提取信号 → 读历史 → 生成并输出下一步建议 → 写入记忆。

---

## L0: Onboarding 视图（control-center 未安装时）

**触发条件：** 无 gateways 配置 且 `control_center_status: not_installed`

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OpenClaw   <hostname>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

本机未安装 OpenClaw

  安装本机节点：运行 /setup-node（约 5 分钟）

  查询远程节点：在 .claude/openclaw-dev.local.md
  的 gateways: 中添加节点，再运行 /status <name>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

若 Tailscale 在线，追加可用 peers 提示：

```
  检测到 Tailscale 节点（可直接添加为 gateway）：
    sophia-mini   100.116.161.3
    mini          100.92.217.43
```

Tailscale 探测命令：

```bash
command -v tailscale && tailscale status --json 2>/dev/null | \
  jq -r '.Peer[] | select(.Online) | "\(.HostName)\t\(.TailscaleIPs[0])"' \
  2>/dev/null || true
```

---

## L1: Gateway 详情视图

**触发条件：** `/status <gateway-name>`

**Step 1: 查询**

本地 gateway（`host: 127.0.0.1` 或无 ssh_user）：

```bash
openclaw health 2>&1; echo "===SEP==="; openclaw status --deep --all 2>&1
```

远程 gateway：通过 SSH 执行同样命令。

**Step 2: 输出**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<gateway-name>   <host>   ● healthy   uptime:<T>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Gateway
  port: <port>   sessions: <N>   plugins: <N> loaded

Agents (<N>)
  <id>   <model>   <workspace 短路径>

Channels (<online>/<total>)
  ✅ webchat    connected
  ✅ telegram   connected
  ❌ whatsapp   not configured

Plugins (<N> loaded, <M> errors)
  ✅ voice-call   v1.2.0
  ✅ memory-core  v2.0.0

Nodes (<N>)
  exec-node    exec    ● paired
  screen-node  screen  ● paired

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
下钻: /status <gateway-name> agents|channels|plugins|nodes
```

**降级（openclaw 不可用时）：** 读 `~/.openclaw/openclaw.json`，标注 `[降级模式] 以下为配置文件静态信息`。

输出完成后执行**意图层**：提取信号 → 读历史 → 生成并输出下一步建议 → 写入记忆。

---

## L2: 资源详情视图

**触发条件：** `/status <gateway-name> <resource>`，resource 为 `agents` / `channels` / `plugins` / `nodes` 之一

四个资源视图独立，互不依赖。每个视图输出完成后均执行**意图层**：提取信号 → 读历史 → 生成下一步建议 → 写入记忆。

### agents

查询命令：

```bash
openclaw agents list --bindings 2>&1
```

输出：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<gateway-name> › Agents
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ID            Model                Sessions  Workspace
────────────  ───────────────────  ────────  ──────────────────
assistant     claude-sonnet-4-5    24        workspace-assistant
coder         claude-opus-4        8         workspace-coder
researcher    gemini-pro           3         workspace-researcher
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### channels

查询命令：

```bash
openclaw channels status --probe 2>&1
```

输出：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<gateway-name> › Channels
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Channel    Status          账号 / 配置
─────────  ──────────────  ──────────────────
webchat    ✅ connected     内置
telegram   ✅ connected     @my_bot
whatsapp   ❌ not configured
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### plugins

查询命令：

```bash
openclaw plugins list 2>&1
```

输出：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<gateway-name> › Plugins
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugin        Version  Status   Tools
────────────  ───────  ───────  ──────────────────────
voice-call    v1.2.0   ✅ loaded  call, hangup, tts
memory-core   v2.0.0   ✅ loaded  remember, recall, forget
bad-plugin    v0.1.0   ❌ error   —
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### nodes

查询命令：

```bash
openclaw status --deep --all 2>&1 | grep -A20 "Nodes"
```

输出：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
<gateway-name> › Nodes
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Node          Type    Status     Last Seen
────────────  ──────  ─────────  ──────────
exec-node     exec    ● paired   2m ago
screen-node   screen  ● paired   5m ago
camera-node   camera  ○ offline  3h ago
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 缓存层 — 写入

以下两种事件触发写入，写入目标：`.claude/openclaw-dev.local.md` YAML frontmatter。

**事件 1：本地环境探测完成**

写入或更新：

```yaml
control_center_status: not_installed  # 或 installed
```

**事件 2：首次成功连接远程 gateway**

若该 gateway 不在 `gateways:` 列表中，自动 append：

```yaml
gateways:
  - name: sophia-mini
    host: 100.116.161.3
    ssh_port: 22
    ssh_user: <当前用户>
```

写入时使用 YAML frontmatter append，不修改 markdown body，不覆盖现有字段。

---

## 意图层 — 记忆架构

双层结构，记忆文件均在 `.claude/openclaw-dev/memory/` 下（已 gitignore，不提交）。

### Layer 1：聚合频次表（主决策依据）

文件：`.claude/openclaw-dev/memory/status-stats.yaml`

LLM 直接读取，按 `(视图, 主信号)` 二元组定位，O(1) 查表。记录**用户实际执行**的命令频次，而非系统推荐。

```yaml
L0-fleet:
  healthy:
    /status sophia-mini: 12
    /fleet-ssh: 8
    /status mini: 3
  gateway-down:
    /diagnose: 19
    /status ALL: 2

L1:
  plugin-error:
    /diagnose: 7
    /status sophia-mini plugins: 4
  healthy:
    /status sophia-mini agents: 5
    /deploy-skill assistant: 3

L2-agents:
  healthy:
    /deploy-skill assistant: 6
    /scaffold-agent: 2

_meta:
  total_sessions: 47
  last_updated: "2026-03-05T14:40:00"
  last_decay: "2026-01-01"
  schema_version: 1
```

若文件不存在，首次写入时自动创建。

### Layer 2：事件日志（审计 + 回溯）

文件：`.claude/openclaw-dev/memory/status-events.log`

Append-only，保留原始行为序列，铁律：只 append，不删除、不覆盖、不截断。

格式（单行，空格分隔）：
```
<ISO时间> <视图层级> <gateway> <主信号> <用户实际命令|PENDING>
```

示例：
```
2026-03-05T14:32:00 L0-fleet ALL healthy USER:/status sophia-mini
2026-03-05T14:35:00 L1 sophia-mini plugin-error USER:/diagnose sophia-mini
2026-03-05T14:40:00 L2-agents sophia-mini healthy PENDING
```

### 写入机制（学习闭环）

1. 本次 `/status` 输出结束 → 向 `status-events.log` append 一条，用户命令字段写 `PENDING`
2. 用户执行下一条命令时 → **回填**上一条 PENDING 记录为 `USER:<实际命令>` → 同时更新 `status-stats.yaml` 对应计数器 +1
3. 若下一条命令不是 `/status` 相关命令（如普通对话） → 回填为 `USER:other`，不更新计数器

**信号标准化**：取当前输出中最高优先级信号作为主信号 key（`gateway-down` / `plugin-error` / `channel-disconnect` / `healthy` / `not-installed` 等），忽略数量，精确匹配。

### 记忆衰减

每季度（检查 `_meta.last_decay`，距今 > 90 天时触发）：
- 将 `status-stats.yaml` 所有计数器乘以 0.7（向下取整）
- 计数器降为 0 的条目删除
- 更新 `_meta.last_decay`

---

## 意图层 — 信号提取

### 快照信号（从当前输出提取）

| 信号 key | 优先级 | 触发条件 |
|----------|:------:|---------|
| `gateway-down` | P0 | gateway DOWN / 不可达 |
| `plugin-error` | P0 | plugin 加载错误 |
| `channel-disconnect` | P1 | channel 曾 connected 现断开 |
| `channel-unconfigured` | P2 | channel not configured |
| `node-offline` | P2 | node offline |
| `agents-zero` | P2 | agents 数量为 0 |
| `sessions-zero` | P2 | sessions 持续为 0（无活跃会话） |
| `gateway-just-restarted` | P2 | uptime < 5min |
| `not-installed` | P3 | control-center 未安装 |
| `healthy` | P3 | 所有组件正常 |

### 差量信号（与上次记忆对比）

读取 `status-events.log` 最后一条同视图记录，比较状态变化：

| 差量 | 信号 key | 优先级 |
|------|----------|:------:|
| 上次 UP → 本次 DOWN | `degraded` | P0 |
| 上次 connected → 本次 断开 | `channel-lost` | P1 |
| agents 数量减少 | `agent-removed` | P2 |
| 上次 DOWN → 本次 UP | `recovered` | P3（正面） |

差量信号存在时��在视图头部输出变化提示：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fleet Status   2026-03-05 14:35
[!] sophia-mini: UP → DOWN（对比 14:32 查询）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 意图层 — 信号→操作映射表

每个信号对应明确的候选操作列表（按推荐优先级排序）：

| 信号 key | 候选操作（按优先级） |
|----------|---------------------|
| `gateway-down` | `/diagnose <name>`, `/lint-config <name>` |
| `degraded` | `/diagnose <name>` — ⚠ 状态恶化 |
| `plugin-error` | `/diagnose <name>`, `/status <name> plugins` |
| `channel-disconnect` | `/diagnose <name>`, `/status <name> channels` |
| `channel-lost` | `/diagnose <name>` — ⚠ channel 丢失 |
| `channel-unconfigured` | 指引编辑 `openclaw.json` channel 配置 |
| `node-offline` | `/status <name> nodes`, `/diagnose <name>` |
| `agents-zero` | `/scaffold-agent` |
| `sessions-zero` | 指引配置 channel 入口 |
| `agent-removed` | `/status <name> agents` — ⚠ agent 减少 |
| `gateway-just-restarted` | 提示等待稳定（uptime < 5min），可选 `/status <name>` 稍后复查 |
| `not-installed` | `/setup-node` |
| `recovered` | `/status <name>` — 确认恢复详情 |
| `healthy` (L0) | `/status <最常用gateway>`, `/fleet-ssh` |
| `healthy` (L1) | `/status <name> agents\|channels\|plugins\|nodes`（按用户历史） |
| `healthy` (L2-agents) | `/deploy-skill <agent>`, `/list-skills <agent>` |
| `healthy` (L2-channels) | `/status <name>` 返回概览 |
| `healthy` (L2-plugins) | `/status <name>` 返回概览 |
| `healthy` (L2-nodes) | `/status <name>` 返回概览 |

---

## 意图层 — 建议生成算法

**输入**：当前主信号 + 差量信号 + `status-stats.yaml` 对应场景的频次数据

**算法**：

```
1. 取主信号 key（快照信号中最高优先级的）
2. 若有差量信号且优先级 >= 主信号 → 用差量信号替换

3. 查映射表，获取该信号的候选操作列表

4. 查 status-stats.yaml[当前视图][主信号 key]
   → 若存在且总次数 >= 5 → 按用户历史频次排序候选（权重 0.7 历史 + 0.3 映射表顺序）
   → 若存在但总次数 < 5 → 权重反转（0.3 历史 + 0.7 映射表顺序）
   → 若不存在（冷启动） → 直接用映射表顺序

5. P0/P1 信号的首条操作**锁定首位**，不受历史排序影响

6. 取前 3 条输出

7. 若完全无信号 + 无历史（首次全健康） → 输出固定默认集：
   L0: /status <第一个gateway> — 查看详情
   L1: /status <name> agents — 查看 agent 列表
   L2: /status <name> — 返回概览
```

### 降级模式意图层行为

当 L1 视图使用降级模式（openclaw 不可用，读静态配置）时：

- **跳过**快照信号提取（静态配置无法反映运行时状态）
- **跳过**差量信号（无实时数据）
- 固定输出两条建议：
  1. `/diagnose <name>` — 诊断 openclaw 不可用原因
  2. `/lint-config <name>` — 验证配置文件格式
- **不写入记忆**（降级态建议不代表正常使用偏好，避免污染历史）

---

## 下一步建议输出格式

每个视图（L0/L1/L2）末尾统一追加建议块，建议 1-3 条：

```
────────────────────────────────────────────────────
下一步
  /status sophia-mini           — 查看 gateway 详情
  /fleet-ssh                    — 进入 fleet 管控面板
  /setup-node                   — 在本机安装 OpenClaw
────────────────────────────────────────────────────
```

有 P0 信号时，首条建议标注紧急标记：

```
────────────────────────────────────────────────────
下一步  [检测到异常]
  /diagnose sophia-mini         — ⚠ plugin 加载错误，建议立即诊断
  /status sophia-mini plugins   — 查看 plugin 详情
────────────────────────────────────────────────────
```

---

## 远程 Gateway SSH 配置

所有远程查询使用统一 SSH 选项（复用连接，减少握手）：

```bash
SSH_OPTS="-o IdentitiesOnly=yes -o ConnectTimeout=10"
SSH_OPTS="$SSH_OPTS -o ServerAliveInterval=15 -o ServerAliveCountMax=2"
SSH_OPTS="$SSH_OPTS -o ControlMaster=auto"
SSH_OPTS="$SSH_OPTS -o ControlPath=/tmp/oc-ssh-%r@%h:%p"
SSH_OPTS="$SSH_OPTS -o ControlPersist=300"
SSH_OPTS="$SSH_OPTS ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22}"
```
