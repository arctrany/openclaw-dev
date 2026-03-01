# OpenClaw Dev (Codex Adapter)

本仓库原始形态是面向 OpenClaw / Claude 插件开发的工具集（使用 `.claude-plugin/plugin.json` 作为插件清单）。

对 Codex 的适配策略：
- 保留 `.claude-plugin/` 结构不变（OpenClaw 仍按此规范工作）
- 提供 `AGENTS.md` 作为 Codex 的入口说明
- 优先使用仓库里的脚本完成诊断、验证、迭代

## 项目结构（高频）

- `commands/`: Claude 风格命令模板（可作为流程参考）
- `commands/diagnose-openclaw.md`: 主插件级 OpenClaw 能力诊断入口（调用 `plugins/qa`）
- `commands/evolve-openclaw-capability.md`: 主插件级能力演化入口（诊断-修复-回归）
- `agents/`: Claude/OpenClaw agent 模板与检查规则
- `agents/openclaw-capability-evolver.md`: 主插件级能力演化 agent（调用 `plugins/qa`）
- `skills/`: OpenClaw 技能开发/演化参考与脚本
- `scripts/`: 通用技能验证脚本
- `plugins/qa/`: OpenClaw QA 诊断框架（重点，用于诊断与演化）
  - Claude/OpenClaw 插件入口：`.claude-plugin/` + `commands/` + `agents/`
  - Codex 入口：`plugins/qa/AGENTS.md`

## Codex 常用工作流

### 1) 诊断 OpenClaw 能力（推荐先跑）

```bash
bash plugins/qa/scripts/run-qa-tests.sh --agent <agent-id> --quick
```

完整诊断：

```bash
bash plugins/qa/scripts/run-qa-tests.sh --agent <agent-id> --full
```

可选便捷入口（自动补环境变量/展示最新报告）：

```bash
bash plugins/qa/scripts/codex-diagnose.sh --agent <agent-id> --quick
```

报告输出目录：
- `plugins/qa/reports/`

### 2) 验证技能定义质量

```bash
bash scripts/validate-skill.sh skills/<skill-name>
```

### 3) 验证技能是否已加载到 agent 会话

```bash
bash scripts/verify-skill.sh <agent-id> <skill-name>
```

### 4) 场景化模型路由 + OpenClaw agent 执行（新）

用于 deep research / coding / 私密场景的模型与 agent 路由（基于 `skills/model-routing-governor`）：

```bash
oc-route --list-presets
oc-route sensitive-research -m "先给我一版调研框架" --pretty
oc-route research-cn -m "调研这个赛道" --run --pretty
oc-route coding-cn -m "重构模块并加测试" --run --pretty
```

如果当前 shell 还未加载 `PATH` 或未安装全局命令，可回退为 `python3 scripts/oc-route.py ...`。

## 演化建议（Codex 执行顺序）

1. 先跑 `plugins/qa` 快速诊断，定位失败场景（模型、memory、skills、工具调用）
2. 修改对应 `skills/`、agent 配置或 OpenClaw 环境
3. 用 `scripts/validate-skill.sh` 做静态校验
4. 回跑 `plugins/qa` 验证回归
5. 根据报告沉淀修复策略到 `skills/` / `commands/` / `agents/`

## 兼容说明

- `.claude-plugin/plugin.json` 是 OpenClaw 插件清单，不需要改名
- Codex 不直接执行 `commands/*.md` 里的 Claude 专用指令（例如 `AskUserQuestion`），应把这些文件当作“流程模板”
- 根插件 `openclaw-dev` 承担“工具箱/编排层”，`plugins/qa` 承担“诊断执行层”
- `plugins/qa/scripts/run-qa-tests.sh` 已支持通过环境变量覆盖路径，便于不同机器/目录布局
