---
name: qa-agent
description: "Diagnose and optionally fix an OpenClaw agent's capability health using the bundled QA module. Default: diagnosis only. Use --fix to enter a diagnosis-fix-regression loop."
argument-hint: <agent-id> [--quick|--full] [--fix] [focus-area]
user-invocable: true
---

# /qa-agent — OpenClaw Agent 能力诊断与修复

使用 QA 模块 (`plugins/qa`) 诊断 OpenClaw agent 能力。默认仅诊断，加 `--fix` 进入修复循环。

## 输入

- 必须: `agent-id`
- 可选: `--quick` (默认) 或 `--full`
- 可选: `--fix` 启用诊断-修复-回归循环
- 可选: `focus-area` (`memory`, `skills`, `models`, `tools`, `multimodal`)

如果 `agent-id` 缺失，询问用户。

## 执行

```bash
bash ${CLAUDE_PLUGIN_ROOT}/plugins/qa/scripts/run-qa-tests.sh --agent "<agent-id>" <mode>
```

Fallback（非 Claude 运行时）:

```bash
bash plugins/qa/scripts/run-qa-tests.sh --agent "<agent-id>" <mode>
```

Mode:
- 默认 `--quick`
- 深度回归验证用 `--full`

## 诊断模式（默认）

输出:
1. Findings（按严重度排序）
2. Summary metrics（pass/fail/warnings/success rate）
3. Report path (`plugins/qa/reports/qa-report-*.md`)
4. 提示用户可用 `--fix` 进入修复循环

## 修复模式（--fix）

1. Baseline 诊断 (`--quick`)
2. 按优先级排列 failures/warnings (P0/P1 优先)
3. 应用最小可行修复
4. 重新运行 `--quick` 验证
5. 如有需要或用户要求，运行 `--full`
6. 总结改进和剩余风险

输出:
- Findings（按严重度排序）
- Fixes applied（文件 + 理由）
- 验证结果
- 剩余 issues 和建议
