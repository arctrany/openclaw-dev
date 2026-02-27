# openclaw-dev

跨平台 Agent Skill 包 — 安装到代码 Agent（Claude Code / Gemini / Codex / Qwen），让它们具备开发、调试、扩展 [OpenClaw](https://github.com/nicepkg/openclaw) 的能力。

```
openclaw-dev (知识载体)
    ↓ 安装到
Claude Code / Gemini / Codex / Qwen (代码 agent 平台)
    ↓ agent 利用这些知识去
开发 / 调试 / 扩展 / 优化 OpenClaw
```

## 组件

| 类型 | 名称 | 说明 |
|------|------|------|
| **Skill** | `openclaw-dev-knowledgebase` | 全面知识库 — 功能/架构/开发/部署/运维 (9 reference files) |
| **Skill** | `openclaw-skill-development` | Skill 全生命周期 SOP — 创建/验证/部署 |
| **Skill** | `openclaw-agent-development` | Agent 配置 — agents.list[], bindings, per-agent 安全 |
| **Skill** | `openclaw-plugin-architecture` | Plugin 开发 — openclaw.plugin.json, api.register* API |
| **Skill** | `openclaw-skill-evolution` | 数据驱动 skill 演化 — session 日志分析 |
| **Agent** | `plugin-validator` | OpenClaw plugin 结构验证 |
| **Agent** | `skill-reviewer` | Skill 质量评审 (A/B/C/D 评分) |
| **Command** | `/create-skill` | 引导式 skill 创建 |
| **Command** | `/deploy-skill` | 部署 skill 到 OpenClaw agent |
| **Command** | `/list-skills` | 列出已安装 skills |
| **Command** | `/validate-skill` | 验证 skill 结构和元数据 |
| **Command** | `/scaffold-agent` | 交互式 agent 搭建 |
| **Command** | `/scaffold-plugin` | 交互式 plugin 搭建 |

## 安装

这些 skills 安装到**代码 agent 平台**上，让 agent 获得 OpenClaw 开发知识。

### Claude Code

```bash
# 作为 plugin 链接
ln -s /path/to/openclaw-dev ~/.claude/plugins/openclaw-dev
```

### Gemini Antigravity

```bash
# 复制到项目 skill 目录
cp -r skills/* /path/to/project/.agents/skills/
```

### 远程代码 Agent

```bash
# 部署到运行代码 agent 的远程机器
rsync -avz skills/ user@remote:<agent-skills-dir>/
```

> **注意**: 这些 skills 教 agent 如何操作 OpenClaw。agent 使用这些知识去操作目标机器上的 OpenClaw（`~/.openclaw/`）。

## 项目结构

```
openclaw-dev/
├── skills/                          # 5 个 skills (核心知识载体)
│   ├── openclaw-dev-knowledgebase/    # 全面知识库 + 9 references
│   ├── openclaw-skill-development/    # Skill 开发 SOP + scripts
│   ├── openclaw-agent-development/    # Agent 配置指导
│   ├── openclaw-plugin-architecture/  # Plugin API 开发
│   └── openclaw-skill-evolution/      # 数据驱动演化
├── agents/                          # 2 个 subagent
├── commands/                        # 6 个 slash commands
├── scripts/                         # 验证脚本
└── plugins/qa/                      # QA 测试工具
```

## 配置

Copy `.claude/openclaw-dev.local.md.example` → `.claude/openclaw-dev.local.md` and customize paths for your environment.

## 开发

See the [OpenClaw upstream repo](https://github.com/nicepkg/openclaw) for core development.

## License

MIT
