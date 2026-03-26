# OpenClaw Plugin 开发模式与故障排查

## Plugin 开发模式

### 最小工具插件

```typescript
import { Type } from "@sinclair/typebox";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

// openclaw.plugin.json 需要至少包含:
// { "id": "my-tool", "configSchema": { "type": "object", "additionalProperties": false, "properties": {} } }

export default definePluginEntry({
  id: "my-tool",
  name: "My Tool",
  description: "Translate text between languages",
  register(api) {
    api.registerTool({
      name: "translate",
      description: "Translate text between languages",
      parameters: Type.Object({
        text: Type.String({ description: "Text to translate" }),
        targetLang: Type.String({ description: "Target language code" }),
      }),
      async execute(_toolCallId, params) {
        const result = await callTranslateAPI(params.text, params.targetLang);
        return { content: [{ type: "text", text: result }] };
      },
    });
  },
});
```

### Channel Onboarding Hook 模式

```typescript
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  id: "mychannel",
  name: "MyChannel",
  description: "Channel integration",
  register(api) {
    api.registerChannel({ plugin: myChannelPlugin });

    api.registerHook("gateway:startup", async () => {
      const cfg = api.config;
      const accounts = cfg.channels?.mychannel?.accounts ?? {};
      for (const [id, account] of Object.entries(accounts)) {
        if (account.enabled !== false) {
          await initializeAccount(id, account);
        }
      }
    }, { name: "mychannel.startup", description: "Initialize channel accounts" });
  },
});
```

### 多功能插件 (Tool + Hook + CLI)

```typescript
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

export default definePluginEntry({
  id: "my-plugin",
  name: "My Plugin",
  description: "Tool + hook + cli example",
  register(api) {
    api.registerTool({ name: "my_tool", description: "..." });

    api.registerHook("command:new", async (event) => {
      api.logger.info(`Session reset: ${event.sessionKey}`);
    }, { name: "my-plugin.session-log" });

    api.registerCli(({ program }) => {
      program.command("mystatus")
        .description("Show plugin status")
        .action(() => console.log("OK"));
    }, { commands: ["mystatus"] });

    api.registerCommand({
      name: "ping",
      description: "Responds with pong",
      handler: () => ({ text: "pong" }),
    });
  },
});
```

---

## 故障排查

### Plugin 不加载

| 症状 | 原因 | 修复 |
|------|------|------|
| `plugins list` 看不到 | 路径不在发现范围 | 检查 `plugins.load.paths` 或使用 `openclaw plugins install` |
| 显示但 disabled | 默认禁用 / allowlist 未放行 | `openclaw plugins enable <id>` |
| 显示但有 error | 加载异常 | `openclaw plugins doctor`，查看 Gateway 日志 |
| 显示为 `Format: bundle` | 安装的是 Claude/Codex/Cursor bundle | 只验证受支持映射能力，不要按 native plugin 检查 |
| ID 冲突 | 多个同 ID plugin | 更高优先级路径取胜，检查发现顺序 |

### 安装常见错误

| 错误信息 | 原因 | 修复 |
|---------|------|------|
| `extension entry escapes package directory` | `openclaw.extensions` 指向目录或越出包目录 | 改为包内具体文件，如 `["./index.ts"]` |
| `plugin manifest requires configSchema` | manifest 缺少 `configSchema` | 添加空 schema 或真实 schema |
| `package.json missing openclaw.extensions` | 缺少 `openclaw` 字段 | 添加 `"openclaw": {"extensions": ["./index.ts"]}` |
| `extracted package missing package.json` | 目录下没有 `package.json` | 创建 `package.json` 并声明 `openclaw.extensions` |
| `plugin already exists` | 已有同 ID 的 plugin | 先卸载旧版本或清理旧安装记录 |
| `loaded without install/load-path provenance` | 非正式安装流程 | 用 `openclaw plugins install` 重新安装 |

### 安装工作流（验证过的正确流程）

```bash
# native plugin / compatible bundle 都用同一安装面
openclaw plugins install -l /path/to/my-plugin   # 开发模式
openclaw plugins install /path/to/my-plugin      # 复制安装

# 检查识别结果
openclaw plugins inspect my-plugin
openclaw plugins inspect my-plugin --json
```

### Entry Point 问题

```bash
# 检查 TypeScript 语法
npx tsc --noEmit index.ts

# 检查默认导出
node -e "import('./index.ts').then(m => console.log(typeof m.default))"
```

### 依赖问题

```bash
# OpenClaw 使用 --ignore-scripts
npm install --ignore-scripts
```

### Channel Plugin 调试

```bash
openclaw channels status --probe
jq '.channels.<id>' ~/.openclaw/openclaw.json
openclaw gateway --verbose
```

### 配置问题

```bash
jq '.plugins' ~/.openclaw/openclaw.json
jq '.plugins.slots' ~/.openclaw/openclaw.json
```
