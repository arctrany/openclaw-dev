---
name: scaffold-agent
description: Interactive workflow to create a new OpenClaw agent with proper frontmatter, triggering examples, and system prompt.
argument-hint: [agent-name] [plugin-path]
---

# Scaffold OpenClaw Agent

You are guiding the user through creating a new OpenClaw agent. Follow these steps strictly.

## Step 1: Determine Target Location

```bash
# If plugin path provided as $2
PLUGIN_PATH="${2:-.}"

# Verify it's a valid plugin
if [ ! -f "$PLUGIN_PATH/.claude-plugin/plugin.json" ]; then
  echo "ERROR: Not a valid plugin directory (missing .claude-plugin/plugin.json)"
  echo "Usage: /scaffold-agent [agent-name] [plugin-path]"
  echo "Or run from plugin directory: /scaffold-agent [agent-name]"
  exit 1
fi

# Create agents directory if it doesn't exist
mkdir -p "$PLUGIN_PATH/agents"
```

## Step 2: Gather Agent Requirements

Use AskUserQuestion to gather:

1. **Agent name** (if not provided as $1)
   - Must be kebab-case
   - 3-50 characters
   - Descriptive of agent role
   - Examples: skill-reviewer, code-analyzer, deployment-checker

2. **Agent purpose**
   - What specific task does this agent handle?
   - What expertise does it provide?
   - When should it be triggered?

3. **Triggering mode**
   - Proactive (auto-triggers when conditions met)
   - Reactive (user explicitly requests)
   - Both (hybrid)

4. **Model preference**
   - inherit (recommended - same as parent)
   - haiku (fast, simple tasks)
   - sonnet (balanced)
   - opus (complex analysis)

5. **Color**
   - blue (analysis, review)
   - cyan (research)
   - green (success-oriented)
   - yellow (validation, warnings)
   - magenta (creative, generation)
   - red (critical, security)

6. **Tool restrictions**
   - All tools (no restriction)
   - Read-only (Read, Grep, Glob)
   - Code generation (Read, Write, Edit, Grep)
   - Testing (Read, Bash, Grep)
   - Custom (user specifies)

## Step 3: Validate Agent Name

```bash
AGENT_NAME="${1:-<from AskUserQuestion>}"

# Validate format
if ! echo "$AGENT_NAME" | grep -qE '^[a-z0-9][a-z0-9-]{1,48}[a-z0-9]$'; then
  echo "ERROR: Agent name must be:"
  echo "  - 3-50 characters"
  echo "  - Lowercase letters, numbers, hyphens"
  echo "  - Start and end with alphanumeric"
  echo "Valid examples: skill-reviewer, code-gen, validator-v2"
  exit 1
fi

# Check if agent already exists
AGENT_FILE="$PLUGIN_PATH/agents/$AGENT_NAME.md"
if [ -f "$AGENT_FILE" ]; then
  echo "WARNING: Agent $AGENT_NAME already exists at $AGENT_FILE"
  echo "Options:"
  echo "1. Choose a different name"
  echo "2. Overwrite existing (will backup to .bak)"
  echo "3. Cancel"
fi
```

## Step 4: Generate Triggering Examples

Based on agent purpose and triggering mode, create 2-3 concrete examples:

**Proactive example template**:
```
<example>
Context: User has just completed [related action]
user: "[What user says after action]"
assistant: "[How assistant introduces agent usage]"
<commentary>
[Why this agent should trigger - what signals indicate need]
</commentary>
assistant: "[How assistant invokes agent]"
</example>
```

**Reactive example template**:
```
<example>
Context: User needs [specific capability]
user: "[Explicit request for agent functionality]"
assistant: "[How assistant responds and uses agent]"
<commentary>
[Why this agent is appropriate for request]
</commentary>
</example>
```

Create examples that:
- Show specific, realistic scenarios
- Cover different phrasings of same intent
- Explain reasoning in commentary
- Demonstrate when agent should/shouldn't trigger

## Step 5: Design System Prompt

Based on agent purpose, create structured system prompt:

```markdown
You are [role/expertise description].

**Your Core Responsibilities:**
1. [Primary responsibility - most important task]
2. [Secondary responsibility]
3. [Additional responsibilities...]

**Analysis/Work Process:**
1. [First step - what to do initially]
2. [Next step - how to proceed]
3. [Continue with specific steps...]
4. [Final step - how to conclude]

**Quality Standards:**
- [Standard 1 - what constitutes good work]
- [Standard 2]
- [Standard 3]

**Output Format:**
Provide results in this format:
- [Section 1]: [What to include]
- [Section 2]: [What to include]
- [Summary/Conclusion]: [Final output]

**Edge Cases to Handle:**
- [Edge case 1]: [How to handle]
- [Edge case 2]: [How to handle]

**When to Complete:**
Finish work when [specific completion criteria].
```

**System prompt guidelines**:
- Use second person ("You are...", "Check...", "Verify...")
- Be specific about process steps
- Define clear output format
- Address common edge cases
- Keep under 10,000 characters
- Focus on "how" not just "what"

## Step 6: Determine Tool Set

Based on user selection:

**All tools**: Omit `tools` field from frontmatter

**Read-only analysis**:
```yaml
tools: ["Read", "Grep", "Glob"]
```

