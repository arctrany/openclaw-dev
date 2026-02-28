# OpenClaw Workspace、Channels、Discovery

## Workspace 引导文件

Agent workspace 是 agent 的"家"。默认 `~/.openclaw/workspace`。

### 文件清单

| 文件 | 用途 | 加载时机 |
|------|------|---------|
| `AGENTS.md` | 操作指令，记忆使用规则 | 每个 session 开始 |
| `SOUL.md` | 人格、语气、边界 | 每个 session 开始 |
| `USER.md` | 用户信息、称呼 | 每个 session 开始 |
| `IDENTITY.md` | Agent 名字、emoji、风格 | Bootstrap 时 |
| `TOOLS.md` | 本地工具约定 (不控制工具可用性) | 每个 session 开始 |
| `HEARTBEAT.md` | Heartbeat 检查表 (保持精短) | 心跳 run |
| `BOOT.md` | Gateway 启动脚本 (需 hooks 启用) | Gateway 启动 |
| `BOOTSTRAP.md` | 首次运行仪式 (运行后删除) | 仅首次 |
| `MEMORY.md` | 长期记忆 (仅 main session 加载) | Main session 开始 |
| `memory/YYYY-MM-DD.md` | 每日记忆 (append-only) | 自动读 today + yesterday |

### Workspace 位置

```json5
{
  agent: {
    workspace: "~/.openclaw/workspace",
    skipBootstrap: true,  // 跳过自动创建引导文件
  },
}
```

- `OPENCLAW_PROFILE` ≠ "default" → `~/.openclaw/workspace-<profile>`
- 多 workspace 目录 → `openclaw doctor` 会警告
- 建议: 仅保留一个活跃 workspace

### 目录结构

```
workspace/
├── AGENTS.md
├── SOUL.md
├── USER.md
├── IDENTITY.md
├── TOOLS.md
├── HEARTBEAT.md
├── BOOT.md
├── MEMORY.md
├── memory/
│   ├── 2026-01-15.md
│   └── 2026-01-16-vendor-pitch.md
├── hooks/           # per-agent hooks
└── .openclaw/
    └── extensions/  # per-workspace plugins
```

### Git 备份策略

推荐对 workspace 做 Git 管理:

```bash
cd ~/.openclaw/workspace
git init
echo "*.log" >> .gitignore
git add -A && git commit -m "init"
```

⚠️ 不要提交 `~/.openclaw/credentials/` 或 `sessions/`。

---

## Channels (消息渠道)

### 支持渠道

| 渠道 | 类型 | 特点 |
|------|------|------|
| **WhatsApp** | 内置 | Baileys, QR 配对, 最流行 |
| **Telegram** | 内置 | Bot API (grammY), 最快设置 |
| **Discord** | 内置 | Bot + Gateway, servers/channels/DMs |
| **Signal** | 内置 | signal-cli, 隐私导向 |
| **Slack** | 内置 | Bolt SDK, workspace apps |
| **IRC** | 内置 | 经典 IRC |
| **Google Chat** | 内置 | HTTP webhook |
| **BlueBubbles** | 内置 | ✅ 推荐 iMessage 方案 |
| **iMessage (legacy)** | 内置 | ⚠️ 已弃用 |
| **Feishu/Lark** | Plugin | WebSocket bot |
| **Mattermost** | Plugin | Bot API + WebSocket |
| **MS Teams** | Plugin | `@openclaw/msteams` (2026.1.15 起 plugin-only) |
| **LINE** | Plugin | LINE Messaging API |
| **Matrix** | Plugin | Matrix 协议 |
| **Nostr** | Plugin | NIP-04 去中心化 DM |
| **Tlon** | Plugin | Urbit messenger |
| **Twitch** | Plugin | IRC 连接 |
| **Synology Chat** | Plugin | Webhook |
| **Nextcloud Talk** | Plugin | Self-hosted |
| **Zalo / Zalo Personal** | Plugin | 越南流行 |
| **WebChat** | 内置 | Gateway WebSocket UI |

### 多渠道并行

渠道可同时运行。配置多个后 OpenClaw 按聊天自动路由。

### DM 策略 (dmPolicy)

| 策略 | 说明 |
|------|------|
| `pairing` | ✅ 默认推荐 — 新发送者需批准 |
| `allowlist` | 仅白名单内用户 |
| `open` | 任何人可 DM (⚠️ 不推荐) |
| `disabled` | 禁用 DM |

### 群组消息

```json5
{
  channels: {
    whatsapp: {
      groups: {
        "*": { requireMention: true },  // 需 @mention
      },
      dmPolicy: "pairing",
    },
  },
}
```

### 配对

```bash
openclaw channels pair       # 开始配对
openclaw channels pair list  # 查看待配对
openclaw channels pair approve <id>
```

---

## Discovery (发现与传输)

### 发现方式

| 方式 | 范围 | 说明 |
|------|------|------|
| **Bonjour / mDNS** | LAN | 自动发现 Gateway，best-effort |
| **Tailnet** | 跨网络 | MagicDNS 名称或稳定 IP |
| **SSH** | 任意网络 | 通用 fallback |
| **手动** | 任意 | 手动配置端点 |

### Bonjour 服务信标

```
服务类型: _openclaw-gw._tcp
TXT keys:
  role=gateway
  lanHost=<hostname>.local
  sshPort=22
  gatewayPort=18789
  gatewayTls=1
  gatewayTlsSha256=<sha256>
  canvasPort=<port>
  tailnetDns=<magicdns>
  cliPath=<path>
```

### 传输选择策略

```
1. 已配对 direct endpoint 可达 → 使用
2. Bonjour 找到 LAN gateway → 提示选择并存储
3. 配置了 tailnet DNS/IP → 尝试 direct
4. 以上都不行 → SSH fallback
```

### 安全要点

- Bonjour TXT = **未认证** → 仅作 UX 提示
- 路由优先使用 SRV + A/AAAA 解析结果
- TLS pinning 不允许被广告的 fingerprint 覆盖
- iOS/Android 首次连接需 TLS + 确认 fingerprint

### 禁用/覆盖

```bash
OPENCLAW_DISABLE_BONJOUR=1   # 关闭 Bonjour 广播
OPENCLAW_SSH_PORT=22          # 覆盖 SSH 端口
OPENCLAW_TAILNET_DNS=xxx      # 发布 MagicDNS 提示
```

### 组件职责

| 组件 | 职责 |
|------|------|
| **Gateway** | 广播发现信标，拥有配对决策，托管 WS 端点 |
| **macOS App** | 帮助选择 Gateway，显示配对提示，SSH 作为 fallback |
| **iOS/Android** | 浏览 Bonjour 并连接已配对 Gateway WS |
