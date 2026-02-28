# OpenClaw 工具系统 — Tools, Browser, Plugins

## 工具总览

### 工具配置层级

```
tools.profile (基线) → tools.byProvider (按 provider 缩窄) → tools.allow/deny (最终)
                                                             → agents.list[].tools (per-agent)
```

### 工具 Profiles

| Profile | 包含工具 |
|---------|---------|
| `minimal` | `session_status` |
| `coding` | `group:fs`, `group:runtime`, `group:sessions`, `group:memory`, `image` |
| `messaging` | `group:messaging`, `sessions_list/history/send`, `session_status` |
| `full` | 全部 |

### 工具组 (group:*)

| 组 | 展开 |
|----|------|
| `group:runtime` | `exec`, `bash`, `process` |
| `group:fs` | `read`, `write`, `edit`, `apply_patch` |
| `group:sessions` | `sessions_list/history/send/spawn`, `session_status` |
| `group:memory` | `memory_search`, `memory_get` |
| `group:web` | `web_search`, `web_fetch` |
| `group:ui` | `browser`, `canvas` |
| `group:automation` | `cron`, `gateway` |
| `group:messaging` | `message` |
| `group:nodes` | `nodes` |

### 核心工具清单

| 工具 | 说明 |
|------|------|
| `exec` | Shell 命令 (workspace cwd, yieldMs auto-bg, sandbox/gateway/node host) |
| `process` | 管理后台 exec sessions (poll/log/write/kill) |
| `read/write/edit/apply_patch` | 文件操作 |
| `web_search` | Brave Search API (需 BRAVE_API_KEY) |
| `web_fetch` | URL → markdown/text (maxChars cap) |
| `browser` | 管理浏览器 (下方详述) |
| `canvas` | Node Canvas (present/eval/snapshot/A2UI) |
| `nodes` | 发现/配对/通知/camera/screen/location |
| `message` | 跨渠道消息 (send/poll/react/pin/thread/search) |
| `cron` | Cron job CRUD + wake |
| `gateway` | 重启/更新/config (SIGUSR1 in-place restart) |
| `sessions_list/history/send/spawn` | Session 管理与子 agent |
| `session_status` | 当前 session 状态 |
| `agents_list` | 可委派 agent 列表 |
| `image` | 图片分析 (需 imageModel) |

### exec 安全

```json5
{
  tools: {
    exec: {
      security: "allowlist",  // deny | allowlist | full
      ask: "always",          // off | on-miss | always
    },
    elevated: { enabled: false },  // 绕过沙盒
  },
}
```

### 循环检测

```json5
{
  tools: {
    loopDetection: {
      enabled: true,
      warningThreshold: 10,
      criticalThreshold: 20,
      globalCircuitBreakerThreshold: 30,
    },
  },
}
```

---

## Browser (浏览器控制)

### Profile 类型

| Profile | 说明 |
|---------|------|
| `openclaw` | 隔离的 managed browser (CDP, Playwright) |
| `chrome` | 扩展 relay → 你的 Chrome tab |
| `remote` | 远程 CDP URL |

### 配置

```json5
{
  browser: {
    enabled: true,
    defaultProfile: "openclaw",
    executablePath: "/Applications/Brave Browser.app/.../Brave Browser",
    profiles: {
      openclaw: { cdpPort: 18800, color: "#FF4500" },
      work: { cdpPort: 18801, color: "#0066CC" },
      remote: { cdpUrl: "http://10.0.0.42:9222" },
    },
    ssrfPolicy: {
      dangerouslyAllowPrivateNetwork: true, // 默认 trusted-network
    },
  },
}
```

### Snapshot 两种模式

| 模式 | ref 格式 | 用法 |
|------|---------|------|
| AI snapshot (default) | `12` (数字) | `openclaw browser click 12` |
| Role snapshot (`--interactive`) | `e12` | `openclaw browser click e12` |

⚠️ Ref 在页面导航后失效，需重新 `snapshot`。

