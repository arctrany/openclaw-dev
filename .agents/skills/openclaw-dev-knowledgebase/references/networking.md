# OpenClaw Network Architecture & 组网

## Network Model

Gateway 是唯一的控制中枢，所有客户端（CLI、Web、apps、nodes）通过 WebSocket 连接到它。

```
┌─────────────────────────────────────────────────────────┐
│                  Internet / Tailnet                      │
│                                                          │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐            │
│  │ Telegram  │   │ WhatsApp │   │ Discord  │  ...       │
│  │  (cloud)  │   │ (baileys)│   │(discord.js)           │
│  └─────┬─────┘   └─────┬────┘   └─────┬────┘           │
│        │               │              │                  │
│        ▼               ▼              ▼                  │
│  ┌─────────────────────────────────────────┐            │
│  │    Gateway  ws://127.0.0.1:18789        │            │
│  │    ─────────────────────────────        │            │
│  │    • WS control plane                   │            │
│  │    • Channel connections                │            │
│  │    • Pi agent runtime                   │            │
│  │    • Session state                      │            │
│  │    • HTTP: Control UI + Canvas/A2UI     │            │
│  └──┬────────┬────────┬────────┬──────────┘            │
│     │        │        │        │                        │
│     ▼        ▼        ▼        ▼                        │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────────┐              │
│  │ CLI  │ │WebChat│ │macOS │ │iOS/Android│              │
│  │      │ │      │ │ App  │ │  Nodes   │              │
│  └──────┘ └──────┘ └──────┘ └──────────┘              │
└─────────────────────────────────────────────────────────┘
```

## Core Rules

1. **One Gateway per host** — 唯一进程拥有 WhatsApp Session 和所有状态
2. **默认 loopback** — `ws://127.0.0.1:18789`，向导默认生成 Gateway token
3. **Nodes 通过 WS 连接** — LAN、Tailnet 或 SSH 隧道
4. **Canvas/A2UI 同端口** — `http://host:18789/__openclaw__/canvas/`
5. **远程用 SSH 隧道或 Tailscale** — 不直接暴露到公网

## 组网方案

### 方案 1: VPS/Home Server 长驻 + Tailscale (推荐)

**适用**: 需要 agent always-on，笔记本会休眠

```
┌─────────────┐        Tailscale         ┌──────────────┐
│  VPS/Server  │ ◄──────────────────────► │   Laptop     │
│  Gateway     │   (100.x.x.x mesh)      │   CLI/App    │
│  Agent 24/7  │                          │   Node       │
└─────────────┘                           └──────────────┘
```

**Config:**
```json5
{
  gateway: {
    bind: "loopback",
    tailscale: { mode: "serve" },  // Tailnet HTTPS
  }
}
```

访问: `https://<magicdns>/`

### 方案 2: 桌面主机 + 远程笔记本

**适用**: 台式机跑 Gateway，笔记本远程控制

```
┌──────────────┐     SSH tunnel          ┌──────────────┐
│  Desktop     │ ◄───────────────────────│   Laptop     │
│  Gateway     │  -L 18789:127.0.0.1:   │   macOS App  │
│              │      18789              │  Remote SSH  │
└──────────────┘                         └──────────────┘
```

macOS 应用 → Settings → "OpenClaw runs" → Remote over SSH

### 方案 3: Tailscale 直接绑定 (无 Serve)

```json5
{
  gateway: {
    bind: "tailnet",
    auth: { mode: "token", token: "your-token" },
  }
}
```

设备直接访问: `ws://<tailscale-ip>:18789`

> ⚠️ 此模式 loopback 不可用，必须配 auth token

### 方案 4: 公网暴露 (Tailscale Funnel)

```json5
{
  gateway: {
    bind: "loopback",
    tailscale: { mode: "funnel" },
    auth: { mode: "password", password: "..." },
  }
}
```

> ⚠️ 必须设置密码。Funnel 仅支持 443/8443/10000 端口。

## SSH 隧道

```bash
# 创建隧道
ssh -N -L 18789:127.0.0.1:18789 user@gateway-host

# 隧道建立后，本地访问
openclaw health
openclaw status --deep
```

## 远程 CLI 配置

持久化远程目标，免每次带 `--url`:

```json5
{
  gateway: {
    mode: "remote",
    remote: {
      url: "ws://127.0.0.1:18789",
      token: "your-token",
    },
  },
}
```

## Credential 优先级

### Local 模式
`--token` > `OPENCLAW_GATEWAY_TOKEN` > `gateway.auth.token` > `gateway.remote.token`

### Remote 模式
`--token` > `gateway.remote.token` > `OPENCLAW_GATEWAY_TOKEN` > `gateway.auth.token`

## Tailscale Auth

当 `tailscale.mode = "serve"` + `gateway.auth.allowTailscale = true`:
- Control UI/WS 可用 Tailscale identity headers 免 token 认证
- HTTP API (`/v1/*`, `/tools/invoke`) 仍需 token/password
- 前提：Gateway host 是可信的

## 安全原则

1. **默认 loopback** — 除非明确需要，不绑定非本地地址
2. **非 loopback 必须认证** — `lan`/`tailnet`/`custom` 绑定必须配 token/password
3. **SSH/Tailscale Serve 最安全** — 无公网暴露
4. **浏览器控制** = 操作员权限 — 仅 tailnet + 显式 node 配对
5. **Funnel 必须密码** — 不允许无密码公网暴露

## Node 连接流程

```
Telegram 消息 → Gateway → 运行 Agent → 需要 Node 工具？
                                          ↓ 是
                                   Gateway WS → Node RPC
                                          ↓
                                   Node 返回结果
                                          ↓
                                   Gateway 回复 Telegram
```

Nodes 不运行 Gateway 服务，只是外设客户端。
