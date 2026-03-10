---
name: huginn-source-manager
description: |
  Varys 用于动态管理 Huginn 情报源的操作手册。
  当 Momiji 下达新的情报方向指令后，Varys 通过 Huginn REST API 自动增删、调整情报追踪源（RSS Agent、Website Agent）。
  触发词：「添加情报源」、「调整赛道」、「情报节流/扩容」、「启停监测」、「情报侦察」
metadata:
  openclaw:
    emoji: "📡"
    requires:
      env: ["HUGINN_URL", "HUGINN_EMAIL", "HUGINN_PASSWORD"]
---

# Huginn 情报源动态管理 SOP

## 0. 前置常量

```bash
HUGINN_URL="${HUGINN_URL:-http://localhost:13000}"      # 从环境变量读取，不写死
HUGINN_EMAIL="${HUGINN_EMAIL}"                           # Huginn 登录邮箱
HUGINN_PASSWORD="${HUGINN_PASSWORD}"                     # Huginn 登录密码
BRIDGE_AGENT_NAME="OpenClaw_Intelligence_Bridge"        # 目标桥接 Agent 名称
```

## 1. 获取 API Token（Session 认证）

Huginn 没有 API Key 概念，需要先登录获取 Session Cookie：

```bash
# 先获取 CSRF token
CSRF=$(curl -s -c /tmp/huginn_cookies.txt "${HUGINN_URL}/users/sign_in" \
  | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 | cut -d'"' -f4)

# 登录获取 Cookie
curl -s -b /tmp/huginn_cookies.txt -c /tmp/huginn_cookies.txt \
  -X POST "${HUGINN_URL}/users/sign_in" \
  -d "user[email]=${HUGINN_EMAIL}&user[password]=${HUGINN_PASSWORD}&authenticity_token=${CSRF}"
```

## 2. 查询现有 Agents

```bash
# 列出所有 agents 及其 ID
curl -s -b /tmp/huginn_cookies.txt "${HUGINN_URL}/agents.json" \
  | python3 -c "import sys,json; agents=json.load(sys.stdin); [print(f\"{a['id']}: [{a['type']}] {a['name']}\") for a in agents]"
```

## 3. 获取桥接 Agent 的 ID

```bash
BRIDGE_ID=$(curl -s -b /tmp/huginn_cookies.txt "${HUGINN_URL}/agents.json" \
  | python3 -c "import sys,json; agents=json.load(sys.stdin); print(next((a['id'] for a in agents if a['name']=='${BRIDGE_AGENT_NAME}'), ''))")
echo "Bridge Agent ID: ${BRIDGE_ID}"
```

## 4. 添加新情报源（RSS Feed）

适用于：添加某个 RSS 订阅流作为新情报源

```bash
# 步骤 1: 获取当前 CSRF
CSRF=$(curl -s -b /tmp/huginn_cookies.txt -c /tmp/huginn_cookies.txt \
  "${HUGINN_URL}/agents/new" \
  | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 | cut -d'"' -f4)

# 步骤 2: 创建新的 RSS Agent，并直接绑定到桥接 Agent
curl -s -b /tmp/huginn_cookies.txt -X POST "${HUGINN_URL}/agents" \
  -H "Content-Type: application/json" \
  -d "{
    \"agent\": {
      \"name\": \"${SOURCE_NAME}\",
      \"type\": \"Agents::RssAgent\",
      \"schedule\": \"every_1h\",
      \"keep_events_for\": 172800,
      \"receiver_ids\": [${BRIDGE_ID}],
      \"options\": {
        \"url\": \"${RSS_URL}\",
        \"expected_update_period_in_days\": \"1\",
        \"include_articles\": \"false\"
      }
    },
    \"authenticity_token\": \"${CSRF}\"
  }"
```

**使用示例：**
```bash
SOURCE_NAME="OpenAI Blog" RSS_URL="https://openai.com/blog/rss.xml" bash 上面的命令
```

## 5. 删除/停用情报源

```bash
# 按 Agent ID 禁用（不删除，保留历史）
CSRF=$(curl -s -b /tmp/huginn_cookies.txt "${HUGINN_URL}/agents/${AGENT_ID}/edit" \
  | grep -o 'name="authenticity_token" value="[^"]*"' | head -1 | cut -d'"' -f4)

curl -s -b /tmp/huginn_cookies.txt -X PUT "${HUGINN_URL}/agents/${AGENT_ID}" \
  -H "Content-Type: application/json" \
  -d "{\"agent\":{\"disabled\":true},\"authenticity_token\":\"${CSRF}\"}"
```

## 6. 添加 TriggerAgent 过滤层（关键词过滤）

在 RSS Agent 和 OpenClaw 桥接之间插入关键词过滤，确保只有高价值内容才推送：

```bash
curl -s -b /tmp/huginn_cookies.txt -X POST "${HUGINN_URL}/agents" \
  -H "Content-Type: application/json" \
  -d "{
    \"agent\": {
      \"name\": \"AI_Intel_Trigger_Filter\",
      \"type\": \"Agents::TriggerAgent\",
      \"schedule\": \"never\",
      \"receiver_ids\": [${BRIDGE_ID}],
      \"source_ids\": [${RSS_AGENT_ID}],
      \"keep_events_for\": 86400,
      \"propagate_immediately\": true,
      \"options\": {
        \"expected_receive_period_in_days\": \"2\",
        \"keep_event\": \"true\",
        \"rules\": [{
          \"type\": \"regex\",
          \"value\": \"(?i)(GPT-[5-9]|Claude [4-9]|Gemini|reasoning model|AGI|foundation model|frontier|multimodal|agent framework|open source.*model|fine.?tun|RLHF|inference|benchmark)\",
          \"path\": \"title\",
          \"invert\": \"false\"
        }]
      }
    },
    \"authenticity_token\": \"${CSRF}\"
  }"
```

---

## 战略指令执行流程

当你从 Momiji 处收到情报方向变更指令时，按以下步骤操作：

### Step 1：解析指令
收到 Momiji 指令（如「我们这周重点追 AI Infra 和 GPU 赛道」），提取：
- **目标赛道/关键词**
- **需要添加何种来源**（RSS/网页抓取/NewsAPI）
- **是否要停用当前某些源**

### Step 2：评估现有源
```bash
# 查列表，判断哪些源与新方向无关（投票淘汰制：3次推送都非高价值内容则停用）
curl -s -b /tmp/huginn_cookies.txt "${HUGINN_URL}/agents.json" | python3 -c "..."
```

### Step 3：添加新源
根据目标赛道，添加高质量 RSS 源：

| 赛道 | 推荐来源 |
|------|----------|
| AI 前沿 | openai.com/blog, anthropic.com/news, deepmind.google/discover/blog |
| AI Infra | pytorch.org/blog, nvidia.com/en-us/blog, huggingface.co/blog |
| AI 安全 | bleepingcomputer.com（已有）, thehackernews.com |
| 开源模型 | github.com/trending（需 WebsiteAgent 抓取） |
| 硬件/芯片 | anandtech.com, semianalysis.com |

### Step 4：汇报 Momiji
执行完毕后，向 Momiji 汇报：
- 新增源数量
- 停用源数量
- 当前活跃监控点覆盖情况
- 预期首批情报推送时间
