# openclaw-dev

**让你的 Code Agent 具备 OpenClaw 全栈开发能力。**

一个面向代码代理的 OpenClaw 开发工具包。默认以 Claude Code 插件形态使用，也可以作为 OpenClaw 可安装的 Claude-compatible bundle 使用。

## 快速安装

### Claude Code（推荐）

```bash
git clone https://github.com/arctrany/openclaw-dev.git
# 在 Claude Code 中启用插件（指向 clone 的目录）
```

插件自动注册，无需手动配置。

### OpenClaw

```bash
git clone https://github.com/arctrany/openclaw-dev.git
cd openclaw-dev
openclaw plugins install .
openclaw plugins inspect openclaw-dev
```

OpenClaw 会把本仓库识别为 Claude-compatible bundle。当前已可靠映射的是 `skills/`、`commands/` 等 bundle 能力；`agents/` 仍是 detect-only，不应当作 OpenClaw 原生 agent plugin。

### 其他平台（Codex / Qwen / Gemini）

```bash
cd openclaw-dev && bash install.sh
```

自动检测已安装的 agent 并分发到各平台的约定目录。Windows 上优先使用 `.\install.ps1`。

**更新（干净刷新）：**
- Unix-like: `cd openclaw-dev && git pull && bash install.sh`
- Windows PowerShell: `cd openclaw-dev; git pull; .\install.ps1`

> 安装器使用 **清单同步（Manifest Sync）** — 自动追踪已安装的 skills 和 commands。
> 当你删除某个 skill 后重新运行 `install.sh`，旧版本会从目标平台目录被**精准清理**，不留幽灵文件。
> 用户在目标目录下自建的 skill 不受影响。

## 安装后做什么？

在你的 code agent 里直接用自然语言或 `/命令`：

```
帮我安装 OpenClaw              → 自动执行安装、onboard、Gateway 配置
OpenClaw 架构原理              → 查阅架构文档和内部原理
创建一个 skill                 → 走完需求 → 设计 → 实现 → 验证 → 部署
```

## 使用场景

### 安装与部署

```
帮我在这台 Linux 服务器上安装 OpenClaw，配置 Gateway 和 Tailscale
```

跨平台安装（macOS / Linux / Windows WSL2），包含 onboard、Gateway 服务、组网。

### 诊断与修复

```
/diagnose
OpenClaw Gateway 频繁重启，帮我诊断
```

系统性日志分析 → 匹配已知故障模式 → 定位根因 → 给出修复步骤。每次诊断发现的新模式会自动沉淀，**越用越精准**。

### 状态查询

```
/status
/status home-mac
/status ALL
```

Gateway、Agents、Channels、Plugins 的统一状态视图。支持多 Gateway 并行查询。

### 配置检查

```
/lint-config
```

验证 `openclaw.json` 的语法、必要字段、安全设置、路径可达性。防止配置错误导致 Agent 挂掉。

### Skill 开发

```
帮我给 momiji agent 创建一个语音播报技能
/create-skill
/deploy-skill
/validate-skill
```

完整的 Skill 开发生命周期：需求 → 设计 → 实现 → 验证 → 部署。

### Skill 演化

```
/evolve-skill momiji voice-engine
```

分析 session 日志，找到 skill 的触发率、错误率、改进方向，数据驱动优化。

### Fleet 实时监控

```
/watch
/status ALL
```

持久化 tmux 分屏监控面板，实时查看远程节点状态。打开即常驻，所有远程操作可视化。

## 全部命令

| 命令 | 用途 |
|------|------|
| `/diagnose` | 运行时日志诊断 |
| `/status` | 状态总览（支持多 Gateway） |
| `/lint-config` | 配置校验 |
| `/setup-node` | 节点安装部署 |
| `/qa-agent` | QA 诊断与修复（`--fix` 启用修复循环） |
| `/evolve-skill` | 数据驱动 skill 演化 |
| `/create-skill` | 新建 skill |
| `/deploy-skill` | 部署 skill |
| `/validate-skill` | 验证 skill |
| `/list-skills` | 列出所有 skill |
| `/scaffold-agent` | 脚手架 agent |
| `/plugin` | Plugin 全生命周期管理（创建/安装/卸载/升级/启用/禁用/诊断） |
| `/watch` | Fleet 实时监控面板 |

## 跨 OS 支持

| 平台 | OpenClaw 安装 |
|------|-------------|
| macOS | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Linux | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Windows | WSL2 + `iwr -useb https://openclaw.ai/install.ps1 \| iex` |

## 本仓库的安装面

| 目标 | 推荐命令 |
|------|---------|
| Claude Code | clone 仓库并在 Claude Code 中启用 |
| OpenClaw | `openclaw plugins install .` |
| Windows 本地分发 | `.\install.ps1` |
| macOS / Linux / WSL 分发 | `bash install.sh` |

## 本地配置（可选）

复制 `openclaw-dev.local.md.example` 到 `.claude/openclaw-dev.local.md`，可自定义：

- 多 Gateway 连接信息（`gateways:` 配置）
- workspace 路径
- 部署目录

## 更新日志

### v2.2.0 (2026-03-09)

**Install 重构 — 干净刷新语义（Manifest Sync）**：
- `install.sh` 改为清单驱动同步，每次安装后在目标目录写入 `.openclaw-dev.manifest`
- 再次运行时自动对比清单，精准删除已经从仓库移除的 skill / command（零幽灵文件）
- 用户自建 skill 不在清单范围，绝不误删
- 幂等性：无论运行多少次，目标目录状态始终与仓库完全一致

### v2.1.0 (2026-03-04)

**命令重构** — 更清晰的命名：

**Skill 优化**:
- `openclaw-node-operations`: 状态查询重写为分层执行（环境探测 → 正常/降级模式），弱模型也能快速完成
- 新增降级策略表 — openclaw CLI 不可用时自动回退到配置文件读取

**工具增强**:
- `skill-lint.sh` 新增过时命令引用检测

### v2.0.0

- 首次作为 Claude Code 插件发布
- 4 个正交 Skill + 13 个用户命令
- 跨平台分发（Codex / Qwen / Gemini）
- 闭环诊断（fault-patterns.md 自动沉淀）

## License

MIT
