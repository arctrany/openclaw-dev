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

### 安装常见错误

| 错误信息 | 原因 | 修复 |
|---------|------|------|
| `extension entry escapes package directory` | `openclaw.extensions` 指向目录 `["."]` 或 entry 在 `src/` 子目录 | 改为 `["./index.ts"]`，入口文件移到根目录 |
| `plugin id mismatch` | `package.json` 的 `name` 与 `openclaw.plugin.json` 的 `id` 不一致 | 确保两者完全一致 |
| `package.json missing openclaw.extensions` | 缺少 `openclaw` 字段 | 添加 `"openclaw": {"extensions": ["./index.ts"]}` |
| `extracted package missing package.json` | 目录下没有 `package.json` | 创建包含 `name` + `openclaw.extensions` 的 package.json |
| `plugin manifest requires configSchema` | manifest 缺少 `configSchema` | 添加 `"configSchema": {"type": "object", "properties": {}}` |
| `must have required property 'xxx'` | `configSchema` 含 `required` 数组，但安装时 config 还未注入 | 移除 `configSchema.required`，config 通过 env vars 或 `openclaw.json` 后注入 |
| `plugin already exists` | 已有同 ID 的 plugin | 先 `rm -rf ~/.openclaw/extensions/<id>` 再重新安装 |
| `loaded without install/load-path provenance` | 警告（非阻塞），plugin 不在 `plugins.allow` 白名单中 | 将 plugin id 加入 `plugins.allow` 数组 |

### 安装工作流（验证过的正确流程）

```bash
# ❌ 错误方式: 直接 scp/cp 到 extensions/ — 不会注册，只是文件复制
scp -r plugin/ remote:~/.openclaw/extensions/my-plugin  # 不起作用!

# ✅ 正确方式: 使用 openclaw CLI 安装
openclaw plugins install -l /path/to/my-plugin           # 链接安装 (开发)
openclaw plugins install /path/to/my-plugin              # 复制安装 (生产)

# 安装后注入 config (如果 plugin 需要 API 配置)
# 方法 1: 手动编辑 openclaw.json
jq '.plugins.entries["my-plugin"].config = {"apiUrl": "..."}' \
  ~/.openclaw/openclaw.json > /tmp/oc.json && mv /tmp/oc.json ~/.openclaw/openclaw.json

# 方法 2: 通过环境变量 (在 openclaw.env 中设置)
echo 'MY_API_KEY=xxx' >> ~/.openclaw/openclaw.env
```

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