### 关键命令

```bash
# 基础
openclaw browser status / start / stop / tabs / open <url>

# 检查
openclaw browser snapshot [--interactive] [--labels]
openclaw browser screenshot [--full-page] [--ref 12]
openclaw browser console --level error
openclaw browser errors / requests

# 操作
openclaw browser click 12 / type 23 "hello" --submit / press Enter
openclaw browser navigate <url> / resize 1280 720
openclaw browser drag 10 11 / select 9 OptionA

# 状态
openclaw browser cookies / storage local get / set offline on
openclaw browser set device "iPhone 14" / set media dark
```

### 安全

- Browser 控制仅 loopback
- `evaluateEnabled: false` 关闭 JS 执行 (防提示注入)
- 远程 CDP URL 当作 secret 处理
- SSRF 保护: `dangerouslyAllowPrivateNetwork: false` + `hostnameAllowlist`

---

## Plugins (插件系统)

### 概念

Plugin = TypeScript 模块，Gateway 进程内加载 (jiti)。可注册:
- Gateway RPC 方法、HTTP handlers
- Agent 工具
- CLI 命令
- 后台服务
- Skills
- 自动回复命令 (无需 AI)
- Channel 插件、Provider 认证

### 发现顺序

1. `plugins.load.paths` (配置)
2. `<workspace>/.openclaw/extensions/` (workspace)
3. `~/.openclaw/extensions/` (全局)
4. `<openclaw>/extensions/` (内置, 默认禁用)

### manifest

每个 plugin 目录必须含 `openclaw.plugin.json`。

### 配置

```json5
{
  plugins: {
    enabled: true,
    allow: ["voice-call"],  // 白名单
    deny: ["untrusted"],    // 黑名单 (deny wins)
    load: { paths: ["~/Projects/my-extension"] },
    entries: {
      "voice-call": { enabled: true, config: { provider: "twilio" } },
    },
    slots: {
      memory: "memory-core",  // 独占类别
    },
  },
}
```

### 插件 API 能力

```typescript
// 注册工具
api.registerTool({ name: "my_tool", ... });

// 注册 Gateway RPC
api.registerGatewayMethod("myplugin.status", handler);

// 注册 CLI
api.registerCli(({ program }) => { program.command("mycmd")... });

// 注册 Channel
api.registerChannel({ plugin: myChannelPlugin });

// 注册 Provider Auth
api.registerProvider({ id: "acme", auth: [...] });

// 注册 Hook
api.registerHook("command:new", handler, { name: "...", description: "..." });

// 注册自动回复命令
api.registerCommand({ name: "mystatus", handler: (ctx) => ({ text: "..." }) });

// 注册后台服务
api.registerService({ id: "my-service", start: ..., stop: ... });
```

### 官方插件

| 插件 | 包名 | 类型 |
|------|------|------|
| Voice Call | `@openclaw/voice-call` | 工具 |
| MS Teams | `@openclaw/msteams` | Channel |
| Matrix | `@openclaw/matrix` | Channel |
| Nostr | `@openclaw/nostr` | Channel |
| Zalo | `@openclaw/zalo` | Channel |
| Zalo Personal | `@openclaw/zalouser` | Channel |
| Memory (Core) | 内置 | slot:memory |
| Memory (LanceDB) | 内置 | slot:memory |
| Google Antigravity OAuth | 内置 (禁用) | Provider |
| Copilot Proxy | 内置 (禁用) | Provider |

### 管理命令

```bash
openclaw plugins list
openclaw plugins info <id>
openclaw plugins install @openclaw/voice-call [--pin]
openclaw plugins update <id> | --all
openclaw plugins enable/disable <id>
openclaw plugins doctor
```

### 安全

- Plugins 运行在 Gateway 进程内 → **视为可信代码**
- 使用 `plugins.allow` 白名单
- `npm install --ignore-scripts` (无 postinstall)
- 路径逃逸检测 (symlink 检查)
- world-writable 路径被阻止
