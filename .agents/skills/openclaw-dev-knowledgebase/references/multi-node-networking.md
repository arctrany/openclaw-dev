# OpenClaw 多节点组网方案

## 当前方案：单 Gateway + 远程 Node

```
┌─── Tailnet (WireGuard 加密) ──────────────────────────────┐
│                                                            │
│  国内 Remote Gateway (Gateway + Node)     新加坡 Remote Gateway (Node)   │
│  ┌────────────────────────┐        ┌──────────────────┐    │
│  │ Gateway :18789         │◄─ WS ──│ Node             │    │
│  │                        │Tailscale│ exec, screen,    │    │
│  │ agent1: master (opus)  │        │ canvas           │    │
│  │ agent2: worker-cn      │        └──────────────────┘    │
│  │ agent3: worker-sg      │                                │
│  │                        │        你的笔记本 (100.x.x.3)   │
│  │ agent1 ──spawn──► agent2        ┌──────────────────┐    │
│  │ agent1 ──spawn──► agent3        │ Claude Code /    │    │
│  │                        │◄─SSH───│ Gemini           │    │
│  └────────────────────────┘        └──────────────────┘    │
└────────────────────────────────────────────────────────────┘
```

**核心原则**：
- 所有 Agent 运行在同一个 Gateway 上
- 远程机器作为 Node 提供工具能力 (exec/screen/canvas)
- Tailscale 提供跨地域加密互联
- 代码 Agent 通过 SSH 管理 Gateway

## 第一步：Tailscale 组网

```bash
# 三台机器都执行:
brew install tailscale
tailscale up

# 验证
tailscale status
# 100.64.0.1  mac-cn     macOS  online
# 100.64.0.2  mac-sg     macOS  online
# 100.64.0.3  laptop     macOS  online
```

## 第二步：国内 Gateway 配置

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
      },
      {
        id: "worker-sg",
        name: "Worker SG",
        workspace: "~/.openclaw/workspace-worker-sg",
      },
    ],
  },
  tools: {
    agentToAgent: {
      enabled: true,
      allow: ["master", "worker-cn", "worker-sg"],
    },
  },
  gateway: {
    bind: "loopback",   // 安全：仅本地绑定
    port: 18789,
    auth: {
      token: "YOUR_GATEWAY_TOKEN",
      allowTailscale: true,  // Tailscale 身份认证
    },
  },
}
```

## 第三步：发布发现信息

```bash
# 国内 Gateway
export OPENCLAW_TAILNET_DNS=mac-cn        # MagicDNS 名称
export OPENCLAW_SSH_PORT=22               # SSH 端口
# 可选: 禁用 Bonjour (跨网段无用)
export OPENCLAW_DISABLE_BONJOUR=1
```

## 第四步：新加坡 Node 连接

新加坡 Remote Gateway 作为 Node 连接到国内 Gateway：

```bash
# 新加坡 Remote Gateway 安装 OpenClaw
# 使用 Node 模式连接到国内 Gateway
# Gateway 地址: mac-cn:18789 (Tailscale MagicDNS)
# 或: 100.64.0.1:18789 (Tailscale IP)

# 如果 Gateway 绑定 loopback, 需要 SSH 隧道:
ssh -N -L 18789:127.0.0.1:18789 user@mac-cn &
```

Node 连接后提供 capabilities: `exec`, `screen`, `canvas`

## 第五步：代码 Agent 远程管理

从笔记本 (Claude Code/Gemini) 查询 Gateway 状态：

```bash
# SSH 到 Gateway 机器
ssh mac-cn "openclaw agents list --bindings"
ssh mac-cn "openclaw channels status --probe"
ssh mac-cn "openclaw plugins list"

