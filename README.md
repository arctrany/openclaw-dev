# openclaw-dev

跨平台 Agent Skill 包 — 安装到代码 Agent（Claude Code / Gemini / Codex / Qwen），让它们具备开发、调试、扩展 [OpenClaw](https://github.com/nicepkg/openclaw) 的能力。

```
openclaw-dev (知识载体)
    ↓ 安装到
Claude Code / Gemini / Codex / Qwen (代码 agent 平台)
    ↓ agent 利用这些知识去
开发 / 调试 / 扩展 / 优化 OpenClaw
```

## 架构

```
Skills (知识/方法论)                Commands (动作)
─────────────────────            ─────────────────────
knowledgebase (ALL 知识)          /sync-knowledge  (更新知识)
  14 references                  /openclaw-status (查状态)

skill-development (技能生命周期)   /create-skill    (创建)
  8 references                   /deploy-skill    (部署)
                                 /validate-skill  (验证)
                                 /list-skills     (列表)
                                 /evolve-skill    (演化)

node-operations (节点运维)         /setup-node      (初始化)
                                 /scaffold-agent  (搭建 agent)
                                 /scaffold-plugin (搭建 plugin)
```

## 安装

### Claude Code

```bash
ln -s /path/to/openclaw-dev ~/.claude/plugins/openclaw-dev
```

### Gemini Antigravity

```bash
cp -r skills/* /path/to/project/.agents/skills/
```

### 远程代码 Agent

```bash
rsync -avz skills/ user@remote:<agent-skills-dir>/
```

## 项目结构

```
openclaw-dev/
├── skills/                            # 3 个 skills
│   ├── openclaw-dev-knowledgebase/      # ALL 知识 (14 references)
│   ├── openclaw-skill-development/      # 技能生命周期 (8 references)
│   └── openclaw-node-operations/        # 节点运维 SOP
├── commands/                          # 10 个 commands
├── agents/                            # 2 个 subagent
├── scripts/                           # 验证脚本
└── plugins/qa/                        # QA 测试工具
```

## 跨 OS 支持

| 平台 | 安装命令 |
|------|---------|
| macOS / Linux | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Windows (WSL2) | `iwr -useb https://openclaw.ai/install.ps1 \| iex` |

## License

MIT
