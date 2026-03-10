---
name: plugin
description: "OpenClaw Plugin 全生命周期管理 — 创建、安装、卸载、升级、启用/禁用、诊断。支持远程 Gateway。"
argument-hint: "[gateway] <create|install|uninstall|update|enable|disable|info|doctor> [plugin-id|path]"
user-invocable: true
---

# /plugin — Plugin 生命周期管理

一个入口覆盖 Plugin 的完整生命周期，所有操作均封装 `openclaw plugins` 原生命令。

## 路由表

| 参数 | 执行路径 |
|------|---------|
| 无参数 | → 读取 plugin 状态，展示操作菜单 |
| `create [name]` | → 交互式创建新 Plugin |
| `install <path\|spec>` | → 安装 Plugin |
| `uninstall <id>` | → 卸载 Plugin |
| `update [id\|--all]` | → 升级 Plugin |
| `enable <id>` | → 启用 Plugin |
| `disable <id>` | → 禁用 Plugin |
| `info <id>` | → 查看 Plugin 详情 |
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

交互式创建新 Plugin。读取 `openclaw-dev-knowledgebase` skill 的 `references/scaffold-plugin-guide.md`，按步骤引导。

### 快速参考

1. 收集需求（plugin 名称、用途、组件类型）
2. 创建目录 + manifest (`openclaw.plugin.json`)
3. 生成 TypeScript entry point (`src/index.ts`)
4. 创建 `package.json` + `tsconfig.json`
5. 询问安装方式 → 调用 install action

### Fallback（reference 不可用时）

1. 收集 plugin 名称和用途
2. 创建目录结构：`mkdir -p <plugin-name>/src`
3. 创建 `openclaw.plugin.json`：
```json
{
  "name": "<plugin-name>",
  "version": "0.1.0",
  "description": "<描述>",
  "main": "src/index.ts"
}
```
4. 创建 `src/index.ts` 入口（使用 `api.register*` 注册组件）
5. 创建 `package.json` + `tsconfig.json`
6. 执行 install action 完成安装

---

## Action: install

安装 Plugin 到 Gateway。

### 安装源类型

| 源 | 命令 | 说明 |
|----|------|------|
| 本地路径 | `openclaw plugins install ./my-plugin` | 复制到 `~/.openclaw/plugins/` |
| 本地路径 (link) | `openclaw plugins install --link ./my-plugin` | 符号链接，适合开发调试 |
| npm 包 | `openclaw plugins install @org/plugin-name` | npm 安装 |
| npm 精确版本 | `openclaw plugins install @org/plugin-name --pin` | 锁定版本 |
| 归档文件 | `openclaw plugins install ./plugin.tgz` | 解压安装 |

### 执行流程

```
1. 执行 openclaw plugins install <path-or-spec> [--link] [--pin]
2. 检查输出是否成功
3. 若需要 → 提示用户添加到 plugins.allow 白名单
4. 执行 openclaw plugins list --json | grep <id> 确认加载
5. 若 plugin 未自动加载 → 提示 openclaw plugins enable <id>
```

### 远程安装

远程 Gateway 安装时，需先将 plugin 文件传到目标机器：

```bash
# 本地路径 → scp 到远程
scp -r <local-path> ${ssh_user}@${host}:<remote-path>
ssh ... "openclaw plugins install <remote-path>"

# npm 包 → 远程直接 install
ssh ... "openclaw plugins install <npm-spec>"
```

### 常见陷阱

- **避免 `/tmp`**：macOS 定期清理 `/tmp`，plugin 路径丢失会导致 CLI 配置校验失败。使用 `openclaw plugins install`（自动安装到 `~/.openclaw/plugins/`）或 `--link` 到持久目录。
- **allowlist**：`plugins.allow` 白名单未包含新 plugin 时，plugin 加载但标记为 disabled。安装后检查并提示。
- **provenance 警告**：`loaded without install/load-path provenance` 表示 plugin 未通过正式安装流程，可忽略但建议修正。

---

## Action: uninstall

卸载 Plugin。

### 执行流程

```
1. openclaw plugins info <id> 确认 plugin 存在及详情
2. 展示 plugin 信息，请求用户确认
3. openclaw plugins uninstall <id> [--force]
4. 验证卸载成功：openclaw plugins list --json
```

### 选项

| 选项 | 说明 |
|------|------|
| `--dry-run` | 预览卸载效果，不实际执行 |
| `--force` | 跳过确认提示 |
| `--keep-files` | 保留磁盘文件，仅移除配置 |

---

## Action: update

升级 Plugin（仅支持 npm 安装的 plugin）。

### 执行流程

```
1. openclaw plugins update <id> --dry-run  查看可用更新
2. 展示更新内容，请求确认
3. openclaw plugins update <id>  执行升级
4. openclaw plugins list --json  验证新版本
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

操作后自动执行 `openclaw plugins list --enabled` 确认状态变更。

---

## Action: info

查看 Plugin 详情。

```bash
openclaw plugins info <id>         # 人类可读
openclaw plugins info <id> --json  # JSON 格式
```

输出包含：名称、版本、来源、状态、注册的 tools/hooks/channels 列表。

---

## Action: doctor

诊断 Plugin 加载问题。

```bash
openclaw plugins doctor
```

检查项：路径有效性、manifest 格式、依赖完整性、allowlist 配置、加载错误。

---

## 无参数：智能菜单

当用户输入 `/plugin` 不带参数时：

1. 执行 `openclaw plugins list --json` 获取当前状态
2. 解析结果，提取 loaded/disabled/error 状态
3. 展示交互菜单：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Plugins (N loaded, M disabled, K errors)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✅ huginn       v1.0.0   8 tools
  ✅ postiz       v1.0.0   9 tools
  ⚪ acpx         v2026.3  disabled
  ❌ bad-plugin   v0.1.0   load error

操作：
  1. install    — 安装新 Plugin
  2. create     — 创建新 Plugin
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
  /plugin info <id>        — 查看详情
  /status <gw> plugins     — 查看 plugin 全局状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
