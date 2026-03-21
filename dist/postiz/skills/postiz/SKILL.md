---
name: xpoz
description: "XPoz 社媒管理 — 支持 28+ 平台的定时发布、内容管理、数据分析、渠道管理和通知。使用此技能当需要：发布社媒帖子、调度内容、查看社媒分析、管理多平台账号、上传媒体素材、连接/断开渠道、查看通知。支持平台包括 X/Twitter, LinkedIn, Reddit, YouTube, TikTok, Instagram, Facebook, Threads, BlueSky, Medium, Dev.to, WordPress 等。"
metadata: {"clawdbot":{"emoji":"🌎","requires":{"env":["XPOZ_API_KEY"]}}}
---

# XPoz 社媒管理技能

通过 OpenClaw Plugin 注册的 tools 管理社媒内容。以下 tools 由 xpoz plugin 自动注册，agent 可直接调用。

## 可用 Tools

| Tool | 功能 | 何时使用 |
|------|------|---------| 
| `xpoz_list_integrations` | 列出已连接平台 | 创建帖子前先获取 integration ID |
| `xpoz_get_settings` | 获取平台要求 | 了解字符限制、必填字段 |
| `xpoz_create_post` | 创建/调度帖子 | 发布内容到社媒 |
| `xpoz_list_posts` | 查看排期列表 | 检查已安排的帖子 |
| `xpoz_delete_post` | 删除帖子 | 取消排期 |
| `xpoz_upload_media` | 上传本地媒体 | 附加图片/视频（TikTok/Instagram 必须先上传） |
| `xpoz_upload_from_url` | 从 URL 上传媒体 | 无需本地文件，直接从远程 URL 上传 |
| `xpoz_get_analytics` | 平台分析 | 查看粉丝/曝光/互动趋势 |
| `xpoz_get_post_analytics` | 帖子分析 | 查看单帖表现 |
| `xpoz_trigger_tool` | 平台工具 | 获取 Reddit flair、YouTube playlist 等 |
| `xpoz_connect_channel` | 连接新渠道 | 生成 OAuth URL 连接社媒账号 |
| `xpoz_disconnect_channel` | 断开渠道 | 删除已连接的社媒账号 |
| `xpoz_list_notifications` | 查看通知 | 查看发布成功/失败等系统通知 |
| `xpoz_find_slot` | 查找空闲时间 | 自动排期时避免与已有帖子冲突 |
| `xpoz_status` | 检查连接状态 | 验证配置和服务是否正常 |

## 核心工作流

### 发布帖子
```
1. xpoz_list_integrations → 获取目标平台 ID
2. xpoz_get_settings(integration_id) → 了解平台限制
3. xpoz_create_post(content, date, integrations) → 创建帖子
```

### 带媒体发布
```
1. xpoz_upload_media(file_path) 或 xpoz_upload_from_url(url) → 获取媒体 URL
2. xpoz_create_post(content, date, integrations, media=[url]) → 创建带媒体帖子
```

### 连接新渠道
```
1. xpoz_connect_channel(provider="x") → 获取 OAuth URL
2. 用户在浏览器中打开 URL 完成授权
3. xpoz_list_integrations → 确认新渠道已连接
```

### 智能排期
```
1. xpoz_find_slot(integration_id) → 获取下一个空闲时间
2. xpoz_create_post(content, date=空闲时间, integrations) → 自动排期
```

### 分析报告
```
1. xpoz_list_integrations → 获取所有平台
2. xpoz_get_analytics(id) → 各平台趋势
3. 汇总生成报告
```

## 注意事项

1. **日期格式**: 必须是 ISO 8601 (`"2026-03-10T09:00:00Z"`)
2. **媒体上传**: TikTok/Instagram/YouTube 必须先通过 `xpoz_upload_media` 或 `xpoz_upload_from_url` 上传
3. **平台设置**: Reddit 需要 title 和 subreddit，YouTube 需要 title
4. **字符限制**: 各平台不同，用 `xpoz_get_settings` 查看 `maxLength`
5. **环境变量**: 支持 `XPOZ_API_KEY` / `XPOZ_API_URL`（兼容旧名 `POSTIZ_API_KEY` / `POSTIZ_API_URL`）

## 备用方式: CLI

如果 tool 调用失败，可回退到 CLI 方式:
```bash
export XPOZ_API_KEY=$XPOZ_API_KEY
export XPOZ_API_URL=$XPOZ_API_URL
xpoz status
xpoz integrations:list
xpoz posts:create -c "内容" -s "2026-03-10T09:00:00Z" -i "integration-id"
xpoz channels:connect x
xpoz analytics:channel <id>
xpoz notifications:list
```
