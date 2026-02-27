---
name: openclaw-dev-knowledgebase
description: "Use this skill when the user asks about OpenClaw architecture, development setup, debugging, configuration, Gateway troubleshooting, session logs, channel setup, building from source, testing, releasing, macOS app, CLI commands, memory search, cron jobs, heartbeat, hooks, webhooks, browser automation, tool policy, sandboxing, security audit, workspace bootstrap files, node pairing, discovery, networking, plugin development, openclaw.plugin.json, api.register* API, agent configuration, agents.list[], bindings, multi-agent routing, workspace isolation, SOUL.md/AGENTS.md persona files, install OpenClaw on macOS/Linux/Windows, or any OpenClaw internals question."
metadata: {"clawdbot":{"always":false,"emoji":"📚"}}
user-invocable: true
version: 3.0.0
---

# OpenClaw Dev Knowledgebase

OpenClaw 全面知识库 — 功能/架构/开发/部署/运维 + plugin API + agent 配置。

## 知识索引

### 核心概念

| 主题 | 参考文件 |
|------|---------|
| Node / Workspace / Agent / Model | `references/core-concepts.md` |
| Sessions / Memory / Automation / Security | `references/sessions-memory-automation-security.md` |
| Hooks / Webhooks / Heartbeat | `references/hooks-webhooks-heartbeat.md` |
| Tools / Browser / Plugins | `references/tools-browser-plugins.md` |
| Workspace / Channels / Discovery | `references/workspace-channels-discovery.md` |

### 开发指南

| 主题 | 参考文件 |
|------|---------|
| **Plugin API** (openclaw.plugin.json, api.register*) | `references/plugin-api.md` |
| Plugin 示例和故障排除 | `references/plugin-examples.md` |
| **Agent 配置** (agents.list[], bindings, security) | `references/agent-config.md` |
| System Prompt 示例 (SOUL.md, AGENTS.md, USER.md) | `references/system-prompt-examples.md` |

### 运维参考

| 主题 | 参考文件 |
|------|---------|
| 安装和调试 (macOS/Linux/Windows) | `references/install-and-debug.md` |
| 多节点组网 (Tailscale, SSH, 远程 Node) | `references/multi-node-networking.md` |
| 网络模型 | `references/networking.md` |
| 操作手册 (Runbooks) | `references/runbooks.md` |

### 源码参考

| 主题 | 参考文件 |
|------|---------|
| 源码目录结构 | `references/source-code-map.md` |
| 扩展和技能 | `references/extensions-and-skills.md` |

## 核心架构

```
Gateway (控制面, 单进程)
├── Agents (多个, 各有独立 workspace/sessions)
├── Channels (WhatsApp, Telegram, Discord, iMessage...)
├── Plugins (TypeScript 扩展: tools/channels/providers)
├── Nodes (配对设备: exec/screen/canvas/camera)
└── Sessions (DM 隔离, 每次对话一个 session)
```

## 关键路径

| 路径 | 说明 |
|------|------|
| `~/.openclaw/openclaw.json` | 主配置 |
| `~/.openclaw/agents/<id>/sessions/` | Session 日志 |
| `~/.openclaw/workspace-<id>/` | Agent workspace |
| `~/.openclaw/extensions/` | 全局 plugin 目录 |

## 常用命令

```bash
# 状态
openclaw health
openclaw status --deep --all
openclaw doctor

# Agents
openclaw agents list --bindings
jq '.agents.list[] | {id, model, workspace}' ~/.openclaw/openclaw.json

# Channels
openclaw channels status --probe

# Plugins
openclaw plugins list

# Gateway 管理
openclaw gateway install
openclaw gateway start | stop | restart
```

## 安装

| 平台 | 命令 |
|------|------|
| macOS / Linux | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Windows (WSL2) | `iwr -useb https://openclaw.ai/install.ps1 \| iex` |
| 无 root | `curl -fsSL https://openclaw.ai/install-cli.sh \| bash` |

## Plugin 开发快速入门

```bash
# 1. 创建目录 + manifest
mkdir my-plugin && cd my-plugin
cat > openclaw.plugin.json << 'EOF'
{"name":"my-plugin","version":"0.1.0","entry":"./src/index.ts"}
EOF

# 2. TypeScript entry
mkdir src && cat > src/index.ts << 'EOF'
export default function activate(api) {
  api.registerTool("my-tool", {
    description: "My tool",
    parameters: { input: { type: "string" } },
    async execute({ input }) { return { result: input }; },
  });
}
EOF

# 3. 安装
ln -s $(pwd) ~/.openclaw/extensions/my-plugin
pkill -TERM openclaw-gateway
```

## Agent 配置快速入门

```json5
// ~/.openclaw/openclaw.json → agents.list[]
{
  id: "my-agent",
  name: "My Agent",
  workspace: "~/.openclaw/workspace-my-agent",
  model: "anthropic/claude-sonnet-4-5",
  subagents: { allowAgents: ["worker-1"] },
}
```

Workspace 引导文件: `SOUL.md` (身份) / `AGENTS.md` (委派) / `USER.md` (用户偏好)

## Skill 解析顺序

```
Workspace skills  (最高优先)
  └── ~/.openclaw/workspace-<agent>/skills/
Managed skills    (中)
  └── ~/.openclaw/skills/ (shared)
Bundled skills    (最低)
  └── 内置于 OpenClaw
```
