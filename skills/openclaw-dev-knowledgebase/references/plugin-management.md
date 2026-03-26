# Plugin 运维管理指南

Plugin 生命周期的运维操作参考。开发/创建相关内容见 `plugin-api.md` 和 `scaffold-plugin-guide.md`。

## 安装

### 安装源与推荐场景

| 源 | 命令 | 场景 |
|----|------|------|
| 本地路径 | `openclaw plugins install ./my-plugin` | 安装 native plugin 或 compatible bundle |
| 本地链接 | `openclaw plugins install --link ./my-plugin` | 开发调试，代码修改即生效 |
| npm / ClawHub 包 | `openclaw plugins install @org/name` | 第三方/官方 plugin，先 ClawHub 再 npm |
| npm 精确版本 | `openclaw plugins install @org/name --pin` | 锁定版本，避免意外升级 |
| 归档文件 | `openclaw plugins install ./plugin.tgz` | 离线部署 |
| Marketplace | `openclaw plugins install <plugin>@<marketplace>` | Claude marketplace / 自定义 marketplace |

### OpenClaw 会自动识别的格式

- native OpenClaw plugins：`openclaw.plugin.json`
- Codex bundles：`.codex-plugin/plugin.json`
- Claude bundles：`.claude-plugin/plugin.json` 或默认 Claude 布局
- Cursor bundles：`.cursor-plugin/plugin.json`

### 安装后自动行为

- 文件安装到当前 state dir 的 `extensions/` 根（默认是 `~/.openclaw/extensions/`）
- 写入 `openclaw.json` 的 `plugins.installs` 记录
- 若 `plugins.allow` 存在且未包含该 plugin → 可能保持 disabled
- `openclaw plugins inspect <id>` 可查看 `Format: openclaw` 或 `Format: bundle`

### 常见安装问题

| 症状 | 原因 | 修复 |
|------|------|------|
| `plugin path not found` | 路径不存在（如 `/tmp` 被清理） | 重新 install 到持久路径 |
| `not in allowlist` | `plugins.allow` 白名单未包含 | `openclaw plugins enable <id>` |
| `loaded without install/load-path provenance` | 非正式安装流程 | 用 `openclaw plugins install` 重新安装 |
| `plugin manifest requires configSchema` | native manifest 缺少 `configSchema` | 添加空 schema 或真实 schema |
| `extension entry escapes package directory` | entry 越出包目录 | 将 entry 调整到包内具体文件 |
| 安装后显示 `Format: bundle` | 源目录是 Claude/Codex/Cursor bundle | 按 bundle 能力映射验证，不要要求 native manifest |

### 远程 Gateway 安装

```bash
# npm / ClawHub 包 — 远程直接安装
ssh user@host "openclaw plugins install @org/plugin-name"

# 本地文件 — 先传再装
scp -r ./my-plugin user@host:~/tmp/my-plugin
ssh user@host "openclaw plugins install ~/tmp/my-plugin"
```

> **避免 `/tmp` 持久依赖**：macOS 的 `/tmp` 会被系统周期性清理。开发时优先用 `--link` 指向持久目录，生产时用正式 install。

## 卸载

```bash
openclaw plugins uninstall <id>
openclaw plugins uninstall <id> --dry-run
openclaw plugins uninstall <id> --keep-files
```

卸载会：
1. 从 `plugins.installs` 移除安装记录
2. 从 `plugins.allow` 移除（如果存在）
3. 从 `plugins.entries` 移除配置
4. 删除安装文件（除非 `--keep-files`）
5. 对 active memory plugin，将 slot 回退到 `memory-core`

## 升级

```bash
openclaw plugins update <id>
openclaw plugins update <id> --dry-run
openclaw plugins update --all
openclaw plugins update @openclaw/voice-call@beta
```

- 升级依赖 `plugins.installs` 中的 tracked install
- 对 npm 安装，可传入显式 spec 覆盖后续更新来源
- 本地路径安装的 plugin 需手动更新文件

## 启用 / 禁用

```bash
openclaw plugins enable <id>
openclaw plugins disable <id>
```

启用/禁用后用以下命令确认：

```bash
openclaw plugins list
openclaw plugins inspect <id>
```

## 检查 / 诊断

```bash
openclaw plugins inspect <id>
openclaw plugins inspect <id> --json
openclaw plugins doctor
openclaw plugins marketplace list <marketplace>
```

`info` 仍可用，但只是 `inspect` 的别名。

## 配置结构速查

```json5
{
  plugins: {
    enabled: true,
    allow: ["huginn", "postiz"],
    deny: [],
    load: {
      paths: ["~/path/to/plugin"]
    },
    entries: {
      "huginn": {
        enabled: true,
        config: {
          huginnUrl: "http://host:3000"
        }
      }
    },
    installs: {
      "huginn": {
        source: "path",
        installPath: "~/.openclaw/extensions/huginn",
        version: "1.0.0",
        installedAt: "2026-03-10T08:51:44.289Z"
      }
    },
    slots: {
      memory: "memory-core",
      contextEngine: "legacy"
    }
  }
}
```

## 安全要点

- native plugin 运行在 Gateway 进程内，按“执行可信代码”对待
- npm install 自动使用 `--ignore-scripts`
- `plugins.allow` 建议始终显式配置
- 来自 bundle / marketplace 的插件也要按代码审查强度评估
