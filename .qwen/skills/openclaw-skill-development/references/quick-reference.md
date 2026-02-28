# Skill 开发速查表

## 最小 SKILL.md 模板

```markdown
---
name: my-skill
description: "Use this skill when the user asks to 'trigger phrase 1', 'trigger phrase 2', or needs guidance on [topic]. Covers [what it does]."
metadata: {"clawdbot":{"always":false,"emoji":"🔧"}}
---

# My Skill

## 核心流程

1. [Step 1]
2. [Step 2]
3. [Step 3]

## 规则

- [Rule 1]
- [Rule 2]
```

## Frontmatter 速查

| 字段 | 必填 | 说明 |
|------|------|------|
| `name` | ✅ | 必须匹配目录名 (kebab-case) |
| `description` | ✅ | 触发机制 — 越详细越好 |
| `metadata` | 否 | `clawdbot.always`, `emoji`, `requires` |
| `user-invocable` | 否 | `/skill-name` 命令触发 |
| `version` | 否 | semver 版本号 |

## Metadata 常见模式

```json
// 始终加载
{"clawdbot":{"always":true,"emoji":"📋"}}

// 需要二进制
{"clawdbot":{"always":false,"emoji":"🔧","requires":{"bins":["jq","curl"]}}}

// 需要环境变量
{"clawdbot":{"always":false,"emoji":"🔑","primaryEnv":"API_KEY"}}

// macOS only
{"clawdbot":{"always":false,"emoji":"🍎","os":["darwin"]}}

// 需要配置
{"clawdbot":{"always":false,"requires":{"config":["browser.enabled"]}}}
```

## 验证清单

```bash
# 1. SKILL.md 存在
test -f skill-dir/SKILL.md

# 2. name 匹配目录名
grep "^name:" skill-dir/SKILL.md

# 3. description 够长 (>30 chars)
grep "^description:" skill-dir/SKILL.md | wc -c

# 4. metadata JSON 有效
grep "^metadata:" skill-dir/SKILL.md | sed 's/metadata: *//' | jq .

# 5. 行数 <500
wc -l < skill-dir/SKILL.md

# 自动验证
bash scripts/validate-skill.sh skill-dir/
```

## 部署命令

```bash
# 查找 workspace
WORKSPACE=$(jq -r '.agents.list[] | select(.id=="<agent>") | .workspace' ~/.openclaw/openclaw.json)
WORKSPACE=$(eval echo "$WORKSPACE")

# 部署到 workspace
cp -r my-skill/ "$WORKSPACE/skills/my-skill/"

# 远程部署
rsync -avz my-skill/ user@remote:~/.openclaw/workspace/skills/my-skill/

# 发 /new 加载
# 验证
cat ~/.openclaw/agents/<id>/sessions/sessions.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for k, v in data.items():
    prompt = v.get('skillsSnapshot', {}).get('prompt', '')
    if 'my-skill' in prompt:
        print(f'FOUND in {k}')
"
```

## 故障排查

| 问题 | 一行修复 |
|------|---------|
| Skill 不加载 | 检查 `agents.list[].workspace` 路径 |
| Skill 不触发 | 增加 description 中的触发短语 |
| Always-on 浪费 token | 改 `always: false`，优化 description |
| 太长 | 移到 `references/`，body 保持 <500 行 |
| Metadata 无效 | `echo '<meta>' \| jq .` 验证 |
| 远程部署失败 | `rsync -avz` 确认路径正确 |
