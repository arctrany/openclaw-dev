# OpenClaw Plugin 开发模式与故障排查

## Plugin 开发模式

### 最小工具插件

```typescript
// openclaw.plugin.json: { "id": "my-tool", "name": "My Tool" }
// index.ts:
export default function(api) {
  api.registerTool({
    name: "translate",
    description: "Translate text between languages",
    parameters: {
      type: "object",
      properties: {
        text: { type: "string", description: "Text to translate" },
        targetLang: { type: "string", description: "Target language code" },
      },
      required: ["text", "targetLang"],
    },
    handler: async ({ text, targetLang }) => {
      const result = await callTranslateAPI(text, targetLang);
      return { content: result };
    },
  });
};
```

### Channel Onboarding Hook 模式

```typescript
export default function(api) {
  api.registerChannel({ plugin: myChannelPlugin });

  // 在 Gateway 启动时执行初始化
  api.registerHook("gateway:startup", async () => {
    const cfg = api.config;
    const accounts = cfg.channels?.mychannel?.accounts ?? {};
    for (const [id, account] of Object.entries(accounts)) {
      if (account.enabled !== false) {
        await initializeAccount(id, account);
      }
    }
  }, { name: "mychannel.startup", description: "Initialize channel accounts" });
};
```

### 多功能插件 (Tool + Hook + CLI)

```typescript
export default function(api) {
  // 工具
  api.registerTool({ name: "my_tool", ... });

  // Hook
  api.registerHook("command:new", async (event) => {
    api.logger.info(`Session reset: ${event.sessionKey}`);
  }, { name: "my-plugin.session-log" });

  // CLI
  api.registerCli(({ program }) => {
    program.command("mystatus")
      .description("Show plugin status")
      .action(() => console.log("OK"));
  }, { commands: ["mystatus"] });

  // 自动回复命令
  api.registerCommand({
    name: "ping",
    description: "Responds with pong",
    handler: () => ({ text: "🏓 pong" }),
  });
};
```

---

## 故障排查

### Plugin 不加载

| 症状 | 原因 | 修复 |
|------|------|------|
| `plugins list` 看不到 | 路径不在发现范围 | 检查 `plugins.load.paths` 或安装到 `~/.openclaw/extensions/` |
| 显示但 disabled | 默认禁用 (内置 plugin) | `openclaw plugins enable <id>` |
| 显示但有 error | 加载异常 | `openclaw plugins doctor`，查看 Gateway 日志 |
| ID 冲突 | 多个同 ID plugin | 更高优先级路径取胜，检查发现顺序 |

### Entry Point 问题

```bash
# 检查 TypeScript 语法
npx tsc --noEmit index.ts

# 检查导出格式
node -e "const m = require('./index.ts'); console.log(typeof m.default)"
```

### 依赖问题

```bash
# OpenClaw 使用 --ignore-scripts
npm install --ignore-scripts

# 如果依赖需要 native build
# 需在 package.json 中声明 openclaw.requiresBuild: true
```

### Channel Plugin 调试

```bash
# 检查 channel 注册状态
openclaw channels status --probe

# 检查 channel 配置
jq '.channels.<id>' ~/.openclaw/openclaw.json

# Gateway verbose 日志
openclaw gateway --verbose
```

### 配置问题

```bash
# 检查 plugin 配置
jq '.plugins' ~/.openclaw/openclaw.json

# 检查 slots
jq '.plugins.slots' ~/.openclaw/openclaw.json
```
