# Skill 演化高级技术

## 语义分析

### 触发词聚类

从 session 日志提取所有触发查询，聚类分析找到描述中遗漏的触发模式:

```python
from collections import Counter

def cluster_trigger_phrases(trigger_phrases):
    """找到高频词和 n-gram 模式"""
    words = Counter()
    bigrams = Counter()
    for phrase in trigger_phrases:
        tokens = phrase.lower().split()
        words.update(tokens)
        bigrams.update(zip(tokens, tokens[1:]))
    return {
        "top_words": words.most_common(20),
        "top_bigrams": bigrams.most_common(10),
    }
```

### 意图差距检测

找到 skill 应该触发但未触发的 session:

1. 从成功触发的 session 提取特征词
2. 扫描未触发 session，找到包含相似特征词的查询
3. 这些就是 description 缺失的触发模式

## 因果分析

### 错误链追踪

```
用户请求 → skill 触发 → 工具调用 1 ✅ → 工具调用 2 ❌ → 重试 → ❌ → 放弃
```

追踪错误链可以发现:
- 工具序列中的脆弱点
- 缺失的错误处理指导
- 需要添加的 fallback 策略

### 性能退化检测

比较 skill 在不同时间段的指标:

| 指标 | 上周 | 本周 | 变化 |
|------|------|------|------|
| 触发率 | 85% | 72% | ⬇️ -13% |
| 成功率 | 92% | 88% | ⬇️ -4% |
| 平均 tokens | 3.2k | 4.8k | ⬆️ +50% |

信号: token 使用增加但成功率下降 → skill 指令可能有歧义。

## A/B 测试

### 方法

1. 备份当前版本到 `.evolution/v1.2.0.md`
2. 部署改进版本
3. 运行 7 天收集数据
4. 比较关键指标

### 判断标准

| 结果 | 条件 | 操作 |
|------|------|------|
| ROLLOUT | 触发率 +20% 或 成功率 +10% 或 错误率 -30% | 部署 |
| ITERATE | 无显著变化 | 分析原因，继续改进 |
| ROLLBACK | 任何指标明显退化 | 恢复备份 |

### 最小样本量

- 至少 20 次 skill 触发 (每个版本)
- 覆盖不同 prompt 类型
- 排除异常值 (网络错误等)

## 持续演化流水线

```
每日: 收集 session → 提取指标
  ↓
每周: 分析趋势 → 标记需改进 skill
  ↓
每月: 全面审计 → 主要版本更新
```

### 自动触发条件

```python
EVOLUTION_TRIGGERS = {
    "error_rate_high": lambda s: s.error_rate > 0.15,
    "unused_30d": lambda s: s.last_triggered > 30,
    "low_trigger": lambda s: s.trigger_rate < 0.10,
    "slow_2x": lambda s: s.avg_duration > s.baseline_duration * 2,
}
```

### 版本历史管理

```
skill-name/
├── SKILL.md                    # 当前版本
└── .evolution/
    ├── v1.0.0.md               # 初始版本
    ├── v1.1.0.md               # 改进描述触发词
    ├── v1.2.0.md               # 添加错误处理
    └── changelog.md            # 每个版本的变更原因和指标
```
