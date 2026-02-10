---
name: openclaw-skill-evolution
description: This skill should be used when the user asks to "evolve skills", "upgrade skills based on usage", "analyze session logs", "improve skills from agent sessions", "skill performance analysis", "optimize skills from real usage", or needs to analyze OpenClaw agent session logs to identify skill improvement opportunities and evolve skills based on actual usage patterns, errors, performance metrics, and tool/model interactions.
metadata: {"clawdbot":{"always":false,"emoji":"🧬","requires":{"bins":["jq","python3"]}}}
user-invocable: true
version: 1.0.0
---

# OpenClaw Skill Evolution - Data-Driven Skill Improvement

## Overview

Skills evolve through continuous analysis of real-world usage. This skill analyzes OpenClaw agent session logs to identify improvement opportunities, optimize skill effectiveness, and evolve skills based on actual agent behavior, tool usage patterns, errors, and performance metrics.

**Core philosophy**: Skills should improve themselves by learning from how agents actually use them in production.

## When to Use

Use this skill when:
- Analyzing agent performance to improve skills
- Investigating why skills aren't triggering as expected
- Optimizing skill descriptions based on real user queries
- Identifying missing capabilities from agent struggles
- Evolving skills based on error patterns
- Measuring skill effectiveness and ROI
- Conducting periodic skill audits and improvements

## OpenClaw Session Log Architecture

### Session Log Locations

```
~/.openclaw/agents/<agent-id>/sessions/
├── sessions.json              # Session metadata and snapshots
├── <session-id>.jsonl         # Individual session logs (JSONL format)
├── <session-id>.jsonl
└── ...
```

### Session Log Format (JSONL)

Each line in a `.jsonl` file is a JSON event:

```json
{
  "timestamp": "2024-02-10T18:30:15.123Z",
  "type": "message|tool_use|tool_result|error|performance|evaluation",
  "message": {
    "role": "user|assistant|system",
    "content": [{"type": "text|tool_use|tool_result", "text": "...", ...}]
  },
  "metadata": {
    "model": "claude-opus-4",
    "tokens": {"input": 1234, "output": 567},
    "latency_ms": 1523,
    "skill_triggered": "skill-name",
    "tools_used": ["Read", "Write", "Bash"],
    "error": {...}
  }
}
```

### Key Event Types

1. **Message events**: User inputs, assistant responses
2. **Tool use events**: Which tools were called, with what parameters
3. **Tool result events**: Success/failure, output, errors
4. **Error events**: Exceptions, failures, retries
5. **Performance events**: Latency, token usage, cost
6. **Evaluation events**: Quality assessments, user feedback

## Skill Evolution Process

### Phase 1: Session Log Collection

**Objective**: Gather relevant session logs for analysis.

```bash
# List all agents and their sessions
jq -r '.agents.list[] | "\(.id) — \(.workspace)"' ~/.openclaw/openclaw.json

# Find sessions for specific agent
AGENT_ID="developer"
ls -lt ~/.openclaw/agents/$AGENT_ID/sessions/*.jsonl | head -20

# Get session metadata
cat ~/.openclaw/agents/$AGENT_ID/sessions/sessions.json | jq .
```

**Collection criteria**:
- Time range: Last 7 days, 30 days, or all time
- Agent filter: Specific agent or all agents
- Skill filter: Sessions where specific skill triggered
- Error filter: Sessions with errors or failures
- Performance filter: Sessions above latency threshold

**Script**: Use `scripts/collect-sessions.py` to filter and collect relevant logs.

### Phase 2: Usage Pattern Analysis

**Objective**: Understand how agents actually use skills.

#### 2.1 Skill Triggering Analysis

**Questions to answer**:
- Which user queries trigger this skill?
- Are there queries that SHOULD trigger but DON'T?
- How often does skill trigger vs. how often it should?
- What alternative phrasings do users actually use?

**Analysis method**:
```python
# Extract all user messages before skill triggers
sessions = load_sessions(agent_id, skill_name)
for session in sessions:
    for i, event in enumerate(session):
        if event.get('metadata', {}).get('skill_triggered') == skill_name:
            # Look at previous user message
            user_query = find_previous_user_message(session, i)
            trigger_phrases.append(user_query)

# Analyze common patterns
analyze_phrase_patterns(trigger_phrases)
```

