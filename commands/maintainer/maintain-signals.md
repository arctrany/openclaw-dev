---
name: maintain-signals
description: "Collect evolution signals for openclaw-dev from GitHub Issues, project-scoped local agent logs (Claude Code, Codex, Qwen, Antigravity, iFlow), and optional SSH remote nodes. Run before /maintain-evolve."
argument-hint: "[--agent all|claude|codex|qwen|antigravity|iflow] [--host user@remote] [--days 30] [--project-root <path>] [--no-issues]"
user-invocable: false
---

# /maintain-signals — 采集进化信号

> **维护者命令**: 此命令仅在 `openclaw-dev.local.md` 设置 `role: maintainer` 时加载。

从 GitHub Issues、本地 agent 日志、SSH 远程节点收集信号，输出 `data/signals.json`。

## 运行

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/collect-signals.py \
  --agent all \
  --days 30 \
  --project-root "$PWD" \
  [--host user@remote] \
  [--no-issues]
```

Fallback（workspace 运行时）:

```bash
python3 scripts/collect-signals.py --agent all --days 30 --project-root "$PWD"
```

## 参数说明

| 参数 | 默认 | 说明 |
|------|------|------|
| `--agent` | `all` | agent 范围：all / claude / codex / qwen / antigravity / iflow |
| `--host` | 无 | SSH 远程节点，可多次指定 |
| `--days` | 30 | 分析时间窗口（天） |
| `--project-root` | 当前仓库路径 | 仅统计命中该项目路径的日志，减少跨项目噪音 |
| `--no-issues` | — | 跳过 GitHub Issues 采集（无 gh CLI 时使用） |

## 采集完成后

运行 `/maintain-evolve` 读取 `data/signals.json` 进行分析。
