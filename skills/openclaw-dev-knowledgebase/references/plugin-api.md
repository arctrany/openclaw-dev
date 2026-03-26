# OpenClaw Plugin Architecture

> 基准版本：对齐 2026-03-26 可公开访问的最新 OpenClaw 文档（`/plugins/manifest`、`/plugins/building-plugins`、`/plugins/bundles`、`/cli/plugins`、`/tools/plugin`）。

## 先分清两类对象

OpenClaw 当前支持两类可安装对象：

1. **native OpenClaw plugin**
   - 运行在 Gateway 进程内
   - 使用 `openclaw.plugin.json`
   - 通过 `package.json` 的 `openclaw.extensions` 声明入口
   - 可以注册工具、渠道、Provider、Hooks、HTTP route、Service、Context engine 等完整能力

2. **compatible bundle**
   - 来自 Claude / Codex / Cursor 生态
   - 安装后显示为 `Format: bundle`
   - OpenClaw 只映射受支持的内容（skills、部分 commands、支持的 hook packs、MCP 配置等）
   - 不是 native plugin，不应强制要求 `openclaw.plugin.json`

## 检测优先级

OpenClaw 按以下顺序识别目录：

1. `openclaw.plugin.json` 或有效 `package.json` + `openclaw.extensions` → 视为 native plugin
2. `.codex-plugin/`、`.claude-plugin/`、`.cursor-plugin/` 或默认 Claude/Cursor 布局 → 视为 compatible bundle

如果目录同时包含 native 和 bundle 标记，OpenClaw 优先走 native 路径。

## Native Plugin 目录结构

```text
my-plugin/
├── openclaw.plugin.json    # Required: native manifest
├── package.json            # Required: openclaw.extensions
├── index.ts                # Recommended entry in package root
├── skills/                 # Optional: bundled skills
│   └── my-skill/
│       └── SKILL.md
└── src/                    # Optional: helper modules
```

**关键规则**:
1. native plugin 必须有 `openclaw.plugin.json`
2. manifest 负责 discovery / config validation / auth metadata，不负责 entrypoint
3. entrypoint 写在 `package.json` 的 `openclaw.extensions`
4. `configSchema` 是必填字段，即使插件没有配置也要给空 schema
5. 入口文件通常放包根目录；`openclaw.extensions` 必须指向包内实际文件
6. OpenClaw 允许安装 compatible bundles，但 bundle 不是 native plugin

## Compatible Bundle 目录结构

### Claude bundle

```text
my-bundle/
├── .claude-plugin/
│   └── plugin.json         # Optional
├── skills/
├── commands/
├── agents/
├── hooks/
├── .mcp.json
└── settings.json
```

### Codex bundle

```text
my-bundle/
├── .codex-plugin/
│   └── plugin.json
├── skills/
├── hooks/
├── .mcp.json
└── .app.json
```

### Cursor bundle

```text
my-bundle/
├── .cursor-plugin/
│   └── plugin.json
├── skills/
├── .cursor/commands/
├── .cursor/agents/
├── .cursor/rules/
└── .mcp.json
```

## Plugin Manifest (`openclaw.plugin.json`)

### 最小示例

```json
{
  "id": "voice-call",
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {}
  }
}
```

### 完整示例

```json
{
  "id": "openrouter",
  "name": "OpenRouter",
  "description": "OpenRouter provider plugin",
  "version": "1.0.0",
  "providers": ["openrouter"],
  "providerAuthEnvVars": {
    "openrouter": ["OPENROUTER_API_KEY"]
  },
  "providerAuthChoices": [
    {
      "provider": "openrouter",
      "method": "api-key",
      "choiceId": "openrouter-api-key",
      "choiceLabel": "OpenRouter API key",
      "groupId": "openrouter",
      "groupLabel": "OpenRouter",
      "optionKey": "openrouterApiKey",
      "cliFlag": "--openrouter-api-key",
      "cliOption": "--openrouter-api-key <key>",
      "cliDescription": "OpenRouter API key",
      "onboardingScopes": ["text-inference"]
    }
  ],
  "uiHints": {
    "apiKey": {
      "label": "API key",
      "placeholder": "sk-or-v1-...",
      "sensitive": true
    }
  },
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {
      "apiKey": {
        "type": "string"
      }
    }
  }
}
```

### 顶层字段速查

| 字段 | 必填 | 说明 |
|------|------|------|
| `id` | 是 | Canonical plugin id |
| `configSchema` | 是 | 插件配置的 inline JSON Schema |
| `enabledByDefault` | 否 | bundled plugin 是否默认启用 |
| `kind` | 否 | 独占类别，如 `memory` / `context-engine` |
| `channels` | 否 | 该插件声明的 channel ids |
| `providers` | 否 | 该插件声明的 provider ids |
| `providerAuthEnvVars` | 否 | provider auth 的 cheap env metadata |
| `providerAuthChoices` | 否 | onboarding / CLI auth 选择元数据 |
| `skills` | 否 | 相对 plugin root 的 skill 目录 |
| `name` | 否 | 可读名称 |
| `description` | 否 | 简短说明 |
| `version` | 否 | 信息性版本号 |
| `uiHints` | 否 | 配置字段的 UI label / placeholder / sensitivity hints |

### 与旧说法冲突的点

- `version` 在 manifest 中是**合法可选字段**
- `uiHints` 在 manifest 中是**合法可选字段**
- manifest **不再声明 entrypoint**
- `configSchema` **必须存在**，即使为空
- `required` 不是被框架禁止的字段；它只是会参与配置校验，所以要按你的真实配置策略设计