**Output**: List of actual user queries that triggered the skill.

#### 2.2 Tool Usage Pattern Analysis

**Questions to answer**:
- Which tools does agent use most when skill is active?
- Are there tools agent tries to use but aren't available?
- What's the typical tool usage sequence?
- Are there tool combinations that frequently fail?

**Analysis method**:
```python
# Extract tool usage when skill is active
tool_sequences = []
for session in sessions:
    if skill_is_active(session, skill_name):
        tools = extract_tool_sequence(session)
        tool_sequences.append(tools)

# Find common patterns
common_sequences = find_common_sequences(tool_sequences)
failed_tools = find_failed_tool_uses(sessions, skill_name)
```

**Output**: Tool usage patterns and optimization opportunities.

#### 2.3 Error Pattern Analysis

**Questions to answer**:
- What errors occur most frequently when skill is active?
- Are errors caused by missing information in skill instructions?
- Do errors indicate skill is being used for wrong tasks?
- What edge cases is skill not handling?

**Analysis method**:
```python
# Extract errors when skill is active
errors = []
for session in sessions:
    if skill_is_active(session, skill_name):
        session_errors = extract_errors(session)
        errors.extend(session_errors)

# Categorize errors
error_categories = categorize_errors(errors)
# - Missing file errors → skill should instruct to check existence
# - Permission errors → skill should document required permissions
# - Syntax errors → skill examples may be wrong
# - Timeout errors → skill should set realistic expectations
```

**Output**: Error patterns and root causes.

#### 2.4 Performance Analysis

**Questions to answer**:
- How long do tasks take when skill is active?
- Is agent spending time on unnecessary steps?
- Are there performance bottlenecks?
- What's the token usage impact of this skill?

**Analysis method**:
```python
# Extract performance metrics
performance = []
for session in sessions:
    if skill_is_active(session, skill_name):
        metrics = {
            'duration_ms': calculate_duration(session),
            'tokens_used': sum_tokens(session),
            'tool_calls': count_tool_calls(session),
            'retries': count_retries(session)
        }
        performance.append(metrics)

# Calculate statistics
avg_duration = mean([p['duration_ms'] for p in performance])
p95_duration = percentile([p['duration_ms'] for p in performance], 95)
```

**Output**: Performance metrics and optimization targets.

### Phase 3: Skill Gap Analysis

**Objective**: Identify what's missing from current skills.

#### 3.1 User Intent Gaps

**Method**: Analyze sessions where agent struggled or failed.

```python
# Find sessions with multiple retries or failures
struggling_sessions = []
for session in all_sessions:
    if has_multiple_retries(session) or has_failures(session):
        struggling_sessions.append(session)

# Analyze what agent was trying to do
for session in struggling_sessions:
    user_intent = extract_user_intent(session)
    agent_attempts = extract_agent_attempts(session)

    # Check if any skill could have helped
    relevant_skill = find_relevant_skill(user_intent)
    if not relevant_skill:
        # Gap: no skill exists for this intent
        skill_gaps.append(user_intent)
```

**Output**: List of intents that need new skills or skill expansion.

#### 3.2 Knowledge Gaps

**Method**: Analyze sessions where agent lacks domain knowledge.

```python
# Find sessions where agent explicitly states uncertainty
uncertain_sessions = []
for session in all_sessions:
    for event in session:
        if contains_uncertainty(event):  # "I'm not sure", "I don't know"
            uncertain_sessions.append((session, event))

# Categorize knowledge gaps
for session, uncertain_event in uncertain_sessions:
    topic = extract_topic(uncertain_event)
    knowledge_gaps.append(topic)
```

**Output**: Topics that need skill documentation or references.

#### 3.3 Capability Gaps

**Method**: Analyze tool availability vs. agent needs.

```python
# Find sessions where agent needs unavailable tools
for session in all_sessions:
    attempted_tools = extract_tool_attempts(session)
    available_tools = get_available_tools(session)

    missing_tools = set(attempted_tools) - set(available_tools)
    if missing_tools:
        capability_gaps.append({
            'session': session,
            'missing': list(missing_tools),
            'context': extract_context(session)
        })
```

**Output**: Missing capabilities that need skill workarounds or new tools.

