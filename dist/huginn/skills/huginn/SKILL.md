---
name: huginn
description: "Huginn 情报流水线管理 — 监控、调整和优化 Huginn 自动化 agents。使用此技能当需要：查看流水线健康状态、调整情报采集目标、启用/禁用 feed agents、手动触发采集、修改 agent 调度规则、注入测试事件、查看 agent 日志排查问题、动态增删监控源。Momiji 可用此技能根据战略方向调整情报管道的监控焦点。"
metadata: {"clawdbot":{"emoji":"🕸️","requires":{"env":["HUGINN_URL","HUGINN_PASSWORD"]}}}
---

# Huginn 情报流水线管理技能

通过 OpenClaw Plugin 注册的 tools 管理 Huginn 自动化平台。以下 tools 由 huginn plugin 自动注册，agent 可直接调用。

## 可用 Tools

| Tool | 功能 | 何时使用 |
|------|------|---------|
| `huginn_list_agents` | 列出所有 agents 及状态 | 查看全局概览 |
| `huginn_get_agent` | 获取 agent 详情 | 查看配置、上下游关系 |
| `huginn_run_agent` | 手动触发运行 | 立即刷新 feed、触发 digest |
| `huginn_get_agent_events` | 获取 agent 事件 | 检查抓取结果、流水线输出 |
| `huginn_get_agent_logs` | 获取 agent 日志 | 调试错误、检查运行记录 |
| `huginn_create_event` | 注入手动事件 | 测试流水线、手动推送条目 |
| `huginn_update_agent` | 更新 agent 配置 | 修改 options/schedule/sources/disabled |
| `huginn_get_pipeline_status` | 聚合流水线状态 | 快速健康检查 |

## 核心工作流

### 1. 健康检查（日常巡检）

```
huginn_get_pipeline_status → 查看 summary (healthy/disabled/errored)
```

若有异常 agent：
```
huginn_get_agent_logs(agent_id) → 查看错误原因
huginn_get_agent(agent_id) → 检查配置是否正确
```

### 2. 调整情报目标（战略偏移）

当 Momiji 收到"把重点放在 AI 芯片领域"类指令时：

```
1. huginn_list_agents → 了解当前所有 feed 及其状态
2. huginn_get_agent(id) → 查看目标 agent 的 options (url, expected_update_period 等)
3. huginn_update_agent(id, options={...}) → 修改 feed URL 或过滤关键词
4. huginn_update_agent(id, disabled=false) → 启用相关 feed
5. huginn_update_agent(id, disabled=true) → 暂停低优先级 feed
6. huginn_run_agent(id) → 手动触发刷新，验证配置生效
```

### 3. 调整采集频率

```
huginn_update_agent(agent_id, schedule="every_1h")   # 高优先级
huginn_update_agent(agent_id, schedule="every_12h")   # 低优先级
huginn_update_agent(agent_id, schedule="every_2h")    # 常规
```

常用调度值：`every_1m`, `every_5m`, `every_1h`, `every_2h`, `every_12h`, `every_1d`, `midnight`, `never`

### 4. 测试流水线

注入测试事件验证下游处理：
```
huginn_create_event(agent_id=12, payload={
  title: "测试: AI 芯片突破",
  url: "https://example.com/test",
  source: "manual-test"
})
```

然后检查下游 agent 是否正确接收：
```
huginn_get_agent_events(downstream_agent_id) → 验证事件传递
```

### 5. 手动触发 Digest（立即生成情报摘要）

```
huginn_run_agent(digest_agent_id)  # 触发 DigestAgent 生成汇总
huginn_get_agent_events(digest_agent_id) → 查看生成的摘要
```

## 流水线拓扑

典型情报流水线结构：

```
Feed Agents (1-N) → DeDup Agent → Content Fetcher → Formatter → Digest → Bridge → Gateway
```

- **Feed Agents**: RssAgent/WebsiteAgent，负责抓取源数据
- **DeDup Agent**: DeDuplicationAgent，去重
- **Content Fetcher**: WebsiteAgent，获取全文内容
- **Formatter**: 格式化情报条目
- **Digest Agent**: DigestAgent，定期聚合为摘要
- **Bridge Agent**: PostAgent，通过 Webhook 推送到 OpenClaw Gateway

## 战略调整决策表

| 场景 | 操作 |
|------|------|
| 新增监控领域 | 启用已禁用的相关 feed，或 update_agent 修改现有 feed 的 URL |
| 降低某领域优先级 | disable 相关 feed agents |
| 紧急情报需求 | run_agent 手动触发所有相关 feed + digest |
| 调试无输出 | get_pipeline_status → 找 errored → get_agent_logs 排查 |
| 验证修改生效 | update_agent → run_agent → get_agent_events 确认输出 |

## 注意事项

- 修改 agent 配置后建议 `huginn_run_agent` 手动触发一次验证
- Bridge Agent 的超时错误通常是 Gateway 响应慢，不影响情报采集本身
- `disabled=true` 只是暂停调度，不删除 agent 配置，可随时恢复
- 注入的手动事件会被下游 agent 正常消费，用于测试时注意内容标记
