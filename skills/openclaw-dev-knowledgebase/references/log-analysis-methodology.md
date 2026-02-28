# OpenClaw 日志分析方法论

## 分析流程

```
1. 定位日志 → 2. 量化概览 → 3. 故障分类 → 4. 根因链追踪 → 5. 沉淀发现
```

## 第一步：定位日志

| 平台 | Gateway 日志 | 错误日志 |
|------|-------------|---------|
| macOS (LaunchAgent) | `~/.openclaw/logs/gateway.log` | `~/.openclaw/logs/gateway.err.log` |
| macOS (手动) | stdout | stderr |
| Linux (systemd) | `journalctl --user -u openclaw-gateway` | 同左 (`-p err`) |
| Docker | `docker logs openclaw-gateway` | `docker logs openclaw-gateway 2>&1 1>/dev/null` |

其他关键文件:
```
~/.openclaw/openclaw.json                    # 主配置
~/.openclaw/openclaw.json.bak*               # 配置备份 (手动编辑的证据)
~/.openclaw/agents/<id>/agent/auth-profiles.json  # API key 配置
~/.openclaw/agents/<id>/sessions/*.jsonl     # Session 日志
~/Library/LaunchAgents/openclaw-gateway*.plist  # macOS 服务配置
```

## 第二步：量化概览

先获取全局视图，不要直接看细节:

```bash
# 日志时间跨度和规模
head -1 gateway.log | cut -d' ' -f1     # 起始时间
tail -1 gateway.log | cut -d' ' -f1     # 结束时间
wc -l gateway.log gateway.err.log       # 行数

# 错误总量和每日分布
awk '{print substr($1,1,10)}' gateway.err.log | sort | uniq -c | sort -rn | head -20

# 未处理异常
grep -c "UnhandledPromiseRejection\|unhandled" gateway.err.log

# 配置备份数量 (手动编辑频率指标)
ls -la ~/.openclaw/openclaw.json.bak* 2>/dev/null | wc -l
```

## 第三步：故障分类

按 5 个维度分类错误:

### 3.1 网络层
```bash
grep -c "fetch failed\|ECONNREFUSED\|ETIMEDOUT\|ENOTFOUND\|ERR_ASSERTION.*IP" gateway.err.log
# 按天:
grep "fetch failed" gateway.err.log | awk '{print substr($1,1,10)}' | sort | uniq -c | sort -rn
```

### 3.2 配置层
```bash
grep -c "invalid character\|SyntaxError.*JSON\|config reload skipped" gateway.err.log
# 看具体位置:
grep "invalid character" gateway.err.log | head -5
```

### 3.3 认证层
```bash
grep -c "No API key\|auth.*failed\|401\|rate.limit\|429" gateway.err.log
```

### 3.4 工具层
```bash
grep "\[tools\]" gateway.err.log | awk -F'tool=' '{print $2}' | awk '{print $1}' | sort | uniq -c | sort -rn
```

### 3.5 进程层
```bash
# Gateway 重启次数
grep -c "Gateway listening\|SIGTERM\|starting" gateway.log
# Crash loop 检测: 10 分钟内 3+ 次启动
grep "Gateway listening" gateway.log | awk '{print $1}' | while read ts; do
  epoch=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${ts%%.*}" +%s 2>/dev/null)
  echo "$epoch $ts"
done | awk 'NR>1 && $1-prev<600 {count++; if(count>=2) print "CRASH LOOP at "$2} {prev=$1; count=0}'
```

## 第四步：根因链追踪

从表象错误追溯到根因，典型链:

```
表象: "No API key found"
  ↑ 因为: config reload skipped (invalid config)
  ↑ 因为: JSON parse error at line 193
  ↑ 根因: 手动编辑引入多余逗号
```

追踪方法:
```bash
# 找到第一次出现的时间
grep -m1 "No API key" gateway.err.log
# 看同一时间段还发生了什么
grep "2026-02-04T04:3" gateway.err.log | head -20
```

## 第五步：沉淀发现

**每次分析后必须做**:

1. 检查 `references/fault-patterns.md` 中是否已有匹配模式
2. 如果是新模式 → **追加到 fault-patterns.md**
3. 格式:
```markdown
### [模式名称]
- **签名**: `[日志关键词]`
- **根因**: [根本原因]
- **影响**: [影响范围]
- **修复**: [修复步骤]
- **预防**: [预防措施]
- **首次发现**: [日期]
```

## 关键指标基线

健康的 OpenClaw 应该满足:

| 指标 | 健康值 | 告警值 |
|------|--------|--------|
| 每日错误数 | < 50 | > 200 |
| fetch failed / 天 | < 5 | > 50 |
| Gateway 重启 / 天 | 0-1 | > 3 |
| 配置解析失败 | 0 | > 0 |
| 工具失败率 | < 5% | > 15% |
| .bak 文件增速 | 0 / 周 | > 3 / 周 |
