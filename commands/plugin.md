---
name: plugin
description: "OpenClaw Plugin 全生命周期管理 — 创建、安装、卸载、升级、启用/禁用、诊断。支持远程 Gateway。"
argument-hint: "[gateway] <create|install|uninstall|update|enable|disable|info|doctor> [plugin-id|path]"
user-invocable: true
---

# /plugin — Plugin 生命周期管理

一个入口覆盖 Plugin 的完整生命周期，所有操作均封装 `openclaw plugins` 原生命令。

最新 OpenClaw 有两类可安装对象：
- **native OpenClaw plugin**：`openclaw.plugin.json` + `package.json` + `openclaw.extensions`
- **compatible bundle**：Claude / Codex / Cursor 插件布局，安装后显示为 `Format: bundle`

`/plugin create` 默认创建 native plugin。对于现成 Claude/Codex/Cursor 插件，优先保留原 bundle 结构，不要强行改造为 native plugin。

## 路由表

| 参数 | 执行路径 |
|------|---------|
| 无参数 | → 读取 plugin 状态，展示操作菜单 |
| `create [name]` | → 交互式创建新 native Plugin |
| `install <path\|spec>` | → 安装 Plugin / bundle |
| `uninstall <id>` | → 卸载 Plugin |
| `update [id\|--all]` | → 升级 Plugin |
| `enable <id>` | → 启用 Plugin |
| `disable <id>` | → 禁用 Plugin |
| `info <id>` | → 查看 Plugin 详情（底层使用 `inspect`） |
| `doctor` | → 诊断 Plugin 加载问题 |
| `<gateway> <action> ...` | → 通过 SSH 在远程 Gateway 执行 |

---

## Gateway 选择

与 `/diagnose`、`/status` 共用同一套 gateway 路由逻辑。

读取 `.claude/openclaw-dev.local.md` 中的 `gateways:` 配置。

- **第一个参数匹配已知 gateway 名称** → SSH 到远程 Gateway 执行
- **否则** → 本地执行

SSH 命令模板：

```bash
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes -o ControlMaster=auto"
SSH_OPTS="$SSH_OPTS -o ControlPath=/tmp/oc-ssh-%r@%h:%p -o ControlPersist=300"
SSH_OPTS="$SSH_OPTS ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22}"
ssh $SSH_OPTS ${ssh_user}@${host} "<命令>"
```

---

## Action: create

交互式创建新 **native OpenClaw plugin**。读取 `openclaw-dev-knowledgebase` skill 的 `references/scaffold-plugin-guide.md`，按步骤引导。

### 快速参考

1. 收集需求（plugin 名称、用途、组件类型）
2. 创建目录 + manifest (`openclaw.plugin.json`，必须带 `configSchema`)
3. 生成根目录 TypeScript entry point (`index.ts`)
4. 创建 `package.json`（`openclaw.extensions` 指向具体入口文件）
5. 询问安装方式 → 调用 install action

### Fallback（reference 不可用时）

1. 收集 plugin 名称和用途
2. 创建目录结构：`mkdir -p <plugin-name>`
3. 创建 `openclaw.plugin.json`：
```json
{
  "id": "<plugin-name>",
  "name": "<Plugin Name>",
  "description": "<描述>",
  "configSchema": {
    "type": "object",
    "additionalProperties": false,
    "properties": {}
  }
}
```
4. 创建根目录 `index.ts` 入口（使用 `definePluginEntry` + `api.register*`）
5. 创建 `package.json`
6. 执行 install action 完成安装

---

## Action: install

安装 Plugin 到 Gateway。

### 安装源类型

| 源 | 命令 | 说明 |
|----|------|------|
| 本地路径（native 或 bundle） | `openclaw plugins install ./my-plugin` | 安装到当前 state dir 的 `extensions/` 根 |
| 本地路径 (link) | `openclaw plugins install --link ./my-plugin` | 符号链接，适合开发调试 |
| npm / ClawHub 包 | `openclaw plugins install @org/plugin-name` | 先查 ClawHub，再回退 npm |
| npm 精确版本 | `openclaw plugins install @org/plugin-name --pin` | 锁定版本 |
| 归档文件 | `openclaw plugins install ./plugin.tgz` | 解压安装 |
| Marketplace | `openclaw plugins install <plugin>@<marketplace>` | Claude marketplace / 自定义 marketplace |

OpenClaw 会自动识别：
- native OpenClaw plugin：`openclaw.plugin.json`
- Codex bundle：`.codex-plugin/plugin.json`
- Claude bundle：`.claude-plugin/plugin.json` 或默认 Claude 布局
- Cursor bundle：`.cursor-plugin/plugin.json`