**Code generation**:
```yaml
tools: ["Read", "Write", "Edit", "Grep"]
```

**Testing**:
```yaml
tools: ["Read", "Bash", "Grep", "Glob"]
```

**Validation**:
```yaml
tools: ["Read", "Grep", "Glob"]
```

**Custom**: User specifies exact tools

## Step 7: Write Agent File

Combine all elements into agent file:

```markdown
---
name: <agent-name>
description: Use this agent when <triggering-conditions>. Examples:

<example>
Context: <scenario>
user: "<user-request>"
assistant: "<assistant-response>"
<commentary>
<reasoning>
</commentary>
</example>

<example>
<second-example>
</example>

[<third-example if needed>]

model: <inherit|haiku|sonnet|opus>
color: <blue|cyan|green|yellow|magenta|red>
[tools: [<tool-list>]]
---

<system-prompt>
```

Save to `$PLUGIN_PATH/agents/$AGENT_NAME.md`

## Step 8: Validate Agent File

Run validation checks:

```bash
AGENT_FILE="$PLUGIN_PATH/agents/$AGENT_NAME.md"

# 1. File exists
test -f "$AGENT_FILE" && echo "✓ File created" || echo "✗ File missing"

# 2. Has frontmatter
head -1 "$AGENT_FILE" | grep -q '^---$' && echo "✓ Frontmatter present" || echo "✗ Missing frontmatter"

# 3. Required fields present
grep -q '^name:' "$AGENT_FILE" && echo "✓ Has name field" || echo "✗ Missing name"
grep -q '^description:' "$AGENT_FILE" && echo "✓ Has description" || echo "✗ Missing description"
grep -q '^model:' "$AGENT_FILE" && echo "✓ Has model field" || echo "✗ Missing model"
grep -q '^color:' "$AGENT_FILE" && echo "✓ Has color field" || echo "✗ Missing color"

# 4. Has examples in description
grep -q '<example>' "$AGENT_FILE" && echo "✓ Has triggering examples" || echo "✗ Missing examples"

# 5. Name matches filename
FILE_NAME=$(basename "$AGENT_FILE" .md)
AGENT_NAME_IN_FILE=$(grep '^name:' "$AGENT_FILE" | sed 's/name: *//')
[ "$FILE_NAME" = "$AGENT_NAME_IN_FILE" ] && echo "✓ Name matches file" || echo "✗ Name mismatch"

# 6. Has system prompt
PROMPT_LINES=$(sed -n '/^---$/,/^---$/!p' "$AGENT_FILE" | wc -l)
[ "$PROMPT_LINES" -gt 10 ] && echo "✓ Has system prompt" || echo "✗ System prompt too short"
```

## Step 9: Report Creation Summary

Provide comprehensive summary:

```
✓ Agent created: <agent-name>
  Location: <plugin-path>/agents/<agent-name>.md
  Model: <selected-model>
  Color: <selected-color>
  Tools: <tool-set or "all">

Triggering:
  Mode: <proactive|reactive|hybrid>
  Examples: <count> scenarios defined

System Prompt:
  Length: <character-count> characters
  Structure: ✓ Responsibilities, Process, Output Format

Validation:
  [✓ or ✗ for each check]

Next steps:
1. Review and refine triggering examples
2. Test agent with realistic scenarios
3. Adjust system prompt based on testing
4. Update plugin README.md to document agent

Testing command:
  Create scenarios matching your examples and verify agent triggers
```

## Step 10: Offer Testing Guidance

Provide specific test scenarios based on created examples:

```
To test this agent:

Scenario 1 (from example 1):
  Setup: <context from example>
  Say: "<user quote from example>"
  Expected: Agent should trigger and <expected behavior>

Scenario 2 (from example 2):
  Setup: <context from example>
  Say: "<user quote from example>"
  Expected: Agent should <expected behavior>

Negative test:
  Say: "<unrelated request>"
  Expected: Agent should NOT trigger

If agent doesn't trigger:
- Check description includes specific trigger phrases
- Verify examples match real usage patterns
- Add more examples covering different phrasings
```

## Important Guidelines

**Description Best Practices**:
- Include 2-4 concrete examples
- Use actual user phrasing in examples
- Explain reasoning in commentary
- Show both when to trigger and when not to

**System Prompt Best Practices**:
- Write in second person ("You are...")
- Provide step-by-step process
- Define clear output format
- Address edge cases
- Keep focused and concise

**Tool Selection**:
- Grant minimum tools needed
- Read-only for analysis tasks
- Write access only when generating/modifying
- Bash only for testing/validation

**Model Selection**:
- Use `inherit` unless specific need
- `haiku` for simple validation
- `opus` for complex reasoning
- `sonnet` for balanced tasks

## Validation Checklist

Before completing, verify:
- [ ] Agent name is valid (3-50 chars, kebab-case)
- [ ] Description includes triggering conditions
- [ ] 2-4 concrete examples with commentary
- [ ] Model field is valid value
- [ ] Color field is valid color
- [ ] Tools are appropriate for task
- [ ] System prompt is comprehensive
- [ ] File saved in agents/ directory
- [ ] Name matches filename

## Additional Resources

For agent development best practices, see:
- openclaw-agent-development skill
- plugin-dev agent-development skill
- Existing agents in this plugin as examples
