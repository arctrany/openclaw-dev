# OpenClaw Dev (Codex Adapter)

OpenClaw / Claude 插件开发工具集。Codex 入口文件。

## 目录结构

| 路径 | 用途 |
|------|------|
| `commands/` | Claude 风格命令模板（流程参考） |
| `agents/` | Agent 模板与验证规则 |
| `skills/` | OpenClaw skill 开发参考与脚本 |
| `scripts/` | 通用验证脚本 |
| `plugins/qa/` | QA 诊断框架（诊断与演化的执行层） |

## 常用工作流

```bash
# 1. 诊断 OpenClaw 能力
bash plugins/qa/scripts/run-qa-tests.sh --agent <agent-id> --quick
bash plugins/qa/scripts/run-qa-tests.sh --agent <agent-id> --full

# 2. 验证 skill 定义质量
bash scripts/validate-skill.sh skills/<skill-name>

# 3. 验证 skill 是否已加载到 agent 会话
bash scripts/verify-skill.sh <agent-id> <skill-name>

# 4. 场景化模型路由
oc-route --list-presets
oc-route sensitive-research -m "..." --pretty
# 回退: python3 scripts/oc-route.py ...
```

报告输出：`plugins/qa/reports/`

## 演化顺序

1. `plugins/qa` 快速诊断 → 定位失败场景
2. 修改 `skills/` / agent 配置 / OpenClaw 环境
3. `scripts/validate-skill.sh` 静态校验
4. 回跑 `plugins/qa` 验证回归
5. 修复策略沉淀到 `skills/` / `commands/` / `agents/`

## 兼容说明

- `.claude-plugin/plugin.json` 是 OpenClaw 插件清单，不改名
- `commands/*.md` 中的 Claude 专用指令（如 `AskUserQuestion`）当作流程模板，不直接执行
- 路径覆盖：`plugins/qa/scripts/run-qa-tests.sh` 支持环境变量覆盖
