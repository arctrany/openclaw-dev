# Huginn ↔ OpenClaw ↔ Postiz — 完整集成指南

## 前置：环境变量统一管理

**所有敏感配置（IP、端口、Token）都集中在：**
```
examples/openclaw/postiz-integration/config-remote/.env.sample
```
复制为 `.env.deploy` 并填写真实值，然后 `source .env.deploy` 再执行任何脚本。

```bash
cp .env.sample .env.deploy
vim .env.deploy  # 填写你的真实值
source .env.deploy
bash deploy-remote.sh
```

> **注意**：`.env.deploy` 已加入 `.gitignore`，不会被提交。

---

## Mac Mini OpenClaw 当前配置参考

| 变量 | 说明 | 查看方式 |
|------|------|----------|
| `OPENCLAW_HOOKS_TOKEN` | Webhook 认证令牌 | `grep HOOKS ~/.openclaw/openclaw.env` |
| `OPENCLAW_AUTH_TOKEN` | Gateway 认证令牌 | 同上 |
| `POSTIZ_API_KEY` | Postiz 公开 API 密钥 | Postiz → Settings → Public API |
| `POSTIZ_API_URL` | Postiz 内网地址 | 通常为 `http://<NAS-IP>:4007/api` |

---

## Huginn PostAgent 配置（使用变量参数化）

在 Huginn 中创建一个 **PostAgent**，选项（Options）填写：

```json
{
  "post_url": "http://{{ '{{' }}ENV['REMOTE_HOST']{{ '}}' }}:{{ '{{' }}ENV['OPENCLAW_GATEWAY_PORT']{{ '}}' }}/hooks/agent",
  "expected_receive_period_in_days": "1",
  "content_type": "json",
  "method": "post",
  "payload": {
    "agentId": "researcher",
    "name": "Huginn_Intelligence_Alert",
    "message": "🚨 重大情报 🚨\n\n标题: {{title}}\n链接: {{url}}\n摘要: {{description}}\n关键词: {{match}}",
    "deliver": true,
    "wakeMode": "now",
    "thinking": "high"
  },
  "headers": {
    "Authorization": "Bearer {{ '{{' }}ENV['OPENCLAW_HOOKS_TOKEN']{{ '}}' }}"
  },
  "emit_events": "false",
  "no_merge": "false",
  "output_mode": "clean"
}
```

或者如果 Huginn 不支持环境变量插值，直接写死具体值（这套值来自你的 `.env.deploy`）：

```json
{
  "post_url": "http://<GATEWAY_HOST>:<GATEWAY_PORT>/hooks/agent",
  "content_type": "json",
  "method": "post",
  "payload": {
    "agentId": "researcher",
    "name": "Huginn_Intelligence_Alert",
    "message": "🚨 重大情报 🚨\n\n标题: {{title}}\n链接: {{url}}\n摘要: {{description}}",
    "deliver": true,
    "wakeMode": "now",
    "thinking": "high"
  },
  "headers": {
    "Authorization": "Bearer <OPENCLAW_HOOKS_TOKEN>"
  },
  "emit_events": "false",
  "no_merge": "false",
  "output_mode": "clean"
}
```

---

## Pipeline 工作流

```
Huginn (WebsiteAgent → TriggerAgent → PostAgent)
    │
    │  HTTP POST /hooks/agent
    │  Authorization: Bearer <OPENCLAW_HOOKS_TOKEN>
    ▼
OpenClaw Gateway (<GATEWAY_HOST>:<GATEWAY_PORT>)
    │
    │  唤醒 researcher 工作区
    ▼
Varys (researcher) — 分析情报，写入 content-backlog.md
    │
    │  Cron/Heartbeat 定时拉取
    ▼
Davos (adm) — 内容创作，调用 postiz_create_post
    │
    │  HTTP POST (Authorization: <POSTIZ_API_KEY>)
    ▼
Postiz (192.168.1.78:4007) — 存为草稿，等待人工审核
    │
    ▼
社交平台（Twitter, LinkedIn, 小红书...）
```

---

## Huginn 推送连通性测试

测试 OpenClaw Webhook 是否可达（从 NAS 或本机运行）：

```bash
source .env.deploy
curl -s -w "\n状态码: %{http_code}\n" \
  -X POST "http://${REMOTE_HOST}:${OPENCLAW_GATEWAY_PORT}/hooks/agent" \
  -H "Authorization: Bearer ${OPENCLAW_HOOKS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "agentId": "researcher",
    "name": "Huginn_Smoke_Test",
    "message": "这是一条来自 Huginn 的测试消息。如果你收到这条消息，说明 Huginn → OpenClaw 的 Webhook 通道已完全打通！",
    "deliver": true,
    "wakeMode": "now"
  }'
```

预期返回：`HTTP 202` 表示 Varys 已被成功唤醒。
