---
name: postiz
description: "Postiz 社媒管理 — 支持 28+ 平台的定时发布、内容管理和数据分析。使用此技能当需要：发布社媒帖子、调度内容、查看社媒分析、管理多平台账号、上传媒体素材。支持平台包括 X/Twitter, LinkedIn, Reddit, YouTube, TikTok, Instagram, Facebook, Threads, BlueSky, Medium, Dev.to, WordPress 等。"
metadata: {"clawdbot":{"emoji":"🌎","requires":{"env":["POSTIZ_API_KEY"]}}}
---

# Postiz 社媒管理技能

通过 OpenClaw Plugin 注册的 tools 管理社媒内容。以下 tools 由 postiz plugin 自动注册，agent 可直接调用。

## 可用 Tools

| Tool | 功能 | 何时使用 |
|------|------|---------|
| `postiz_list_integrations` | 列出已连接平台 | 创建帖子前先获取 integration ID |
| `postiz_get_settings` | 获取平台要求 | 了解字符限制、必填字段 |
| `postiz_create_post` | 创建/调度帖子 | 发布内容到社媒 |
| `postiz_list_posts` | 查看排期列表 | 检查已安排的帖子 |
| `postiz_delete_post` | 删除帖子 | 取消排期 |
| `postiz_upload_media` | 上传媒体文件 | 附加图片/视频（TikTok/Instagram 必须先上传） |
| `postiz_get_analytics` | 平台分析 | 查看粉丝/曝光/互动趋势 |
| `postiz_get_post_analytics` | 帖子分析 | 查看单帖表现 |
| `postiz_trigger_tool` | 平台工具 | 获取 Reddit flair、YouTube playlist 等 |

## 核心工作流

### 发布帖子
```
1. postiz_list_integrations → 获取目标平台 ID
2. postiz_get_settings(integration_id) → 了解平台限制
3. postiz_create_post(content, date, integrations) → 创建帖子
```

### 带媒体发布
```
1. postiz_upload_media(file_path) → 获取媒体 URL
2. postiz_create_post(content, date, integrations, media=[url]) → 创建带媒体帖子
```

### 多平台同步
```
postiz_create_post(
  content="内容",
  date="2026-03-10T09:00:00Z",
  integrations=["twitter-id", "linkedin-id", "reddit-id"]
)
```

### 分析报告
```
1. postiz_list_integrations → 获取所有平台
2. postiz_get_analytics(id, days=30) → 各平台趋势
3. 汇总生成报告
```

## 注意事项

1. **日期格式**: 必须是 ISO 8601 (`"2026-03-10T09:00:00Z"`)
2. **媒体上传**: TikTok/Instagram/YouTube 必须先通过 `postiz_upload_media` 上传
3. **平台设置**: Reddit 需要 title 和 subreddit，YouTube 需要 title
4. **API 限速**: 30 请求/小时
5. **字符限制**: 各平台不同，用 `postiz_get_settings` 查看 `maxLength`

## 备用方式: CLI

如果 tool 调用失败，可回退到 CLI 方式:
```bash
export POSTIZ_API_KEY=$POSTIZ_API_KEY
export POSTIZ_API_URL=$POSTIZ_API_URL
postiz integrations:list
postiz posts:create -c "内容" -s "2026-03-10T09:00:00Z" -i "integration-id"
```
