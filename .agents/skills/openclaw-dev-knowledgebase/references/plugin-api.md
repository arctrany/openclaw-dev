
# OpenClaw Plugin Architecture

## 概念

OpenClaw plugin = **TypeScript 模块**，在 Gateway 进程内通过 jiti 加载。插件可注册工具、渠道、Provider 认证、Gateway RPC、CLI 命令、后台服务、Hooks 和自动回复命令。

⚠️ Plugins 运行在 Gateway 进程内 — 视为可信代码。

## Plugin 目录结构

```
my-plugin/
├── openclaw.plugin.json    # Required: Plugin manifest
├── index.ts                # Required: Plugin entry point
├── package.json            # Required for npm distribution
├── skills/                 # Optional: bundled skills
│   └── my-skill/
│       └── SKILL.md
└── src/                    # Optional: source modules
```

**关键规则**:
1. Manifest 必须是 `openclaw.plugin.json`（不是 `.claude-plugin/plugin.json`）
2. Entry point 是 TypeScript（jiti 运行时加载）
3. 使用 kebab-case 命名

## Plugin Manifest (openclaw.plugin.json)

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "description": "What this plugin does",
  "configSchema": {
    "type": "object",
    "properties": {
      "apiKey": { "type": "string" },
      "region": { "type": "string" }
    }
  },
  "uiHints": {
    "apiKey": { "label": "API Key", "sensitive": true },
    "region": { "label": "Region", "placeholder": "us-east-1" }
  }
}
```

## Entry Point

两种导出格式：

### 函数式（推荐）

```typescript
export default function register(api) {
  // 注册工具、渠道、hooks 等
  api.registerTool({ name: "my_tool", ... });
}
```

### 对象式

```typescript
export default {
  id: "my-plugin",
  name: "My Plugin",
  configSchema: { ... },
  register(api) {
    // 注册逻辑
  }
};
```

## Plugin API 能力

### 注册 Agent 工具

```typescript
export default function(api) {
  api.registerTool({
    name: "my_tool",
    description: "Does something useful",
    parameters: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" }
      },
      required: ["query"]
    },
    handler: async ({ query }) => {
      const result = await doSomething(query);
      return { content: result };
    }
  });
}
```

### 注册 Channel

```typescript
const myChannel = {
  id: "acmechat",
  meta: {
    id: "acmechat",
    label: "AcmeChat",
    selectionLabel: "AcmeChat (API)",
    docsPath: "/channels/acmechat",
    blurb: "AcmeChat messaging channel.",
    aliases: ["acme"],
  },
  capabilities: { chatTypes: ["direct"] },
  config: {
    listAccountIds: (cfg) =>
      Object.keys(cfg.channels?.acmechat?.accounts ?? {}),
    resolveAccount: (cfg, accountId) =>
      cfg.channels?.acmechat?.accounts?.[accountId ?? "default"],
  },
  outbound: {
    deliveryMode: "direct",
    sendText: async ({ text }) => ({ ok: true }),
  },
};

