---
name: scaffold-plugin
description: Interactive workflow to create a new OpenClaw plugin (extension) with manifest, TypeScript entry point, and component registration.
argument-hint: [plugin-name]
---

# Scaffold OpenClaw Plugin

读取 `openclaw-dev-knowledgebase` skill 的 `references/scaffold-plugin-guide.md`，按步骤引导用户创建新 Plugin。

## 快速参考

1. 收集需求 (plugin 名称, 用途, 组件类型)
2. 创建目录 + manifest (`openclaw.plugin.json`)
3. 生成 TypeScript entry point (`src/index.ts`)
4. 创建 `package.json` + `tsconfig.json`
5. 安装到 `~/.openclaw/extensions/` (符号链接)
6. 重启 Gateway + 验证

完整步骤见 `references/scaffold-plugin-guide.md`。