## `package.json`

```json
{
  "name": "@myorg/openclaw-my-plugin",
  "version": "1.0.0",
  "type": "module",
  "openclaw": {
    "extensions": ["./index.ts"]
  }
}
```

### 关键规则

- `openclaw.extensions` 必须指向包内具体文件，不能写成目录
- 一个包可以暴露多个 extensions
- `package.json` 的 `name` 不必与 manifest `id` 完全相同
- 运行时身份以 manifest / entry export 的 plugin id 为准；安装后用 `openclaw plugins inspect <id>` 校验最终识别结果

## Entry Point

### 推荐写法：`definePluginEntry`

```typescript
import { Type } from "@sinclair/typebox";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  id: "my-plugin",
  name: "My Plugin",
  description: "Adds a custom tool to OpenClaw",
  register(api) {
    api.registerTool({
      name: "my_tool",
      description: "Do a thing",
      parameters: Type.Object({
        input: Type.String()
      }),
      async execute(_toolCallId, params) {
        return {
          content: [{ type: "text", text: `Got: ${params.input}` }]
        };
      },
    });
  },
});
```

### 兼容写法

```typescript
export default function register(api) {
  api.registerTool({ name: "my_tool", description: "..." });
}
```

或：

```typescript
export default {
  id: "my-plugin",
  name: "My Plugin",
  register(api) {
    api.registerTool({ name: "my_tool", description: "..." });
  },
};
```

## Plugin API 能力

```typescript
api.registerProvider({ /* 模型 Provider */ });
api.registerChannel({ plugin: myChannelPlugin });
api.registerTool({ /* Agent tool */ });
api.registerHook("command:new", handler, { name: "..." });
api.registerSpeechProvider({ /* TTS / STT */ });
api.registerMediaUnderstandingProvider({ /* 图像/音频分析 */ });
api.registerImageGenerationProvider({ /* 生图 */ });
api.registerWebSearchProvider({ /* Web search */ });
api.registerHttpRoute({ /* HTTP endpoint */ });
api.registerCommand({ /* 自动回复命令 */ });
api.registerCli(({ program }) => { /* CLI */ });
api.registerContextEngine({ /* Context engine */ });
api.registerService({ /* 后台服务 */ });
```

## 发现与优先级

默认发现顺序：

1. `plugins.load.paths`
2. `<workspace>/.openclaw/extensions/`
3. `~/.openclaw/extensions/`
4. `<openclaw>/extensions/`

同 ID 冲突时，按上述顺序取胜。

## 配置

```json5
{
  plugins: {
    enabled: true,
    allow: ["voice-call"],
    deny: ["untrusted"],
    load: { paths: ["~/dev/my-extension"] },
    entries: {
      "voice-call": {
        enabled: true,
        config: { provider: "twilio" },
      },
    },
    slots: {
      memory: "memory-core",
      contextEngine: "legacy",
    },
  },
}
```

## Compatible Bundles 当前映射能力

### 已支持

- bundle skill roots → OpenClaw skills
- Claude `commands/` / Cursor `.cursor/commands/` → skill content
- 符合 OpenClaw 预期的 Codex hook packs
- `.mcp.json` 中受支持的 stdio MCP 配置
- Claude `settings.json` 的部分默认值

### 仅检测，不执行

- Claude `agents`
- Claude / Cursor `hooks.json`
- Cursor `.cursor/agents`、`.cursor/rules`
- 其他未映射的 bundle metadata

## 管理命令

```bash
openclaw plugins list
openclaw plugins inspect <id>
openclaw plugins inspect <id> --json
openclaw plugins install @openclaw/voice-call
openclaw plugins install ./my-plugin
openclaw plugins install -l ./my-plugin
openclaw plugins install <plugin>@<marketplace>
openclaw plugins marketplace list <marketplace>
openclaw plugins update <id>
openclaw plugins update --all
openclaw plugins enable <id>
openclaw plugins disable <id>
openclaw plugins doctor
```

`info` 仍可用，但现在只是 `inspect` 的别名。

## 安全

- native plugins 在 Gateway 进程内运行，视为可信代码
- npm 安装默认使用 `--ignore-scripts`
- 插件安装与更新要按“执行代码”同等级别审查
- `plugins.allow` 建议保持显式白名单

## 开发工作流

```bash
# 1. 创建目录
mkdir my-plugin && cd my-plugin

# 2. 创建 manifest
cat > openclaw.plugin.json << 'EOF'
{
  "id": "my-plugin",
  "name": "My Plugin",
  "description": "What it does",
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {}
  }
}
EOF

# 3. 创建 package.json
cat > package.json << 'EOF'
{
  "name": "@myorg/openclaw-my-plugin",
  "version": "1.0.0",
  "type": "module",
  "openclaw": { "extensions": ["./index.ts"] }
}
EOF

# 4. 创建根目录入口
cat > index.ts << 'EOF'
import { Type } from "@sinclair/typebox";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  id: "my-plugin",
  name: "My Plugin",
  description: "What it does",
  register(api) {
    api.registerTool({
      name: "my_tool",
      description: "My tool",
      parameters: Type.Object({ query: Type.String() }),
      async execute(_toolCallId, params) {
        return { content: [{ type: "text", text: `Result: ${params.query}` }] };
      },
    });
  },
});
EOF

# 5. 链接安装并验证
openclaw plugins install -l .
openclaw plugins inspect my-plugin
```