export default function(api) {
  api.registerChannel({ plugin: myChannel });
}
```

Channel 配置放在 `channels.<id>` 下（不是 `plugins.entries`）:

```json5
{
  channels: {
    acmechat: {
      accounts: {
        default: { token: "ACME_TOKEN", enabled: true },
      },
    },
  },
}
```

### 注册 Provider Auth

```typescript
export default function(api) {
  api.registerProvider({
    id: "acme",
    label: "AcmeAI",
    auth: [{
      id: "oauth",
      label: "OAuth",
      kind: "oauth",
      run: async (ctx) => ({
        profiles: [{
          profileId: "acme:default",
          credential: {
            type: "oauth", provider: "acme",
            access: "...", refresh: "...",
            expires: Date.now() + 3600 * 1000,
          },
        }],
        defaultModel: "acme/opus-1",
      }),
    }],
  });
}
```

### 注册 Gateway RPC

```typescript
export default function(api) {
  api.registerGatewayMethod("myplugin.status", ({ respond }) => {
    respond(true, { ok: true, version: "1.0.0" });
  });
}
```

### 注册 CLI 命令

```typescript
export default function(api) {
  api.registerCli(({ program }) => {
    program.command("mycmd")
      .description("Does something")
      .action(() => console.log("Hello"));
  }, { commands: ["mycmd"] });
}
```

### 注册 Hooks

```typescript
export default function(api) {
  api.registerHook("command:new", async (event) => {
    console.log(`[my-plugin] Session reset: ${event.sessionKey}`);
  }, {
    name: "my-plugin.session-reset",
    description: "Logs session resets",
  });
}
```

可用事件: `command:new`, `command:reset`, `command:stop`, `agent:bootstrap`, `gateway:startup`, `message:received`, `message:sent`

### 注册自动回复命令

```typescript
export default function(api) {
  api.registerCommand({
    name: "mystatus",
    description: "Show plugin status",
    acceptsArgs: false,
    requireAuth: true,
    handler: (ctx) => ({
      text: `Plugin running! Channel: ${ctx.channel}`,
    }),
  });
}
```

### 注册后台服务

```typescript
export default function(api) {
  api.registerService({
    id: "my-poller",
    start: () => api.logger.info("Poller started"),
    stop: () => api.logger.info("Poller stopped"),
  });
}
```

### Runtime Helpers

```typescript
// TTS for telephony
const result = await api.runtime.tts.textToSpeechTelephony({
  text: "Hello from OpenClaw",
  cfg: api.config,
});
```

## Plugin 发现与优先级

1. `plugins.load.paths` — 配置路径（最高）
2. `<workspace>/.openclaw/extensions/` — workspace 级
3. `~/.openclaw/extensions/` — 全局用户级
4. `<openclaw>/extensions/` — 内置（默认禁用）

同 ID 冲突时，按上述顺序取胜者。

## Package Packs

一个 npm 包可含多个 plugin:

```json
{
  "name": "@acme/my-plugins",
  "openclaw": {
    "extensions": ["./src/safety.ts", "./src/tools.ts"]
  }
}
```

## Plugin Slots (独占类别)

某些类别一次只能有一个 plugin 活跃:

```json5
{
  plugins: {
    slots: {
      memory: "memory-core",  // 或 "memory-lancedb" 或 "none"
    },
  },
}
```

## 配置

```json5
{
  plugins: {
    enabled: true,
    allow: ["voice-call"],     // 白名单 (可选)
    deny: ["untrusted"],       // 黑名单 (deny wins)
    load: { paths: ["~/dev/my-extension"] },
    entries: {
      "voice-call": {
        enabled: true,
        config: { provider: "twilio" },
      },
    },
  },
}
```

## 管理命令

```bash
openclaw plugins list                          # 列出所有 plugins
openclaw plugins info <id>                     # 详情
openclaw plugins install @openclaw/voice-call  # 从 npm 安装
openclaw plugins install ./my-plugin           # 从本地安装
openclaw plugins install -l ./my-plugin        # 链接 (开发模式)
openclaw plugins update <id>                   # 更新
openclaw plugins update --all                  # 全部更新
openclaw plugins enable <id>                   # 启用
openclaw plugins disable <id>                  # 禁用
openclaw plugins doctor                        # 诊断
```

## 安全

- `npm install --ignore-scripts` — 无 postinstall 执行
- 路径逃逸检测（symlink 检查）
- world-writable 路径被阻止
- `plugins.allow` 白名单推荐
- 非 bundled plugin 无 provenance 时会警告

## 开发工作流

```bash
# 1. 创建目录
mkdir my-plugin && cd my-plugin

# 2. 初始化
cat > openclaw.plugin.json << 'EOF'
{"id": "my-plugin", "name": "My Plugin"}
EOF

cat > index.ts << 'EOF'
export default function(api) {
  api.registerTool({ name: "my_tool", ... });
}
EOF

# 3. 开发模式 (链接安装)
openclaw plugins install -l .

# 4. 重启 Gateway 测试
pkill -TERM openclaw-gateway

# 5. 检查加载
openclaw plugins list
openclaw plugins info my-plugin
```

## npm 发布

```json
{
  "name": "@myorg/my-plugin",
  "version": "1.0.0",
  "openclaw": {
    "extensions": ["./index.ts"]
  }
}
```

- Entry 可以是 `.ts` 或 `.js`
- Scoped packages 自动 normalize ID (`@myorg/foo` → `foo`)
- `openclaw plugins install @myorg/my-plugin` 从 npm registry 安装

## 官方插件参考

| 插件 | npm | 类型 |
|------|-----|------|
| Voice Call | `@openclaw/voice-call` | Tool |
| MS Teams | `@openclaw/msteams` | Channel |
| Matrix | `@openclaw/matrix` | Channel |
| Nostr | `@openclaw/nostr` | Channel |
| LINE | `@openclaw/line` | Channel |
| Feishu | `@openclaw/feishu` | Channel |
| Mattermost | `@openclaw/mattermost` | Channel |
| Memory (Core) | 内置 | Slot: memory |
| Memory (LanceDB) | 内置 | Slot: memory |

## Additional Resources

- **`references/examples-and-troubleshooting.md`** — Plugin 开发模式、Channel onboarding hooks、Provider auth 集成、故障排查
