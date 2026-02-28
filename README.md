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

## 一键安装

### 自动安装（推荐）

```bash
# 自动检测已安装的全局平台 (Claude Code / Codex)
./install.sh

# 安装到指定项目 (Gemini / Qwen，项目级安装)
./install.sh --project ~/your-project

# 安装所有平台
./install.sh --all --project ~/your-project

# 预览操作（不实际执行）
./install.sh --dry-run --project ~/your-project

# 只安装到指定平台
./install.sh --platforms claude,gemini --project ~/your-project
```

### 卸载

```bash
# 自动检测并卸载
./uninstall.sh

# 从项目卸载
./uninstall.sh --project ~/your-project

# 从所有平台卸载
./uninstall.sh --all --project ~/your-project
```

### 手动安装

#### Claude Code

```bash
ln -s /path/to/openclaw-dev ~/.claude/plugins/openclaw-dev
```

#### Gemini Antigravity

```bash
# 将 skill 链接到项目目录
mkdir -p /path/to/project/.agents/skills
ln -s /path/to/openclaw-dev/skills/openclaw-dev-knowledgebase /path/to/project/.agents/skills/
ln -s /path/to/openclaw-dev/skills/openclaw-skill-development /path/to/project/.agents/skills/
ln -s /path/to/openclaw-dev/skills/openclaw-node-operations   /path/to/project/.agents/skills/
```

#### Codex CLI

```bash
# 链接 skills 目录
mkdir -p ~/.codex
ln -s /path/to/openclaw-dev/skills ~/.codex/openclaw-dev-skills

# 在 ~/.codex/instructions.md 中添加引用
cat >> ~/.codex/instructions.md << 'EOF'
## OpenClaw Development Skills
Skills are available at `~/.codex/openclaw-dev-skills/`. Read the SKILL.md files when asked about OpenClaw.
EOF
```

#### Qwen Code

```bash
# 将 skill 链接到项目目录
mkdir -p /path/to/project/.qwen/skills
ln -s /path/to/openclaw-dev/skills/openclaw-dev-knowledgebase /path/to/project/.qwen/skills/
ln -s /path/to/openclaw-dev/skills/openclaw-skill-development /path/to/project/.qwen/skills/
ln -s /path/to/openclaw-dev/skills/openclaw-node-operations   /path/to/project/.qwen/skills/
```

#### 远程代码 Agent

```bash
rsync -avz skills/ user@remote:<agent-skills-dir>/
```

## 平台支持矩阵

| 平台 | 安装方式 | Skill 目录 | 安装类型 |
|------|---------|-----------|---------|
| Claude Code | symlink 整包 | `~/.claude/plugins/` | 全局 |
| Codex CLI | symlink + instructions.md | `~/.codex/` | 全局 |
| Gemini Antigravity | symlink 各 skill | `<project>/.agents/skills/` | 项目级 |
| Qwen Code | symlink 各 skill | `<project>/.qwen/skills/` | 项目级 |

## 项目结构

```
openclaw-dev/
├── install.sh                         # 一键安装脚本
├── uninstall.sh                       # 卸载脚本
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
