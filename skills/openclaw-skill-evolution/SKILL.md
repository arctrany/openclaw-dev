---
name: openclaw-skill-evolution
description: This skill should be used when the user asks to "evolve skills", "upgrade skills based on usage", "analyze session logs", "improve skills from agent sessions", "skill performance analysis", "optimize skills from real usage", or needs to analyze OpenClaw agent session logs to identify skill improvement opportunities and evolve skills based on actual usage patterns, errors, performance metrics, and tool/model interactions.
metadata: {"clawdbot":{"always":false,"emoji":"🧬","requires":{"bins":["jq","python3"]}}}
user-invocable: true
version: 1.0.0
---

# OpenClaw Skill Evolution - Data-Driven Skill Improvement

## Overview

Skills evolve through continuous analysis of real-world usage. This skill analyzes OpenClaw agent session logs to identify improvement opportunities and evolve skills based on actual agent behavior.

**Core philosophy**: Skills should improve themselves by learning from how agents actually use them.

## Session Log Architecture

```
~/.openclaw/agents/<agent-id>/sessions/
├── sessions.json              # Session metadata and snapshots
├── <session-id>.jsonl         # Individual session logs (JSONL format)
└── ...
```

Each `.jsonl` line is a JSON event:
```json
{
  "timestamp": "2024-02-10T18:30:15.123Z",
  "type": "message|tool_use|tool_result|error|performance",
  "message": { "role": "user|assistant|system", "content": [...] },
  "metadata": {
    "model": "claude-opus-4",
    "tokens": {"input": 1234, "output": 567},
    "skill_triggered": "skill-name",
    "tools_used": ["Read", "Write", "Bash"]
  }
}
```

## Evolution Process

### Phase 1: Collect Sessions

```bash
jq -r '.agents.list[] | "\(.id) — \(.workspace)"' ~/.openclaw/openclaw.json
AGENT_ID="developer"
ls -lt ~/.openclaw/agents/$AGENT_ID/sessions/*.jsonl | head -20
```

**Filters**: time range, agent, skill, errors-only, latency threshold.

### Phase 2: Analyze Usage Patterns

**2.1 Triggering analysis** — Which queries trigger the skill? Are there queries that should but don't?

```python
sessions = load_sessions(agent_id, skill_name)
for session in sessions:
    for i, event in enumerate(session):
        if event.get('metadata', {}).get('skill_triggered') == skill_name:
            user_query = find_previous_user_message(session, i)
            trigger_phrases.append(user_query)
analyze_phrase_patterns(trigger_phrases)
```

**2.2 Tool usage** — Which tools are used most? What sequences work/fail?

**2.3 Error patterns** — What errors recur? Missing info? Wrong task match?

**2.4 Performance** — Duration, token usage, tool calls, retries.

### Phase 3: Gap Analysis

1. **Intent gaps** — Find sessions where agent struggled; identify missing skills
2. **Knowledge gaps** — Find sessions where agent expressed uncertainty
3. **Capability gaps** — Find tools agent needed but didn't have

### Phase 4: Generate Improvements

#### Description Evolution

**Before** (weak):
```yaml
description: Provides guidance on API testing
```

**After** (data-driven):
```yaml
description: This skill should be used when the user asks to "test the API", "validate API responses", "check API endpoints", "verify REST API works", "debug API calls"...
```

**Method**: Extract real user queries → identify patterns → rewrite description with actual user language.

#### Instruction Enhancement

Based on tool usage and errors, add:
- Error handling for common failures
- Working tool usage examples
- Edge case documentation
- Troubleshooting for frequent issues

#### Reference Addition

When skill body >500 lines, move details to `references/`. When repeated questions occur on same topic, create reference doc.

#### Metadata Optimization

```yaml
metadata: {
  "clawdbot": {
    "always": false,   # Set true if >50% sessions trigger
    "requires": {
      "bins": ["jq", "curl"],
      "env": ["API_KEY"],
      "anyBins": ["httpie", "curl"]
    }
  }
}
```

### Phase 5: Test & Validate

Deploy improved version side-by-side, measure for 7 days:
- Trigger rate improved >20% → ROLLOUT
- Success rate improved >10% → ROLLOUT
- Error rate decreased >30% → ROLLOUT
- No change → ITERATE
- Degraded → ROLLBACK

### Phase 6: Continuous Evolution

**Weekly**: Comprehensive skill analysis + improvement opportunities
**Monthly**: Full skill audit + major version updates

**Auto-trigger evolution when**:
- Error rate exceeds 15%
- Not triggered in 30 days
- Triggers <10% of expected times
- Duration >2x baseline

## Evolution Workflow (Quick Reference)

```bash
# Step 1: Identify target skill by usage + error rate
python3 scripts/skill-usage-report.py --days 30

# Step 2: Run analysis suite
SKILL="api-testing"
python3 scripts/analyze-triggers.py --skill $SKILL > analysis/triggers.txt
python3 scripts/analyze-errors.py --skill $SKILL > analysis/errors.txt
python3 scripts/analyze-performance.py --skill $SKILL > analysis/performance.txt

# Step 3: Generate improvement plan from analysis outputs

# Step 4: Implement improvements
cp skills/$SKILL/SKILL.md skills/$SKILL/.evolution/v$(get-version).md

# Step 5: Deploy to test workspace, monitor 7 days

# Step 6: Rollout or iterate based on metrics
```

## Best Practices

1. **Incremental** — Small, measurable changes over time
2. **Data-driven** — Every change backed by session analysis
3. **Validated** — A/B test before full rollout
4. **Versioned** — Track evolution history in `.evolution/`
5. **Reversible** — Keep backups, can rollback
6. **User-centric** — Improve based on actual user language

## Troubleshooting

| Issue | Fix |
|-------|-----|
| No session data | Check `~/.openclaw/agents/*/sessions/*.jsonl` exists |
| Wrong error rate | Review error categorization; filter to skill-active sessions |
| Worse after change | Rollback; use more diverse session data |
| Too many triggers | Narrow trigger phrases; add negative examples |

## Metrics Glossary

| Metric | Definition |
|--------|------------|
| Trigger rate | % sessions skill triggered when relevant |
| Success rate | % sessions completed without errors |
| Error rate | % sessions with errors when skill active |
| Avg duration | Mean task completion time with skill |
| Token efficiency | Output / input tokens ratio |
| Tool efficiency | Successful / total tool calls |

## Additional Resources

- **`references/analysis-scripts.md`** — Detailed script documentation and output examples
- **`references/advanced-techniques.md`** — Semantic analysis, causal analysis, A/B testing, automated generation, continuous pipeline

---

**Remember**: Skills should continuously evolve based on how agents actually use them. Data-driven evolution ensures skills remain effective and valuable.
