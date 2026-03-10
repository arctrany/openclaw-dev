# Plugin 运维管理指南

Plugin 生命周期的运维操作参考。开发/创建相关内容见 `plugin-api.md` 和 `scaffold-plugin-guide.md`。

## 安装

### 安装源与推荐场景

| 源 | 命令 | 场景 |
|----|------|------|
| 本地路径 | `openclaw plugins install ./my-plugin` | 已完成开发，部署到生产 |
| 本地链接 | `openclaw plugins install --link ./my-plugin` | 开发调试，代码修改即生效 |
| npm 包 | `openclaw plugins install @org/name` | 第三方/官方 plugin |
| npm 精确版本 | `openclaw plugins install @org/name --pin` | 锁定版本，避免意外升级 |
| 归档文件 | `openclaw plugins install ./plugin.tgz` | 离线部署 |

### 安装后自动行为

- 文件复制到 `~/.openclaw/plugins/<id>/`（`--link` 时为符号链接）
- 写入 `openclaw.json` 的 `plugins.installs` 记录
- 若 `plugins.allow` 存在且未包含此 plugin → 不自动加载，需手动 enable
- Gateway 自动热加载（无需重启，除非 plugin 注册了 channel）

### 常见安装问题

| 症状 | 原因 | 修复 |
|------|------|------|
| `plugin path not found` | 路径不存在（如 `/tmp` 被清理） | 重新 install 到持久路径 |
| `not in allowlist` | `plugins.allow` 白名单未包含 | `openclaw plugins enable <id>` |
| `loaded without install/load-path provenance` | 非正式安装流程 | 用 `openclaw plugins install` 重新安装 |
| `plugin id mismatch` | `package.json` name 与 manifest id 不一致 | 统一两处 id |
| `extension entry escapes package directory` | 入口文件不在包根目录 | 将 `index.ts` 移到根目录 |

### 远程 Gateway 安装

```bash
# npm 包 — 远程直接安装
ssh user@host "openclaw plugins install @org/plugin-name"

# 本地文件 — 先传再装
scp -r ./my-plugin user@host:~/.openclaw/plugins/my-plugin
ssh user@host "openclaw plugins install ~/.openclaw/plugins/my-plugin"
```

> **避免 `/tmp`**：macOS 的 `/tmp`（实际 `/private/tmp`）会被系统周期性清理。plugin 路径失效后，CLI 配置校验会阻塞所有 `openclaw` 命令（包括 health/status），而 Gateway 进程本身可能仍正常运行。

## 卸载

```bash
openclaw plugins uninstall <id>              # 交互确认
openclaw plugins uninstall <id> --force      # 跳过确认
openclaw plugins uninstall <id> --dry-run    # 预览
openclaw plugins uninstall <id> --keep-files # 仅移除配置，保留文件
```

卸载会：
1. 从 `plugins.installs` 移除安装记录
2. 从 `plugins.allow` 移除（如果存在）
3. 从 `plugins.entries` 移除配置
4. 删除安装的文件（除非 `--keep-files`）

## 升级

仅支持通过 npm 安装的 plugin。

```bash
openclaw plugins update <id>          # 升级单个
openclaw plugins update <id> --dry-run # 预览
openclaw plugins update --all         # 全部升级
openclaw plugins update --all --dry-run
```

本地路径安装的 plugin 需手动更新文件后重启 Gateway。

## 启用 / 禁用

```bash
openclaw plugins enable <id>   # 添加到 plugins.allow + entries.enabled=true
openclaw plugins disable <id>  # 设置 entries.enabled=false
```

启用/禁用即时生效，Gateway 自动热加载。

## 诊断

```bash
openclaw plugins doctor
```

检查所有发现的 plugin 的：
- 路径有效性
- Manifest 完整性
- `package.json` 一致性
- 加载错误
- allowlist 状态

## 配置结构速查

```json5
{
  plugins: {
    enabled: true,
    allow: ["huginn", "postiz"],     // 白名单
    deny: [],                         // 黑名单（优先于 allow）
    load: {
      paths: ["/path/to/plugin"]     // 额外加载路径（不推荐，用 install 代替）
    },
    entries: {
      "huginn": {
        enabled: true,
        config: {                     // plugin-specific 配置
          huginnUrl: "http://host:3000",
          username: "admin",
          password: "${HUGINN_PASSWORD}"  // 支持环境变量引用
        }
      }
    },
    installs: {                       // install 命令自动写入
      "huginn": {
        source: "path",
        installPath: "~/.openclaw/plugins/huginn",
        version: "1.0.0",
        installedAt: "2026-03-10T08:51:44.289Z"
      }
    },
    slots: {                          // 独占类别
      memory: "memory-core"
    }
  }
}
```

## 安全要点

- `plugins.allow` 为显式信任白名单，建议始终配置
- 非 npm 安装的 plugin 会触发 provenance 警告，可安全忽略但建议通过 `openclaw plugins install` 正式安装
- Gateway bind 到非 loopback 地址时会警告，确保 `gateway.auth.token` 已配置
- npm install 自动使用 `--ignore-scripts`，阻止 postinstall 执行
