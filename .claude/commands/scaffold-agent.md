---
name: scaffold-agent
description: Interactive workflow to create a new OpenClaw agent with workspace, bindings, persona files, and security configuration.
argument-hint: [agent-id]
---

# Scaffold OpenClaw Agent

读取 `openclaw-dev-knowledgebase` skill 的 `references/scaffold-agent-guide.md`，按步骤引导用户创建新 Agent。

## 快速参考

1. 收集需求 (agent ID, 用途, model, 委派角色, 安全)
2. 环境检查 (验证配置, 列出现有 agent)
3. 创建 Workspace + persona 文件 (SOUL.md, AGENTS.md, USER.md)
4. 更新 openclaw.json (备份 + jq 修改)
5. 可选: 配置 Bindings (channel 绑定)
6. 重启 Gateway + 验证

完整步骤见 `references/scaffold-agent-guide.md`。