### Phase 4: Skill Improvement Generation

**Objective**: Generate specific improvements for skills.

#### 4.1 Description Evolution

**Based on triggering analysis**, update skill description:

**Before** (weak):
```yaml
description: Provides guidance on API testing
```

**After** (strong, based on real queries):
```yaml
description: This skill should be used when the user asks to "test the API", "validate API responses", "check API endpoints", "verify REST API works", "debug API calls", or needs to interact with HTTP APIs for testing, validation, or debugging purposes.
```

**Method**:
1. Extract all user queries that triggered skill (from Phase 2.1)
2. Identify common patterns and phrasings
3. Rewrite description to include actual user language
4. Add specific trigger phrases in quotes
5. Expand contexts where skill should activate

#### 4.2 Instruction Enhancement

**Based on tool usage and errors**, enhance skill body:

**Additions to make**:
- Add error handling for common failures
- Include tool usage examples that actually work
- Document edge cases discovered in sessions
- Add troubleshooting section for frequent issues
- Include performance tips if latency is high

**Method**:
```python
# Generate improvement recommendations
improvements = []

# From error analysis
for error_category in error_categories:
    improvement = generate_error_handling_section(error_category)
    improvements.append(improvement)

# From tool usage
for tool_sequence in common_sequences:
    if is_efficient(tool_sequence):
        improvement = generate_example(tool_sequence)
    else:
        improvement = generate_optimization(tool_sequence)
    improvements.append(improvement)
```

#### 4.3 Reference Addition

**Based on knowledge gaps**, add reference files:

**When to add references**:
- Skill body exceeding 500 lines → move details to `references/`
- Repeated questions about same topic → create reference doc
- Complex procedures that aren't always needed → move to `references/advanced.md`
- API documentation frequently needed → add `references/api-docs.md`

**Method**:
```python
# Identify sections that should move to references
large_sections = find_large_sections(skill_body)
for section in large_sections:
    if section['lines'] > 100:
        reference_file = create_reference_file(section)
        replace_with_reference_link(skill_body, section, reference_file)
```

#### 4.4 Metadata Optimization

**Based on dependency analysis**, update metadata:

```yaml
metadata: {
  "clawdbot": {
    "always": false,  # Set to true if skill triggers in >50% of sessions
    "emoji": "🔧",
    "requires": {
      "bins": ["jq", "curl"],  # Add tools actually used
      "env": ["API_KEY"],      # Add env vars needed
      "anyBins": ["httpie", "curl"]  # Alternatives
    },
    "os": ["darwin", "linux"]  # If platform-specific
  }
}
```

**Method**:
1. Analyze tool usage to determine `requires.bins`
2. Check error logs for missing dependencies
3. Determine if skill should be `always: true` based on usage frequency
4. Add appropriate emoji based on skill category

### Phase 5: A/B Testing & Validation

**Objective**: Validate improvements before full rollout.

#### 5.1 Create Improved Version

Create side-by-side comparison:

```
skills/
├── api-testing/              # Original
│   └── SKILL.md
└── api-testing-v2/           # Improved
    └── SKILL.md
```

#### 5.2 Measure Impact

**Metrics to track**:
- **Triggering accuracy**: Does improved description trigger more appropriately?
- **Success rate**: Do sessions complete successfully more often?
- **Performance**: Are tasks faster with new instructions?
- **Error rate**: Do errors decrease with better error handling?
- **Token efficiency**: Is new version more concise?

**Method**:
```python
# Deploy improved skill to workspace
deploy_skill(agent_id, "api-testing-v2", workspace)

# Collect sessions over test period (7 days)
test_sessions = collect_sessions(agent_id, date_range="7d")

# Compare metrics
baseline_metrics = calculate_metrics(original_sessions)
test_metrics = calculate_metrics(test_sessions)

improvement = {
    'trigger_rate': test_metrics.triggers / baseline_metrics.triggers,
    'success_rate': test_metrics.successes / test_metrics.total,
    'avg_duration': test_metrics.avg_duration,
    'error_rate': test_metrics.errors / test_metrics.total
}
```

#### 5.3 Rollout Decision

