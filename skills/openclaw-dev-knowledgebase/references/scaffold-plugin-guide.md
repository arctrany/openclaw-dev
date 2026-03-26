# Plugin 创建指南

交互式创建新 **native OpenClaw plugin**，包含 manifest、TypeScript entry point 和组件注册。

> 如果用户要接入的是现成 Claude / Codex / Cursor 插件，优先保留原 bundle 结构。最新 OpenClaw 能直接安装这些 bundle，不需要强制改造成 native plugin。

## 需求收集

1. **Plugin 名称** — kebab-case (例: `voice-assistant`, `slack-channel`)
2. **Plugin 用途** — 添加什么能力？
3. **注册组件** — Tool / Channel / Provider / Hook / CLI command / Service
4. **配置需求** — 是否需要 `configSchema` 字段（没有配置也必须给空 schema）

## 创建目录和 Manifest

```bash
PLUGIN_NAME="<plugin-name>"
mkdir -p "$PLUGIN_NAME"
```

**openclaw.plugin.json**:
```json
{
  "id": "<plugin-name>",
  "name": "<Plugin Name>",
  "description": "<plugin-purpose>",
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {}
  }
}
```

**package.json**:
```json
{
  "name": "@myorg/openclaw-<plugin-name>",
  "version": "0.1.0",
  "type": "module",
  "openclaw": { "extensions": ["./index.ts"] },
  "dependencies": {
    "@sinclair/typebox": "^0.34.38",
    "openclaw": "latest"
  }
}
```

## TypeScript Entry Point

**index.ts**:
```typescript
import { Type } from "@sinclair/typebox";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  id: "<plugin-name>",
  name: "<Plugin Name>",
  description: "<plugin-purpose>",
  register(api) {
    api.registerTool({
      name: "my_tool",
      description: "Description of what this tool does",
      parameters: Type.Object({
        input: Type.String({ description: "Input parameter" })
      }),
      async execute(_toolCallId, params) {
        return {
          content: [{ type: "text", text: `Processed: ${params.input}` }]
        };
      },
    });

    // Channel: api.registerChannel({ plugin: myChannelPlugin });
    // Hook: api.registerHook("command:new", async (ctx) => { ... });
    // CLI: api.registerCli(({ program }) => { ... });
    // Service: api.registerService({ id: "my-service", start() {}, stop() {} });
  },
});
```

## 安装 Plugin

```bash
# 开发模式链接安装
openclaw plugins install -l "./$PLUGIN_NAME"

# 检查识别结果
openclaw plugins inspect "<plugin-name>"
```

## 验证

```bash
openclaw plugins list | grep "$PLUGIN_NAME"
openclaw plugins inspect "$PLUGIN_NAME" --json
```

## 完成报告

```
Plugin created: <plugin-name>
  Location:  ./<plugin-name>/
  Manifest:  openclaw.plugin.json
  Entry:     index.ts
  Components:
    ✓ openclaw.plugin.json (manifest)
    ✓ index.ts (entry point)
    ✓ package.json
  Registered:
    <tool|channel|hook|cli|service>: <name>
```
