# OpenClaw × Postiz Integration

通过对 `postiz-app` (Postiz) 和 `openclaw` (OpenClaw) 项目的深度融合，我们可以实现一个全自动的社交媒体运营 Agent。本目录提供了完整的集成示例和最佳实践。

## 1. 架构分析

* **OpenClaw**: 作为本地优先的 AI 私人助手，其核心能力来源于 "Skill" (技能) 系统，Agent 通过读取包含指令的 `SKILL.md` 文件来学习如何调用外部工具。
* **Postiz**: 一个支持 28+ 个社交平台（X, LinkedIn, Reddit, TikTok 等）的社交媒体排期发布平台，拥有强大的后端 API。
* **融合点 (`postiz-agent`)**: Postiz 官方提供了一个专门为 Agent 设计的命令行工具 (`postiz` CLI)，它封装了复杂的 API，使其变成 Agent 易于理解和调用的 Bash 指令.

## 2. 深度融合 Workflow

直接下达自然语言指令给 OpenClaw（例如：“帮我写一篇关于 AI 的文章，配上图，然后发到 Twitter 和 LinkedIn”），将触发以下流转：

1. **Discover (发现)**: OpenClaw 调用 `postiz integrations:list` 查询已绑定的社交账号。
2. **Fetch (获取参数)**: 调用 `postiz integrations:trigger` 获取特定平台（如 Reddit 版块）的动态参数。
3. **Prepare (准备媒体)**: 调用 `postiz upload <file>` 将媒体上传到 Postiz CDN 获取 URL。
4. **Post (发布/定时)**: 调用 `postiz posts:create` 组合文案、链接、时间完成排期发布。
5. **Analyze (数据分析)**: 调用 `postiz analytics:post <post-id>` 读取点赞、浏览量等分析数据。

## 3. 落地实施指南

### 方案 A: 基于 Skill + Sandbox 的极致安全整合（推荐）

这是最贴合 OpenClaw 哲学的整合方式，也是官方主推路径。

1. **安装 Postiz CLI (在 Sandbox 镜像中)**:
   为了防止 AI 在宿主机乱敲命令，建议将 `postiz` CLI 打包到 OpenClaw 的 Sandbox 镜像中 (`openclaw/Dockerfile.sandbox-common`)，并确保 Sandbox 容器能访问到 Postiz API。
   ```bash
   npm install -g postiz
   ```

2. **配置环境变量**:
   在 OpenClaw 的 `.env` 文件中配置 Postiz API 凭证：
   ```env
   POSTIZ_API_KEY=your_api_key_here
   POSTIZ_API_URL=http://localhost:3000/api  # 私有化部署地址
   ```

3. **植入 Postiz Skill**:
   将 `skill/SKILL.md` 放入 OpenClaw 的工作区技能目录中，例如 `~/.openclaw/workspace/skills/postiz/SKILL.md`。这会告诉 OpenClaw 使用 `postiz` 相关的 bash 命令。

### 方案 B: 基于 OpenClaw Plugin 的深度结构化整合

如果你不希望 Agent 直接执行 Bash 命令，而是希望通过更结构化的 MCP Tools / Plugin API，可以使用我们开发的 Plugin。

代码包含在本目录的 `plugin/` 文件夹下。

**使用方法**:
```bash
openclaw plugins install -l ./examples/openclaw/postiz-integration/plugin
```
此 Plugin 会通过 TypeScript API 暴露结构化的 `postiz_create_post` 等 9 个 MCP Tool。

---

> 注：本实现放在 `examples/openclaw` 目录下，确保在 `npm install` 等安装过程中不会被默认加载到 code agent 中。