**Decision criteria**:
- ✅ Trigger rate improved by >20% → ROLLOUT
- ✅ Success rate improved by >10% → ROLLOUT
- ✅ Error rate decreased by >30% → ROLLOUT
- ⚠️ No significant change → ITERATE
- ❌ Metrics degraded → ROLLBACK

### Phase 6: Continuous Evolution

**Objective**: Establish continuous improvement cycle.

#### 6.1 Automated Analysis Pipeline

**Setup**:
```bash
# Cron job to analyze sessions weekly
0 0 * * 0 /path/to/scripts/analyze-skills.sh

# analyze-skills.sh
#!/bin/bash
for agent in $(jq -r '.agents.list[].id' ~/.openclaw/openclaw.json); do
  python3 scripts/analyze-agent-sessions.py --agent "$agent" --days 7
done
```

**Output**: Weekly skill performance report.

#### 6.2 Evolution Triggers

**Auto-trigger skill evolution when**:
- Error rate for skill exceeds 15%
- Skill not triggered in last 30 days (may be obsolete)
- Skill triggers <10% of times it should (weak description)
- Average session duration with skill >2x baseline
- New user intent patterns detected (>10 similar queries)

#### 6.3 Version Control

**Track skill evolution**:
```bash
# In skill directory
skills/api-testing/
├── SKILL.md                    # Current version
├── .evolution/
│   ├── v1.0.0.md              # Original
│   ├── v1.1.0.md              # First improvement
│   ├── v2.0.0.md              # Major rewrite
│   └── changelog.md           # Evolution history
└── references/
```

**Changelog format**:
```markdown
# Skill Evolution Changelog

## v2.0.0 (2024-02-10)
**Trigger**: Error rate 25% → 8%
**Changes**:
- Added error handling for timeout scenarios
- Updated description with 5 new trigger phrases from real queries
- Moved advanced troubleshooting to references/advanced.md
**Impact**: Success rate +35%, avg duration -20%

## v1.1.0 (2024-01-15)
**Trigger**: Low triggering rate (45% of expected)
**Changes**:
- Rewrote description using actual user language
- Added 3 real-world examples from sessions
**Impact**: Trigger rate +60%
```

## Analysis Scripts

### collect-sessions.py

Extract relevant sessions for analysis.

**Location**: `scripts/collect-sessions.py`

**Usage**:
```bash
# Collect last 7 days for specific agent
python3 scripts/collect-sessions.py --agent developer --days 7

# Collect sessions where skill triggered
python3 scripts/collect-sessions.py --skill api-testing --days 30

# Collect sessions with errors
python3 scripts/collect-sessions.py --errors-only --days 7

# Collect sessions above latency threshold
python3 scripts/collect-sessions.py --latency 5000 --days 14
```

See `scripts/collect-sessions.py` for implementation.

### analyze-triggers.py

Analyze skill triggering patterns.

**Location**: `scripts/analyze-triggers.py`

**Usage**:
```bash
# Analyze what triggers a skill
python3 scripts/analyze-triggers.py --skill api-testing

# Output:
# Skill: api-testing
# Total triggers: 45
# Unique queries: 23
#
# Top triggering queries:
# 1. "test the API" (12 times)
# 2. "check if API works" (8 times)
# 3. "validate API responses" (6 times)
# ...
#
# Suggested description additions:
# - "test the API"
# - "check if API works"
# - "validate API responses"
```

### analyze-errors.py

Analyze error patterns when skill is active.

**Location**: `scripts/analyze-errors.py`

**Usage**:
```bash
# Analyze errors for specific skill
python3 scripts/analyze-errors.py --skill api-testing

# Output:
# Skill: api-testing
# Total sessions: 45
# Sessions with errors: 12 (27%)
#
# Error categories:
# 1. Missing file (5 occurrences)
#    - File not found: config.json
#    - Recommendation: Add file existence check to skill
#
# 2. Timeout (4 occurrences)
#    - API request timeout after 30s
#    - Recommendation: Document timeout handling
#
# 3. Permission denied (3 occurrences)
#    - Cannot execute script.sh
#    - Recommendation: Document chmod +x requirement
```

### analyze-performance.py

Analyze performance metrics.

**Location**: `scripts/analyze-performance.py`

