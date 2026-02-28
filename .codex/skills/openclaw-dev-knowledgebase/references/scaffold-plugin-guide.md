# Plugin 创建指南

交互式创建新 OpenClaw Plugin (extension)，包含 manifest、TypeScript entry point 和组件注册。

## 需求收集

1. **Plugin 名称** — kebab-case (例: `voice-assistant`, `slack-channel`)
2. **Plugin 用途** — 添加什么能力？
3. **注册组件** — Tool / Channel / Provider / Hook / CLI command / Service
4. **Author** — 名称 (可选)

## 创建目录和 Manifest

```bash
PLUGIN_NAME="<plugin-name>"
mkdir -p "$PLUGIN_NAME/src"
```

**openclaw.plugin.json**:
```json
{
  "name": "<plugin-name>",
  "version": "0.1.0",
  "description": "<plugin-purpose>",
  "author": { "name": "<author-name>" },
  "entry": "./src/index.ts"
}
```

**package.json**:
```json
{
  "name": "<plugin-name>",
  "version": "0.1.0",
  "type": "module",
  "openclaw": { "extensions": ["."] },
  "devDependencies": { "typescript": "^5.0.0" }
}
```

## TypeScript Entry Point

**src/index.ts**:
```typescript
import type { PluginAPI } from "openclaw";

export default function activate(api: PluginAPI) {
  // Tool
  api.registerTool("my-tool", {
    description: "Description of what this tool does",
    parameters: {
      input: { type: "string", description: "Input parameter" },
    },
    async execute({ input }) {
      return { result: `Processed: ${input}` };
    },
  });

  // Channel:  api.registerChannel("my-channel", { ... });
  // Hook:     api.registerHook("onSessionStart", async (ctx) => { ... });
  // CLI:      api.registerCLI("my-cmd", { ... });
  // Service:  api.registerService("my-service", { ... });
}
```

**tsconfig.json**:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/**/*.ts"]
}
```

## 安装 Plugin

```bash
# 链接到扩展目录
ln -s "$(pwd)/$PLUGIN_NAME" ~/.openclaw/extensions/$PLUGIN_NAME

# 重启 Gateway
pkill -TERM openclaw-gateway
sleep 3
openclaw health
openclaw plugins list
```

## 验证

```bash
openclaw plugins list | grep "$PLUGIN_NAME"
openclaw gateway call --method "tools.list" 2>/dev/null | grep "my-tool"
```

## 完成报告

```
Plugin created: <plugin-name>
  Location:  ./<plugin-name>/
  Manifest:  openclaw.plugin.json
  Entry:     src/index.ts
  Components:
    ✓ openclaw.plugin.json (manifest)
    ✓ src/index.ts (entry point)
    ✓ package.json
    ✓ tsconfig.json
  Registered:
    <tool|channel|hook|cli|service>: <name>
```
