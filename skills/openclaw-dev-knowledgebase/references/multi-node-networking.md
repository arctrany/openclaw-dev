# OpenClaw 多节点组网方案

## 架构概述

```
┌─── Tailnet (WireGuard 加密) ──────────────────────────┐
│                                                        │
│  国内 Remote Gateway (100.x.x.1)     新加坡 Remote Gateway (100.x.x.2)  │
│  ┌────────────────────┐        ┌──────────────┐       │
│  │ Gateway + Node     │◄─WS────│ Node         │       │
│  │                    │ Tailscale│              │       │
│  │ agent1: master     │        │ 提供远程 exec  │       │
│  │ agent2: worker-cn  │        │ screen, canvas│       │
│  │ agent3: worker-sg  │        │              │       │
│  │                    │        │              │       │
│  │ Channels:          │        └──────────────┘       │
│  │ WhatsApp/Telegram  │                               │
│  │ Discord/Web        │        你的笔记本 (100.x.x.3)  │
│  └────────────────────┘        ┌──────────────┐       │
│         ▲                      │ Claude Code  │       │
│         └──────SSH─────────────│ / Gemini     │       │
│                                └──────────────┘       │
└────────────────────────────────────────────────────────┘
```

## 关键概念

| 概念 | OpenClaw 定义 | 你的场景 |
|------|--------------|---------|
| **Gateway** | 唯一控制面，管理 sessions/agents/channels | 国内 Remote Gateway |
| **Node** | 连接设备，提供工具能力 (exec/screen/canvas) | 两台 Remote Gateway 都是 Node |
| **Agent** | AI 大脑 (workspace+sessions)，**全部运行在 Gateway 上** | master + worker-cn + worker-sg |

> ⚠️ Agent 不运行在 Node 上。worker-sg 在国内 Gateway 运行，但可将工具执行路由到新加坡 Node。

## 组网步骤

### 第一步：Tailscale 互联

两台机器 + 笔记本，加入同一 Tailnet：

```bash
# 每台机器:
brew install tailscale
tailscale up

# 验证互通
tailscale status
# 应看到:
#   100.x.x.1  <gateway-host>-cn   macOS  -
#   100.x.x.2  <gateway-host>-sg   macOS  -
#   100.x.x.3  laptop        macOS  -
```

### 第二步：国内 Gateway 配置

```json5
// ~/.openclaw/openclaw.json (国内 Remote Gateway)
{
  agents: {
    defaults: {
      model: "anthropic/claude-sonnet-4-5",
    },
    list: [
      {
        id: "master",
        name: "Master",
        default: true,
        workspace: "~/.openclaw/workspace-master",
        model: "anthropic/claude-opus-4-6",
        subagents: {
          allowAgents: ["worker-cn", "worker-sg"],
        },
      },
      {
        id: "worker-cn",
        name: "Worker CN",
        workspace: "~/.openclaw/workspace-worker-cn",
        model: "anthropic/claude-sonnet-4-5",
      },
      {
        id: "worker-sg",
        name: "Worker SG",
        workspace: "~/.openclaw/workspace-worker-sg",
        model: "anthropic/claude-sonnet-4-5",
      },
    ],
  },
  tools: {
    agentToAgent: {
      enabled: true,
      allow: ["master", "worker-cn", "worker-sg"],
    },
  },
}
```

### 第三步：发布发现信息

```bash
# 国内 Gateway — 发布 Tailscale 地址
export OPENCLAW_TAILNET_DNS=<gateway-host>-cn
export OPENCLAW_SSH_PORT=22
```

### 第四步：新加坡 Node 连接

新加坡机器作为 Node 连接到国内 Gateway:

```bash
# 新加坡 Remote Gateway — 只需安装 OpenClaw 并配对
# Node 通过 Tailscale 连到 Gateway 的 WS 端口
# Gateway 地址: 100.x.x.1:18789 (或 <gateway-host>-cn:18789 via MagicDNS)
```

### 第五步：验证

```bash
# 从国内 Gateway:
openclaw agents list --bindings
openclaw channels status --probe

# 从笔记本 (代码 agent):
ssh 100.x.x.1 "openclaw agents list --bindings"
```

## 委派模型

```
master (opus)
├── sessions_spawn → worker-cn (sonnet)
│   └── 工具执行: 本地 (国内 Node)
└── sessions_spawn → worker-sg (sonnet)
    └── 工具执行: ??? (见下方限制)
```

### ⚠️ 已知限制

| 能力 | 状态 | 说明 |
|------|:---:|------|
| 同 Gateway 多 agent | ✅ | `agents.list[]` |
| master→worker 委派 | ✅ | `sessions_spawn` + `subagents.allowAgents` |
| agent 间消息 | ✅ | `tools.agentToAgent.enabled: true` |
| 新加坡作为 Node 连接 | ✅ | Tailscale + WS |
| worker-sg 工具路由到新加坡 Node | ⚠️ | **无 per-agent Node 绑定**。上游不支持"agent X 专用 Node Y" |
| 统一节点视图 (IP/位置/状态) | ⚠️ | 部分可查，无现成聚合视图 |
| Node 地理位置标注 | ❌ | 需自建 |
| 跨 Gateway 联邦 | ❌ | 不存在 |

### 关于 "per-agent Node 绑定" 的说明

这是当前架构的主要限制。你可能希望：

```
worker-cn → 在国内 Node 执行
worker-sg → 在新加坡 Node 执行
```

但目前 OpenClaw 的 Node 只是提供 capabilities 给 Gateway，**没有** agent→Node 的绑定机制。所有 agent 共享所有 Node 的能力。

**应对策略**:
1. worker-sg 的 workspace 设置为新加坡 Node 上的路径 → 文件操作落到新加坡
2. 利用 `sandbox.scope: "agent"` 隔离容器
3. 期待上游未来增加 per-agent Node routing

## 节点可见性

从 Gateway 可查询的信息：

```bash
# Agent 视图
openclaw agents list --bindings

# Channel 状态
openclaw channels status --probe

# Session 统计
ls ~/.openclaw/agents/*/sessions/*.jsonl | wc -l

# Plugin 状态
openclaw plugins list

# Node 连接 (Tailscale 视角)
tailscale status
```

### 缺失的可见性 (需自建)

```bash
# Node 地理位置 — 用 Tailscale API
tailscale status --json | jq '.Peer[] | {Name: .HostName, IP: .TailscaleIPs[0], Location: .Location}'

# Node 资源
ssh 100.x.x.2 "sysctl -n hw.memsize && sysctl -n hw.ncpu && uptime"

# Agent token 消耗
# 无内置指标，需从 session 日志分析
```
