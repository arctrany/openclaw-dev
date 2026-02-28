---
name: diagnose
description: "Systematic OpenClaw runtime diagnosis — analyze logs, identify fault patterns, output report, and accumulate new findings"
user-invocable: true
---

# /diagnose — OpenClaw 系统性诊断

读取 `openclaw-node-operations` skill 的 `references/diagnose-runbook.md`，按步骤执行完整的 5 步诊断流程。

## 快速参考

1. 定位日志 (`~/.openclaw/logs/`)
2. 量化概览 (错误总数、未处理异常、重启次数)
3. 五维分类 (网络/配置/认证/工具/进程)
4. 模式匹配 (对比 `fault-patterns.md` 已知模式)
5. 输出诊断报告 (含健康评分)
6. 沉淀新发现 (追加到 `fault-patterns.md`)

完整步骤和报告模板见 `references/diagnose-runbook.md`。