# 或建立 SSH 隧道后直接用 CLI
ssh -N -L 18789:127.0.0.1:18789 user@mac-cn &
openclaw --url ws://127.0.0.1:18789 --token YOUR_TOKEN status --deep
```

## 委派模型

```
master (opus) ── sessions_spawn ──► worker-cn (sonnet)
                                         └── 工具在国内 Node 执行
               ── sessions_spawn ──► worker-sg (sonnet)
                                         └── 工具在 ??? Node 执行 (见限制)
```

`sessions_spawn` 参数：
- `task`: 任务描述
- `agentId`: 目标 worker ID
- `model`: 可覆盖 model
- `runTimeoutSeconds`: 超时

## 已知限制

| 能力 | 状态 | 说明 |
|------|:---:|------|
| 同 Gateway 多 agent 委派 | ✅ | `sessions_spawn` + `subagents.allowAgents` |
| agent 间消息 | ✅ | `sessions_send` + `agentToAgent.enabled` |
| 远程 Node 连接 | ✅ | Tailscale WS / SSH 隧道 |
| **per-agent Node 绑定** | ❌ | 不能指定 "worker-sg 的 exec 在新加坡 Node 上执行" |
| **跨 Gateway 委派** | ❌ | 两个 Gateway 间无联邦协议 |
| Node 地理位置标注 | ❌ | Gateway 不记录 Node 位置 |

### per-agent Node 绑定 变通方案

虽然不能原生绑定 agent→Node，但可以：

1. **workspace 分离**: worker-sg 的 workspace 中放新加坡相关的文件/配置
2. **exec 显式 SSH**: worker-sg 的 AGENTS.md 指示它通过 SSH 到新加坡执行
   ```markdown
   # AGENTS.md (worker-sg workspace)
   When you need to execute commands, SSH to the Singapore node:
   ssh mac-sg "your-command-here"
   ```
3. **sandbox 隔离**: 每个 agent 独立容器

## 节点可见性

### 从 Gateway 可获取

```bash
# Agent 列表 + 模型 + workspace
jq '.agents.list[] | {id, name, model, workspace}' ~/.openclaw/openclaw.json

# Bindings
openclaw agents list --bindings

# Channel 连接状态
openclaw channels status --probe

# Session 统计
for agent in master worker-cn worker-sg; do
  count=$(ls ~/.openclaw/agents/$agent/sessions/*.jsonl 2>/dev/null | wc -l)
  echo "$agent: $count sessions"
done

# Node 连接 (通过 Tailscale)
tailscale status --json | jq '.Peer[] | {Name: .HostName, IP: .TailscaleIPs[0], Online: .Online}'
```

### 需自建的可见性

| 信息 | 获取方式 |
|------|---------|
| Node IP 地址 | `tailscale status --json` |
| Node 地理位置 | `tailscale status --json` → `.Location` 或 IP GeoIP |
| Node 资源 (CPU/MEM) | `ssh node "sysctl hw.ncpu; sysctl hw.memsize; uptime"` |
| Agent token 消耗 | Session 日志分析 |

---

## 未来：Clawnet 重构计划

上游 `docs/refactor/clawnet.md` 描述了协议统一计划：

| 阶段 | 内容 | 对你的影响 |
|------|------|-----------|
| Phase 1 | WS 协议增加 role/scope/deviceId | Node 角色更明确 |
| Phase 2 | Bridge → WS 迁移 | Node 连接统一 |
| Phase 3 | 集中式 approvals | 审批从 Node 迁到 Gateway |
| Phase 4 | 全面 TLS | 跨网安全增强 |
| Phase 5 | 废弃 Bridge | 简化协议栈 |
| Phase 6 | 设备绑定认证 | 安全增强 |

**Clawnet 完成后可能解决的问题**：
- 统一的 Node 身份和 presence → 更好的节点可见性
- 角色 (node/operator) + scope 分离 → 未来可能支持 per-agent Node 路由
- 但 **跨 Gateway 联邦仍不在计划中** → 如需要需单独提 feature request

> 建议关注上游 `clawnet.md` 的进展，适时跟进。
