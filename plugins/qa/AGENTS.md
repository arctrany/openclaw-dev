# QA Plugin (Codex)

`plugins/qa` 是用于诊断 OpenClaw 能力的 QA 插件。建议用它做能力演化前后的基线对比。

这是一个双入口插件：
- Claude/OpenClaw：使用 `.claude-plugin/plugin.json` + `commands/` + `agents/`
- Codex：使用本文件 `AGENTS.md`（并复用同一套 `scripts/`）

## 推荐入口（Codex）

```bash
bash scripts/run-qa-tests.sh --agent <agent-id> --quick
```

完整模式：

```bash
bash scripts/run-qa-tests.sh --agent <agent-id> --full
```

可选便捷入口（自动补环境变量/展示最新报告）：

```bash
bash scripts/codex-diagnose.sh --agent <agent-id> --quick
```

## 关键输出

- 报告：`plugins/qa/reports/qa-report-*.md`
- 临时日志：`/tmp/qa-test-*.log`

## 可覆盖环境变量（用于不同 OpenClaw 部署）

- `OPENCLAW_HOME_DIR`：默认 `~/.openclaw`
- `QA_SESSIONS_ROOT`：集中式 session 根目录（默认 `/Volumes/EXT/openclaw/sessions`）
- `QA_SESSION_DIR_OVERRIDE`：直接指定某个 agent 的 session 目录（优先级最高）
- `QA_OPENCLAW_CONFIG_FILE`：OpenClaw 主配置文件路径
- `QA_AUTH_PROFILES_FILE`：认证配置路径
- `QA_RUNTIME_LOG_DIR`：运行日志目录（默认 `/tmp/openclaw`）
- `QA_REPORT_DIR`：报告输出目录（默认 `plugins/qa/reports`）

## Codex 诊断/演化循环

1. 先跑 `--quick` 找 P0/P1 问题
2. 修复配置/技能/模型
3. 回跑 `--full` 做回归
4. 根据报告把修复经验沉淀到 `skills/` 或 `commands/`

## Claude/OpenClaw 插件入口（已提供）

- Command: `diagnose-openclaw`
- Command: `evolve-openclaw-capability`
- Agent: `openclaw-capability-evolver`
