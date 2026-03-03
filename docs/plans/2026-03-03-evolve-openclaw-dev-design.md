# openclaw-dev 自我进化系统设计

**日期**: 2026-03-03
**状态**: 已批准
**范围**: openclaw-dev 插件自身的数据驱动进化能力

---

## 背景

openclaw-dev 目前缺乏分析自身使用情况的能力。`/evolve-skill` 命令是给 OpenClaw workspace 内部 skill 用的，不适用于 openclaw-dev 插件本身。需要一套专门针对 openclaw-dev 的进化机制。

---

## 目标

- 通过 GitHub Issues 和 agent session 日志，量化 skills/commands 的使用质量
- 生成结构化改进建议，由开发者审批后手动应用
- 支持本地和 SSH 远程多节点日志采集
- 兼容 Claude Code、Codex、Qwen、Antigravity、iFlow 五种 agent

---

## 设计决策

| 问题 | 决策 |
|------|------|
| 触发方式 | 半自动：手动触发采集和分析，开发者审批改动 |
| 产出对象 | openclaw-dev 开发者（改进 repo 本身，不动用户本地 skill 副本）|
| 用户反馈来源 | GitHub Issues |
| 日志来源 | 各 agent 本地日志 + SSH 远程节点日志 |
| agent 日志路径 | 动态发现，不硬编码 |
| 分析信号 | skill 触发率/错误率 + command 使用率 |

---

## 总体架构

```
数据源                    采集层                    分析决策层
────────────────────────────────────────────────────────────
GitHub Issues  ─────┐
                    ├──→  /collect-signals  ──→  signals.json  ──→  /evolve-openclaw-dev
本地 agent 日志 ────┤         (agent-aware         (结构化信号)        (分析 + 报告 + diff)
                    │         动态发现路径)
远程 SSH 节点  ─────┘
```

两个命令，职责严格分离：采集不分析，分析不采集。

---

## 命令一：`/collect-signals`

### 参数

```
/collect-signals
  [--agent claude|codex|qwen|antigravity|iflow|all]  # 默认 all
  [--host user@remote]                                # SSH 远程节点，可多次指定
  [--days 30]                                         # 时间窗口，默认 30 天
  [--issues]                                          # 是否拉取 GitHub Issues
```

### 运行流程

1. **GitHub Issues 采集**（`gh issue list --repo arctrany/openclaw-dev --json`）
   - 提取标题、labels、openAt、comment 数

2. **本地 agent 日志动态发现**
   - 对每个已知 agent 根目录（`~/.claude`、`~/.codex`、`~/.qwen`、`~/.antigravity`、iFlow 路径）
   - 动态查找日志文件（按扩展名 `.jsonl`/`.log` 和内容格式特征识别）
   - 提取：skill 名出现次数、命令调用记录、error 事件

3. **远程节点采集**（如指定 `--host`）
   - SSH 远程执行动态发现脚本
   - 结果合并到本地 signals

4. **输出** `data/signals.json`

### signals.json 结构

```json
{
  "collected_at": "2026-03-03T10:00:00",
  "window_days": 30,
  "sources": ["claude-local", "antigravity-local", "ssh:user@host"],
  "issues": [
    {"number": 12, "title": "...", "labels": ["bug"], "age_days": 5}
  ],
  "skill_signals": {
    "openclaw-dev-knowledgebase": {"triggered": 42, "errors": 3, "sessions": 60},
    "openclaw-node-operations":   {"triggered": 18, "errors": 7, "sessions": 60},
    "openclaw-skill-development": {"triggered": 9,  "errors": 1, "sessions": 60},
    "model-routing-governor":     {"triggered": 2,  "errors": 0, "sessions": 60}
  },
  "command_signals": {
    "/diagnose":       {"uses": 15},
    "/create-skill":   {"uses": 8},
    "/sync-knowledge": {"uses": 0}
  }
}
```

---

## 命令二：`/evolve-openclaw-dev`

### 前置条件

必须先运行 `/collect-signals` 生成 `data/signals.json`。

### 分析步骤

1. **Issue 聚类**：按 label 分类，高频词提取，识别哪个 skill/command 被抱怨最多
2. **Skill 触发质量**：
   - 触发率 < 20% → description 缺关键词
   - 错误率 > 15% → 指令不清晰或依赖缺失
   - 从未触发 → 功能重叠或废弃候选
3. **Command 使用率**：零使用命令评估删除，高频命令评估升级
4. **生成报告 + diff 建议**，优先级排序（P0/P1/P2）

### 报告格式

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧬 openclaw-dev Evolution Report
   数据窗口: 30天 | 采集节点: 3 | Sessions: 142
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Issues (5 open)
   P0: #12 "node-operations 安装步骤失效" [bug, 5天未关闭]
   P1: #9  "model-routing 找不到触发词"   [bug]

📊 Skill 触发质量
   openclaw-node-operations:   触发率 30%, 错误率 39% ⚠️
   model-routing-governor:     触发率 3%,  错误率 0%  ⚠️ 极低触发

📉 Command 使用率
   /sync-knowledge: 0次 → 考虑删除或重命名

💡 改进建议 (优先级排序)
   1. [P0] node-operations — 补充安装失败 fallback 指令
   2. [P1] model-routing-governor description — 添加中文触发词
   3. [P2] /sync-knowledge — 评估是否保留

⚡ 下一步
   应用建议 → 逐条确认后编辑 SKILL.md
   验证     → bash scripts/skill-lint.sh skills/<name>
   发版     → git tag v2.x.x && git push && bash install.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 新增文件

```
dev/
├── commands/
│   ├── collect-signals.md        # 新增
│   └── evolve-openclaw-dev.md    # 新增
├── scripts/
│   └── collect-signals.py        # 新增（采集脚本）
└── data/
    └── signals.json              # 新增（gitignore，含用户路径）
```

`data/signals.json` 加入 `.gitignore`。

---

## 半自动进化闭环

```
1. /collect-signals --agent all --days 30 [--host user@remote]
2. /evolve-openclaw-dev
3. 开发者 review 报告，选择接受哪些建议
4. 手动编辑 SKILL.md / commands/
5. bash scripts/skill-lint.sh 验证
6. git tag v2.x.x + git push
7. bash install.sh  # 分发新版本
```

---

## 约束

- `signals.json` 不入库（含用户路径信息）
- 所有路径动态发现，不硬编码 agent 日志路径
- SSH 采集使用标准 `ssh`/`scp`，无额外依赖
- 跨平台：Claude Code、Codex、Qwen、Antigravity、iFlow 均支持
