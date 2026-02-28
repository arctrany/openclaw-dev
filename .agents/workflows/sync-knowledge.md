---
name: sync-knowledge
description: "Sync openclaw-dev knowledge base with upstream OpenClaw documentation changes"
user-invocable: true
---

# /sync-knowledge — 同步知识库

读取 `openclaw-dev-knowledgebase` skill 的 `references/sync-knowledge-runbook.md`，将知识库与上游文档同步。

## 快速参考

1. 拉取上游最新 (`$OPENCLAW_REPO` 或 `~/openclaw`)
2. 比较变更 (自上次同步以来的文档修改)
3. 对照 Reference 映射表
4. 生成差异报告
5. 逐个更新受影响的 reference
6. 验证 skill 完整性

完整步骤见 `references/sync-knowledge-runbook.md`。