**Usage**:
```bash
# Analyze performance for skill
python3 scripts/analyze-performance.py --skill api-testing

# Output:
# Skill: api-testing
# Sessions analyzed: 45
#
# Duration:
#   - Average: 3.2s
#   - P50: 2.8s
#   - P95: 7.1s
#   - P99: 12.4s
#
# Token usage:
#   - Average: 1,245 tokens/session
#   - Input: 890 tokens
#   - Output: 355 tokens
#
# Tool calls:
#   - Average: 3.4 calls/session
#   - Most used: Read (67%), Bash (45%), Grep (23%)
#
# Bottlenecks:
#   - High P95 latency suggests optimization needed
#   - Consider caching for Read operations
```

## Evolution Workflow

### Step 1: Identify Target Skill

Choose which skill to evolve:

```bash
# List all skills by usage frequency
python3 scripts/skill-usage-report.py --days 30

# Output:
# Skill Usage Report (Last 30 Days)
#
# 1. api-testing (234 triggers, 18% error rate) ⚠️
# 2. database-queries (189 triggers, 5% error rate) ✓
# 3. code-review (145 triggers, 12% error rate) ⚠️
# 4. file-processing (89 triggers, 22% error rate) ❌
# ...
```

**Priority**: Skills with high usage + high error rate.

### Step 2: Run Analysis Suite

```bash
# Run all analyses for target skill
SKILL="api-testing"

python3 scripts/analyze-triggers.py --skill $SKILL > analysis/triggers.txt
python3 scripts/analyze-errors.py --skill $SKILL > analysis/errors.txt
python3 scripts/analyze-performance.py --skill $SKILL > analysis/performance.txt
python3 scripts/analyze-tools.py --skill $SKILL > analysis/tools.txt
```

### Step 3: Generate Improvement Plan

Based on analysis outputs, create improvement plan:

```markdown
# Skill Improvement Plan: api-testing

## Current Issues
1. Error rate: 18% (target: <10%)
2. Weak triggering: Missing 12 common query patterns
3. Performance: P95 latency 7.1s (target: <5s)

## Proposed Changes

### Description Enhancement
**Add trigger phrases** (from triggers.txt):
- "test the API"
- "check if API works"
- "validate API responses"
- "debug API calls"
- "verify REST API"

### Error Handling
**Add sections for** (from errors.txt):
1. File existence checks before reading
2. Timeout handling with retry logic
3. Permission requirements documentation

### Performance Optimization
**Changes** (from performance.txt):
- Add caching guidance for repeated reads
- Suggest parallel API calls where possible
- Optimize tool usage sequence

### Tool Guidance
**Document common patterns** (from tools.txt):
- Read → Bash(curl) → Read (verify response)
- Recommended: Bash(curl -w) for timing info

## Expected Impact
- Error rate: 18% → <10%
- Trigger accuracy: +30%
- P95 latency: 7.1s → 5s
```

### Step 4: Implement Improvements

```bash
# Create backup
cp skills/$SKILL/SKILL.md skills/$SKILL/.evolution/v$(get-version).md

# Implement changes
# - Update description with new trigger phrases
# - Add error handling sections
# - Move large sections to references/
# - Update metadata
```

### Step 5: Test & Validate

```bash
# Deploy to test agent workspace
WORKSPACE=$(jq -r '.agents.list[0].workspace' ~/.openclaw/openclaw.json)
cp -r skills/$SKILL-improved $WORKSPACE/skills/$SKILL

# Monitor for 7 days
# Compare metrics with baseline
```

### Step 6: Rollout or Iterate

Based on validation results:
- ✅ Metrics improved → Rollout to all agents
- ⚠️ Mixed results → Iterate on improvements
- ❌ Metrics degraded → Rollback, rethink approach

## Best Practices

### Analysis Frequency

**Real-time** (continuous):
- Error tracking
- Performance monitoring
- Usage counting

**Daily**:
- Error rate checks
- Trigger accuracy

**Weekly**:
- Comprehensive skill analysis
- Improvement opportunity identification

**Monthly**:
- Full skill audit
- Major version updates
- Skill lifecycle decisions (retire/consolidate)

### Data-Driven Decisions

**Always base improvements on data**:
- ❌ "I think skill should trigger on X"
- ✅ "Data shows 15 sessions used phrasing X, adding to triggers"

