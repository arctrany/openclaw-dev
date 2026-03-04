---
name: maintain-evolve
description: "Analyze collected signals (from /maintain-signals) and generate a prioritized Evolution Report for openclaw-dev skills and commands."
user-invocable: true
---

# /maintain-evolve — 分析 + 生成进化报告

> **维护者命令**: 此命令仅在 `openclaw-dev.local.md` 设置 `role: maintainer` 时加载。

读取 `data/signals.json`，输出优先级排序的改进建议。

**前置条件**: 先运行 `/maintain-signals`。

## 分析流程

### 1. 检查信号文件

```bash
[ -f data/signals.json ] || { echo "请先运行 /maintain-signals"; exit 1; }
python3 -c "import json; d=json.load(open('data/signals.json')); print(f'采集时间: {d[\"collected_at\"]}  窗口: {d[\"window_days\"]}天  节点: {len(d[\"sources\"])}')"
```

### 2. OpenClaw 版本检查 + Release Notes 解析

读取 `signals["openclaw_version"]`，若 `update_available: true`：

```python
import json, re
d = json.load(open("data/signals.json"))
ov = d["openclaw_version"]
if ov["update_available"] and ov.get("release_notes"):
    body = ov["release_notes"]["body"]

    # 按变更类型分类
    categories = {
        "new_commands":    [],  # 新增 CLI 命令/flag
        "deprecated":      [],  # 废弃项
        "api_changes":     [],  # API/Plugin SDK 变更
        "config_changes":  [],  # 配置 schema 变更
        "breaking":        [],  # Breaking changes
    }

    for line in body.splitlines():
        l = line.lower()
        if any(k in l for k in ["new command", "add command", "new flag", "new option"]):
            categories["new_commands"].append(line.strip())
        elif any(k in l for k in ["deprecat", "removed", "废弃"]):
            categories["deprecated"].append(line.strip())
        elif any(k in l for k in ["api", "plugin sdk", "plugin api"]):
            categories["api_changes"].append(line.strip())
        elif any(k in l for k in ["config", "schema", "openclaw.json"]):
            categories["config_changes"].append(line.strip())
        elif any(k in l for k in ["breaking", "不兼容"]):
            categories["breaking"].append(line.strip())

    print(json.dumps(categories, indent=2, ensure_ascii=False))
```

变更类型 → 受影响的 skill/reference 映射：

| 变更类型 | 需要更新的位置 |
|---------|-------------|
| `new_commands` / `new_flag` | `node-operations` SKILL.md + `references/install-and-debug.md` |
| `deprecated` | 对应 reference 加 ⚠️ 废弃标注 |
| `api_changes` | `knowledgebase/references/plugin-api.md` |
| `config_changes` | `knowledgebase/references/core-concepts.md` |
| `breaking` | 所有 4 个 skill 的 description 检查，优先级 P0 |

输出列为 P0 issue：**需要按上表逐项更新 skill 内容**

### 3. Issue 聚类分析

按 `label_names` 分组，计算各 skill/command 被提及次数：
- bug + age_days > 7 → P0
- bug + age_days ≤ 7 → P1
- enhancement → P2

### 4. Skill 触发质量

```python
import json
d = json.load(open("data/signals.json"))
for skill, sig in d["skill_signals"].items():
    sessions = max(sig["sessions"], 1)
    rate = sig["triggered"] / sessions * 100
    err_rate = sig["errors"] / max(sig["triggered"], 1) * 100
    flag = ""
    if rate < 20: flag += " ⚠️ 低触发"
    if err_rate > 15: flag += " ⚠️ 高错误"
    if sig["triggered"] == 0: flag += " ❌ 从未触发"
    print(f"{skill}: 触发率{rate:.0f}% 错误率{err_rate:.0f}%{flag}")
```

阈值：
- 触发率 < 20% → description 缺关键词
- 错误率 > 15% → 指令不清晰
- 从未触发 → 功能重叠 or 废弃候选

### 5. Command 使用率

```python
for cmd, sig in d["command_signals"].items():
    if sig["uses"] == 0:
        print(f"{cmd}: 0次 → 考虑删除或重命名")
```

### 6. 生成报告

按以下格式输出 Evolution Report，然后逐条询问开发者是否应用：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
openclaw-dev Evolution Report
   采集时间: <collected_at> | 节点数: <n> | Sessions: <total>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OpenClaw 版本
   本地: <local> | 最新: <latest>
   [如有更新] ⚠️ 需要同步新版本变更到 knowledgebase / node-operations

GitHub Issues (<n> open)
   P0: #xx "..." [bug, <n>天]
   P1: #xx "..." [bug]
   P2: #xx "..." [enhancement]

Skill 触发质量
   <skill>: 触发率 x%, 错误率 y%  [状态]

Command 使用率 (零使用)
   /xxx: 0次 → 评估是否保留

改进建议 (优先级排序)
   1. [P0] ...
   2. [P1] ...

下一步
   应用建议 → 逐条确认后编辑 SKILL.md / commands/
   验证     → bash scripts/skill-lint.sh skills/<name>
   发版     → git tag v2.x.x && git push && bash install.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
