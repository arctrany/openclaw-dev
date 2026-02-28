# openclaw-dev

**让你的 Code Agent 具备 OpenClaw 全栈开发能力。**

一个 skill 包 — 安装到 Claude Code / Qwen / Codex / Gemini，你的 code agent 就能开发、调试、运维、优化 OpenClaw。

## 快速安装

**一句话安装（在项目根目录运行）：**

```bash
git clone https://github.com/arctrany/openclaw-dev.git && cd openclaw-dev && bash install.sh
```

自动检测已安装的 code agent 并安装到所有平台。

**单平台一句话安装：**

| 平台 | 一句话安装 |
|------|-----------|
| **Claude Code** | `git clone https://github.com/arctrany/openclaw-dev.git && cd openclaw-dev && bash install.sh` |
| **Gemini** | `git clone https://github.com/arctrany/openclaw-dev.git && cd openclaw-dev && bash install.sh --project /path/to/project` |
| **Qwen** | 同上（自动检测 `~/.qwen/`） |
| **Codex** | 同上（自动检测 `~/.codex/`） |

**更新：**

```bash
cd openclaw-dev && git pull && bash install.sh
```

**安装后验证（任意 agent 中）：**

```
帮我安装 OpenClaw    → 应触发 node-operations skill
OpenClaw 架构原理    → 应触发 knowledgebase skill
创建一个 skill       → 应触发 skill-development skill
```

## 特点

- **跨平台**: 同一套 skill，Claude Code / Qwen / Codex / Gemini 都能用
- **一句话安装**: `git clone ... && bash install.sh` 自动检测所有已安装 agent
- **活知识**: `fault-patterns.md` 是活文档，agent 每次诊断后会追加新发现
- **闭环进化**: 分析 → 发现模式 → 沉淀 → 下次分析更精准
- **正交设计**: 3 个 skill 分工明确（知识/开发/运维），12 个 command 不重叠

## 为什么需要这个？

Code agent 本身不懂 OpenClaw 的架构、API、运维方法。安装 openclaw-dev 后，它就知道：

- 怎么安装 OpenClaw（macOS/Linux/Windows）
- 怎么创建 agent、skill、plugin
- 怎么诊断 Gateway 故障（从日志到根因）
- 怎么从运行数据中发现优化点
- 每次诊断发现的新模式会自动沉淀，**越用越精准**

安装后，在你的 code agent 里直接用自然语言或 /命令 操作 OpenClaw：

### 场景 1: 初始化一台新机器

```
帮我在这台 Linux 服务器上安装 OpenClaw，配置 Gateway 和 Tailscale
```

Agent 会自动读取 `node-operations` skill，按步骤执行安装、onboard、Gateway 服务配置、Tailscale 组网。

### 场景 2: Gateway 出问题了

```
OpenClaw Gateway 频繁重启，帮我诊断
```

Agent 会：
1. 读取 `log-analysis-methodology.md`，按 5 步方法论分析日志
2. 对照 `fault-patterns.md` 中的已知模式（如 crash loop 签名）
3. 定位根因并给出修复步骤
4. **新发现的模式会追加到 `fault-patterns.md`**，下次更快

### 场景 3: 开发一个新 skill

```
帮我给 momiji agent 创建一个语音播报技能
```

Agent 会走完 `skill-development` 的 Phase 1-5：需求 → 设计 → 实现 → 验证 → 部署。

### 场景 4: 修改配置前先检查

```
/lint-config
```

Agent 验证 `openclaw.json` 的语法、必要字段、安全设置、路径可达性。防止手动编辑导致全员 Agent 挂掉。

### 场景 5: 看看整体运行状态

```
/openclaw-status
```

输出 Gateway、Agents、Channels、Plugins、Sessions 的统一状态视图。

### 场景 6: 从运行数据优化 skill

```
/evolve-skill momiji voice-engine
```

Agent 分析 momiji 的 session 日志，找到 voice-engine skill 的触发率、错误率、改进方向。

## 测试

安装后，打开对应的 code agent，发送以下测试指令：

### Claude Code
```
/diagnose          # 应识别为 openclaw 诊断命令
/lint-config       # 应执行配置验证
/list-skills       # 应列出 openclaw 技能
```

### Qwen / Codex / Gemini
```
请帮我安装 OpenClaw
```
→ agent 应自动触发 `openclaw-node-operations` skill，给出跨平台安装步骤

```
OpenClaw 的 session 模型是怎么工作的？
```
→ agent 应触发 `openclaw-dev-knowledgebase` skill，引用 core-concepts.md

```
帮我创建一个新的 OpenClaw skill
```
→ agent 应触发 `openclaw-skill-development` skill，走 Phase 1-5 流程

### 验证脚本
```bash
# 验证 skill 文件完整性
bash scripts/validate-skill.sh skills/openclaw-dev-knowledgebase
bash scripts/validate-skill.sh skills/openclaw-node-operations
bash scripts/validate-skill.sh skills/openclaw-skill-development
```

## 架构

```
3 Skills (SSoT, 全平台共享)       12 Commands (Claude 薄包装)
──────────────────────────       ─────────────────────────
📚 knowledgebase                  /diagnose → refs/diagnose-runbook
   ├─ 核心概念 (5 refs)           /lint-config → refs/lint-config-runbook
   ├─ 开发指南 (4 refs)           /openclaw-status → refs/status-runbook
   ├─ 运维参考 (4 refs)           /sync-knowledge → refs/sync-knowledge-runbook
   ├─ 运行时分析 (2, 活文档)      /scaffold-agent → refs/scaffold-agent-guide
   ├─ 源码参考 (2 refs)           /scaffold-plugin → refs/scaffold-plugin-guide
   └─ 操作指南 (3 runbooks)       /list-skills → refs/list-skills-runbook
                                  /create-skill  /deploy-skill
🛠 skill-development              /validate-skill /evolve-skill
   ├─ Phase 1-5 SOP               /setup-node
   ├─ 示例 + 脚本
   └─ list-skills runbook

🖥 node-operations
   ├─ 安装/调试/组网 SOP
   └─ diagnose / lint / status runbooks
```

> **设计原则**: Skill 层是 Single Source of Truth (SSoT)，所有平台共享。
> Claude 的 /commands 只是薄包装 — 指向 skill references。

### Skill 分工

| Skill | 触发词 | 职责 |
|-------|--------|------|
| `knowledgebase` | "架构", "原理", "怎么工作" | 理论/内部原理 |
| `node-operations` | "安装", "调试", "修复" | 动手操作/运维 |
| `skill-development` | "创建 skill", "部署", "演化" | 开发方法论 |

### 闭环

```
/diagnose → 分析日志 → 匹配已知模式 → 发现新模式 → 追加 fault-patterns.md
                                                         ↓
                                              下次 /diagnose 命中率更高
```

## 跨 OS 支持

| 平台 | OpenClaw 安装 |
|------|-------------|
| macOS | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Linux | `curl -fsSL https://openclaw.ai/install.sh \| bash` |
| Windows | WSL2 + `iwr -useb https://openclaw.ai/install.ps1 \| iex` |

## License

MIT
