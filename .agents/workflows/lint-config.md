---
name: lint-config
description: "Validate openclaw.json syntax and semantics before applying — prevent configuration corruption"
user-invocable: true
---

# /lint-config — 配置验证

读取 `openclaw-node-operations` skill 的 `references/lint-config-runbook.md`，按步骤执行配置验证。

## 快速参考

检查 5 项:
1. JSON 语法 (含 .bak 恢复提示)
2. 必要字段 (agents.list, id, model)
3. 安全审计 (bind 地址、端口)
4. 路径可达性 (workspace、node 路径)
5. Auth Profile 完整性

完整步骤和输出模板见 `references/lint-config-runbook.md`。