### 执行流程

```
1. 执行 openclaw plugins install <path-or-spec> [--link] [--pin]
2. 检查输出是否成功
3. 执行 openclaw plugins inspect <id> --json 确认格式 / 来源 / capabilities
4. 若需要 → 提示用户添加到 plugins.allow 白名单或执行 enable
5. 对 bundle 安装，额外确认 `Format: bundle` 和 subtype (`codex` / `claude` / `cursor`)
```

### 远程安装

远程 Gateway 安装时，需先将 plugin 文件传到目标机器：

```bash
# 本地路径 → scp 到远程
scp -r <local-path> ${ssh_user}@${host}:<remote-path>
ssh ... "openclaw plugins install <remote-path>"

# npm / ClawHub 包 → 远程直接 install
ssh ... "openclaw plugins install <npm-spec>"
```

### 常见陷阱

- **避免 `/tmp`**：macOS 定期清理 `/tmp`，plugin 路径丢失会导致 CLI 配置校验失败。使用 `openclaw plugins install` 或 `--link` 到持久目录。
- **allowlist**：`plugins.allow` 白名单未包含新 plugin 时，plugin 加载但标记为 disabled。安装后检查并提示。
- **provenance 警告**：`loaded without install/load-path provenance` 表示 plugin 未通过正式安装流程，可忽略但建议修正。
- **bundle 不是 native plugin**：Claude / Codex / Cursor bundle 可以装进 OpenClaw，但只会映射受支持的能力；不要要求它们提供 `openclaw.plugin.json`。

---

## Action: uninstall

卸载 Plugin。

### 执行流程

```
1. openclaw plugins inspect <id> 确认 plugin 存在及详情
2. 展示 plugin 信息，请求用户确认
3. openclaw plugins uninstall <id> [--force]
4. 验证卸载成功：openclaw plugins list
```

### 选项

| 选项 | 说明 |
|------|------|
| `--dry-run` | 预览卸载效果，不实际执行 |
| `--force` | 跳过确认提示 |
| `--keep-files` | 保留磁盘文件，仅移除配置 |

---

## Action: update

升级 Plugin（通常针对 tracked install；npm / ClawHub 包最常见）。

### 执行流程

```
1. openclaw plugins update <id> --dry-run  查看可用更新
2. 展示更新内容，请求确认
3. openclaw plugins update <id>  执行升级
4. openclaw plugins inspect <id> --json  验证新版本 / 来源
```

### 批量升级

```bash
openclaw plugins update --all --dry-run   # 预览所有可升级 plugin
openclaw plugins update --all             # 执行全部升级
```

---

## Action: enable / disable

启用或禁用 Plugin。

```bash
openclaw plugins enable <id>    # 在 config 中启用
openclaw plugins disable <id>   # 在 config 中禁用
```

操作后自动执行 `openclaw plugins list` 或 `inspect` 确认状态变更。

---

## Action: info

查看 Plugin 详情。

```bash
openclaw plugins inspect <id>         # 人类可读
openclaw plugins inspect <id> --json  # JSON 格式
```

`info` 是 `inspect` 的别名。输出包含：名称、版本、来源、状态、格式（`openclaw` / `bundle`）、bundle subtype、注册的 tools/hooks/channels/services/commands 列表。

---

## Action: doctor

诊断 Plugin 加载问题。

```bash
openclaw plugins doctor
```

检查项：路径有效性、manifest / bundle 识别结果、依赖完整性、allowlist 配置、加载错误。

---

## 无参数：智能菜单

当用户输入 `/plugin` 不带参数时：

1. 执行 `openclaw plugins list` 获取当前状态
2. 解析结果，提取 loaded/disabled/error 状态与 `Format`
3. 展示交互菜单：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugins (N loaded, M disabled, K errors)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ huginn       v1.0.0   openclaw     8 tools
  ✅ openclaw-dev v2.2.0   bundle:claude
  ⚪ acpx         v2026.3  disabled
  ❌ bad-plugin   v0.1.0   load error

操作：
  1. install    — 安装新 Plugin
  2. create     — 创建新 native Plugin
  3. doctor     — 诊断加载问题
  4. 选择已有 plugin 查看详情/管理
```

有 error 状态的 plugin 时，优先建议 `doctor`。

---

## 输出格式

所有 action 完成后统一输出：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugin: <action> <id>   ✅ 成功
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  <action 具体结果>

下一步
  /plugin info <id>        — 查看详情（底层调用 inspect）
  /status <gw> plugins     — 查看 plugin 全局状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