**Measure before and after**:
- ❌ "Skill seems better now"
- ✅ "Error rate decreased from 18% to 8% after changes"

**Validate hypotheses**:
- ❌ "This should improve performance"
- ✅ "A/B test shows 20% latency reduction"

### Evolution Principles

1. **Incremental**: Small, measurable changes over time
2. **Data-driven**: Every change backed by session analysis
3. **Validated**: A/B test before full rollout
4. **Versioned**: Track evolution history
5. **Reversible**: Keep backups, can rollback
6. **Continuous**: Regular analysis and improvement cycle
7. **User-centric**: Improve based on actual user language and needs

## Advanced Techniques

### Semantic Analysis

Use NLP to identify user intent patterns:

```python
from sentence_transformers import SentenceTransformer

# Load user queries that triggered skill
queries = load_trigger_queries(skill_name)

# Embed queries
model = SentenceTransformer('all-MiniLM-L6-v2')
embeddings = model.encode(queries)

# Cluster to find patterns
clusters = cluster_queries(embeddings)

# For each cluster, generate representative trigger phrase
for cluster in clusters:
    representative = find_representative_query(cluster)
    suggested_triggers.append(representative)
```

### Causal Analysis

Identify what actually causes skill success/failure:

```python
# Correlate features with outcomes
features = [
    'skill_length',
    'num_examples',
    'num_trigger_phrases',
    'has_error_handling',
    'has_references',
    'tool_restrictions'
]

outcomes = ['success_rate', 'error_rate', 'avg_duration']

# Build regression model
for outcome in outcomes:
    model = train_regression(features, outcome)
    important_features = get_feature_importance(model)

    # Example output:
    # success_rate:
    #   - num_trigger_phrases: 0.45 (most important)
    #   - has_error_handling: 0.32
    #   - has_references: 0.15
```

### Automated Skill Generation

Generate new skills from session patterns:

```python
# Find recurring patterns that lack skills
patterns = find_recurring_patterns(all_sessions)

for pattern in patterns:
    if not has_relevant_skill(pattern):
        # Auto-generate skill draft
        skill_draft = generate_skill_from_pattern(pattern)

        # Requires human review before deployment
        save_for_review(skill_draft)
```

## Troubleshooting

**Issue**: Analysis scripts find no data
- **Check**: Session logs exist in `~/.openclaw/agents/*/sessions/*.jsonl`
- **Verify**: Date range includes recent activity
- **Solution**: Adjust date range or check agent ID

**Issue**: Error rate calculations seem wrong
- **Check**: Error definition in script matches your expectations
- **Verify**: Sessions are correctly filtered (only when skill active)
- **Solution**: Review error categorization logic

**Issue**: Improved skill performs worse
- **Cause**: Overfitting to specific patterns, lost generalization
- **Solution**: Rollback, use more diverse session data

**Issue**: Skill triggers too often after description update
- **Cause**: Trigger phrases too broad
- **Solution**: Add negative examples, be more specific

## Metrics Glossary

**Trigger rate**: % of sessions where skill triggered when relevant
**Success rate**: % of sessions that completed without errors
**Error rate**: % of sessions with errors when skill active
**Avg duration**: Mean time to complete task when skill active
**Token efficiency**: Output tokens / input tokens ratio
**Tool efficiency**: Successful tool calls / total tool calls

## Additional Resources

### Reference Files

- **`references/session-log-format.md`** - Complete JSONL format specification
- **`references/analysis-methods.md`** - Statistical analysis techniques
- **`references/evolution-case-studies.md`** - Real examples of skill evolution

### Scripts

- **`scripts/collect-sessions.py`** - Session log collection
- **`scripts/analyze-triggers.py`** - Trigger pattern analysis
- **`scripts/analyze-errors.py`** - Error pattern analysis
- **`scripts/analyze-performance.py`** - Performance metrics
- **`scripts/analyze-tools.py`** - Tool usage patterns
- **`scripts/generate-report.py`** - Comprehensive skill report

### Examples

- **`examples/evolution-workflow.md`** - Step-by-step evolution example
- **`examples/before-after-comparison.md`** - Skill improvement examples

---

**Remember**: Skills should continuously evolve based on how agents actually use them in the real world. Data-driven evolution ensures skills remain effective, accurate, and valuable.
