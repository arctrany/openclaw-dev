---
name: openclaw-agent-development
description: "This skill should be used when the user asks to create an OpenClaw agent, build agent for OpenClaw, configure agent behavior, or understand agent development. Examples: 'create an agent to validate code', 'build a testing agent', 'how do I configure agent frontmatter', 'write a system prompt for an agent', 'what tools should my agent have', 'OpenClaw agent best practices'. Covers agent structure, frontmatter configuration, system prompt design, triggering patterns, and tool restrictions."
metadata: {"clawdbot":{"always":false,"emoji":"🤖"}}
version: 1.0.0
---

# OpenClaw Agent Development

## Overview

Agents in OpenClaw are autonomous subprocesses that handle complex, multi-step tasks independently. Understanding agent structure, configuration, and system prompt design enables creating powerful autonomous capabilities for OpenClaw deployments.

**Key concepts:**
- Agents are autonomous workers, commands are user-initiated actions
- Markdown file format with YAML frontmatter configuration
- Triggering via description field with concrete examples
- System prompt defines agent behavior and expertise
- Model selection and tool restriction capabilities

## Agent Architecture

### What is an OpenClaw Agent?

An agent is a specialized subprocess configured with:
- **Identity**: Name and role description
- **Triggering conditions**: When the agent should activate
- **Capabilities**: Tools and model access
- **Behavior**: System prompt defining how it works
- **Presentation**: Visual color for UI identification

**Use agents for**:
- Multi-step autonomous workflows
- Specialized analysis tasks
- Code generation and review
- Validation and quality checks
- Complex decision-making processes

**Use commands for**:
- User-initiated one-time actions
- Quick utility functions
- Interactive workflows with user input

## Agent File Structure

### Complete Format

```markdown
---
name: agent-identifier
description: Use this agent when [triggering conditions]. Examples:

<example>
Context: [Situation description]
user: "[User request]"
assistant: "[How assistant should respond and use this agent]"
<commentary>
[Why this agent should be triggered]
</commentary>
</example>

<example>
[Additional example...]
</example>

model: inherit
color: blue
tools: ["Read", "Write", "Grep", "Bash"]
---

You are [agent role description]...

**Your Core Responsibilities:**
1. [Responsibility 1]
2. [Responsibility 2]

**Analysis Process:**
1. [Step one]
2. [Step two]

**Output Format:**
[What to return]
```

### File Location

**In plugins**: `plugin-name/agents/agent-name.md`

**In OpenClaw workspaces**: `<workspace>/agents/agent-name.md` (if supported)

All `.md` files in `agents/` directory are auto-discovered.

## Frontmatter Fields

### name (required)

Agent identifier used for namespacing and invocation.

**Format**: lowercase, numbers, hyphens only
**Length**: 3-50 characters
**Pattern**: Must start and end with alphanumeric

**Good examples**:
- `skill-reviewer`
- `plugin-validator`
- `code-analyzer`
- `deployment-checker`

**Bad examples**:
- `agent` (too generic)
- `-helper-` (starts/ends with hyphen)
- `my_agent` (underscores not allowed)
- `ag` (too short, <3 chars)

### description (required)

**This is the most critical field.** Defines when OpenClaw/Claude should trigger this agent.

**Must include**:
1. Triggering conditions ("Use this agent when...")
2. Multiple `<example>` blocks showing usage scenarios
3. Context, user request, and assistant response in each example
4. `<commentary>` explaining why agent triggers

**Format**:
```
Use this agent when [conditions]. Examples:

<example>
Context: [Scenario description]
user: "[What user says]"
assistant: "[How Claude should respond]"
<commentary>
[Why this agent is appropriate]
</commentary>
</example>

[More examples...]
```

**Best practices**:
- Include 2-4 concrete examples
- Show both proactive and reactive triggering
- Cover different phrasings of same intent
- Explain reasoning in commentary
- Be specific about when NOT to use the agent

**Example from skill-reviewer**:
```yaml
description: Use this agent when the user has created or modified an OpenClaw skill and needs quality review. Examples:

<example>
Context: User just created a new skill
user: "I've created a PDF processing skill"
assistant: "Great! Let me review the skill quality."
<commentary>
Skill created, proactively trigger skill-reviewer to ensure it follows best practices.
</commentary>
assistant: "I'll use the skill-reviewer agent to review the skill."
</example>
```

### model (required)

Which model the agent should use.

**Options**:
- `inherit` - Use same model as parent (recommended)
- `sonnet` - Claude Sonnet (balanced performance/cost)
- `opus` - Claude Opus (most capable, expensive)
- `haiku` - Claude Haiku (fast, cheap)

**Recommendation**: Use `inherit` unless agent needs specific model capabilities.

**When to override**:
- `haiku` for simple validation checks
- `opus` for complex analysis requiring maximum capability
- `sonnet` for standard autonomous work

### color (required)

Visual identifier for agent in UI.

**Options**: `blue`, `cyan`, `green`, `yellow`, `magenta`, `red`

**Guidelines**:
- Choose distinct colors for different agents in same plugin
- Use consistent colors for similar agent types
- **Blue/cyan**: Analysis, review, research
- **Green**: Success-oriented tasks, deployment
- **Yellow**: Caution, validation, warnings
- **Red**: Critical issues, security, errors
- **Magenta**: Creative work, generation

### tools (optional)

Restrict agent to specific tools (principle of least privilege).

**Format**: Array of tool names

```yaml
tools: ["Read", "Write", "Grep", "Bash"]
```

**Default**: If omitted, agent has access to all tools

**Common tool sets**:
- **Read-only analysis**: `["Read", "Grep", "Glob"]`
- **Code generation**: `["Read", "Write", "Grep", "Edit"]`
- **Testing**: `["Read", "Bash", "Grep"]`
- **Validation**: `["Read", "Grep", "Glob"]`
- **Full access**: Omit field or use `["*"]`

**Best practice**: Limit tools to minimum needed for security and clarity.

## System Prompt Design

The markdown body becomes the agent's system prompt. Write in second person, addressing the agent directly as "you".

### Structure Template

```markdown
You are [role] specializing in [domain].

**Your Core Responsibilities:**
1. [Primary responsibility]
2. [Secondary responsibility]
3. [Additional responsibilities...]

**Analysis Process:**
1. [Step one - what to do first]
2. [Step two - next action]
3. [Step three - continue...]
4. [Final step - completion]

**Quality Standards:**
- [Standard 1]
- [Standard 2]
- [Standard 3]

**Output Format:**
Provide results in this format:
- [Section 1]: [What to include]
- [Section 2]: [What to include]
- [Summary]: [What to conclude]

**Edge Cases:**
Handle these situations:
- [Edge case 1]: [How to handle]
- [Edge case 2]: [How to handle]

**When to Stop:**
Complete work when [completion criteria].
```

### Writing Best Practices

✅ **DO**:
- Write in second person ("You are...", "You will...", "Check...")
- Be specific about responsibilities and process
- Provide step-by-step workflow
- Define clear output format
- Include quality standards
- Address edge cases and error scenarios
- Keep under 10,000 characters
- Use imperative commands ("Analyze...", "Verify...", "Report...")

❌ **DON'T**:
- Write in first person ("I am...", "I will...")
- Be vague or generic about what agent does
- Omit process steps or workflow
- Leave output format undefined
- Skip quality guidance
- Ignore error cases
- Write overly long prompts (>10k chars)
- Use passive voice

### Example System Prompts

**Validation Agent**:
```markdown
You are a validation specialist for OpenClaw plugins.

**Your Core Responsibilities:**
1. Validate plugin structure and manifest
2. Check naming conventions and file locations
3. Verify component configuration
4. Identify security issues
5. Report findings with severity levels

**Analysis Process:**
1. Read plugin.json and verify required fields
2. Check directory structure matches conventions
3. Validate component files (skills, commands, agents)
4. Scan for hardcoded paths and security issues
5. Generate validation report

**Quality Standards:**
- All issues categorized by severity (critical, warning, info)
- Specific file paths and line numbers provided
- Clear remediation guidance for each issue
- No false positives

**Output Format:**
# Plugin Validation Report

## Critical Issues
- [Issue with file:line reference]

## Warnings
- [Warning with context]

## Recommendations
- [Improvement suggestion]

**Edge Cases:**
- Missing manifest: Report critical error
- Empty components: Warning, not error
- Custom paths: Validate they exist
```

**Code Review Agent**:
```markdown
You are an expert code reviewer specializing in quality, security, and best practices.

**Your Core Responsibilities:**
1. Analyze code structure and organization
2. Identify security vulnerabilities
3. Check adherence to coding standards
4. Assess test coverage
5. Provide actionable feedback

**Analysis Process:**
1. Read all changed files
2. Analyze code patterns and architecture
3. Scan for security issues (injection, XSS, etc.)
4. Check error handling and edge cases
5. Verify documentation and comments
6. Generate structured review

**Quality Standards:**
- Every issue includes file:line reference
- Security issues prioritized
- Suggestions are specific and actionable
- Positive feedback included for good patterns

**Output Format:**
# Code Review: [Component Name]

## Security Issues (Critical)
- [Issue at file.py:123]

## Code Quality
- [Improvement at file.js:45]

## Best Practices
- [Suggestion with example]

## Positive Observations
- [Good pattern at file.ts:67]
```

## Creating Agents

### Method 1: AI-Assisted Generation

Use this prompt pattern for creating agents:

```
Create an agent configuration for: "[YOUR DESCRIPTION]"

Requirements:
1. Extract core intent and responsibilities
2. Design expert persona for the domain
3. Create comprehensive system prompt with:
   - Clear behavioral boundaries
   - Specific methodologies
   - Edge case handling
   - Output format
4. Create identifier (lowercase, hyphens, 3-50 chars)
5. Write description with triggering conditions
6. Include 2-3 <example> blocks showing when to use

Return configuration in agent markdown format.
```

### Method 2: Manual Creation

1. **Define purpose**: What specific task does agent handle?
2. **Choose identifier**: 3-50 chars, lowercase, hyphens
3. **Write description**: Include triggering examples
4. **Select model**: Usually `inherit`
5. **Choose color**: For visual identification
6. **Define tools**: Minimum needed for task
7. **Write system prompt**: Use template above
8. **Save file**: `agents/agent-name.md`

### Method 3: Use scaffold-agent Command

Use the `scaffold-agent` command for interactive creation:

```
/scaffold-agent
```

This walks through all required fields and generates the agent file.

## Validation

### Identifier Validation

```
✅ Valid: skill-reviewer, code-analyzer, test-gen-v2
❌ Invalid: ag (too short), -start (starts with hyphen), my_agent (underscore)
```

**Rules**:
- 3-50 characters
- Lowercase letters, numbers, hyphens only
- Must start and end with alphanumeric
- No underscores, spaces, or special characters

### Description Validation

**Length**: 10-5,000 characters
**Must include**: Triggering conditions and examples
**Optimal**: 200-1,000 characters with 2-4 examples

### System Prompt Validation

**Length**: 20-10,000 characters
**Optimal**: 500-3,000 characters
**Structure**: Clear responsibilities, process, output format

## Integration with OpenClaw

### Agent Deployment

Agents in plugins are automatically discovered when plugin is installed to OpenClaw.

**Plugin structure**:
```
my-plugin/
├── .claude-plugin/plugin.json
└── agents/
    ├── validator.md
    └── reviewer.md
```

**Installation**:
```bash
# Copy/link plugin to OpenClaw
cp -r my-plugin ~/.openclaw/plugins/

# Or link for development
ln -s /path/to/my-plugin ~/.openclaw/plugins/my-plugin
```

### Triggering Agents

**Automatic triggering**: Agent activates when user request matches description examples

**Manual invocation**: User or main agent can request specific agent

**Example flow**:
1. User: "I've created a new skill, can you review it?"
2. Main agent recognizes pattern from skill-reviewer description
3. Main agent launches skill-reviewer agent
4. skill-reviewer performs analysis
5. skill-reviewer reports findings back

### Agent Coordination

Agents can work together:
- **Sequential**: Agent A completes, then Agent B starts
- **Parallel**: Multiple agents work simultaneously (if independent)
- **Hierarchical**: Main agent delegates to specialized sub-agents

**Example**:
```
User requests: "Build and deploy the plugin"

Main agent:
1. Launches build-agent (validates, tests)
2. Waits for build-agent completion
3. Launches deploy-agent (deploys to target)
4. Monitors both, reports to user
```

## Testing Agents

### Test Triggering

Verify agent triggers correctly:

1. Create test scenarios matching description examples
2. Use similar phrasing to examples
3. Check agent activates appropriately
4. Verify agent doesn't trigger on unrelated requests

### Test System Prompt

Ensure system prompt is effective:

1. Give agent typical task
2. Check it follows process steps
3. Verify output format is correct
4. Test edge cases mentioned in prompt
5. Confirm quality standards met

### Test Tool Restrictions

If tools are restricted:

1. Verify agent can complete tasks with given tools
2. Check agent doesn't attempt to use unavailable tools
3. Ensure tool set is sufficient but not excessive

## Common Patterns

### Validation Agent Pattern

```markdown
---
name: validator-name
description: Use this agent when validation needed. Examples: <example>...</example>
model: inherit
color: yellow
tools: ["Read", "Grep", "Glob"]
---

You are a validation specialist...

**Validation Checks:**
1. [Check 1]
2. [Check 2]

**Output Format:**
- Critical: [Issues]
- Warnings: [Issues]
- Passed: [Checks]
```

### Generator Agent Pattern

```markdown
---
name: generator-name
description: Use this agent when generation needed. Examples: <example>...</example>
model: inherit
color: magenta
tools: ["Read", "Write", "Grep"]
---

You are a code generator...

**Generation Process:**
1. Analyze requirements
2. Design structure
3. Generate code
4. Validate output

**Output Format:**
[Generated files with explanations]
```

### Analyzer Agent Pattern

```markdown
---
name: analyzer-name
description: Use this agent when analysis needed. Examples: <example>...</example>
model: inherit
color: blue
tools: ["Read", "Grep", "Glob", "Bash"]
---

You are an analysis specialist...

**Analysis Steps:**
1. Collect data
2. Identify patterns
3. Generate insights
4. Provide recommendations

**Output Format:**
## Analysis
[Findings]

## Recommendations
[Actionable suggestions]
```

## Best Practices Summary

**Agent Design**:
- Single responsibility per agent
- Clear, specific triggering conditions
- Comprehensive examples in description
- Appropriate model selection
- Minimal necessary tools

**System Prompts**:
- Second person voice ("You are...")
- Step-by-step process
- Clear output format
- Quality standards defined
- Edge cases addressed

**Testing**:
- Verify triggering works correctly
- Test with realistic scenarios
- Validate output format
- Check edge case handling
- Ensure tool restrictions work

## Quick Reference

### Minimal Agent

```markdown
---
name: simple-agent
description: Use this agent when... Examples: <example>user: "..."...</example>
model: inherit
color: blue
---

You are an agent that [does X].

Process:
1. [Step 1]
2. [Step 2]

Output: [What to provide]
```

### Frontmatter Fields

| Field | Required | Example |
|-------|----------|---------|
| name | Yes | skill-reviewer |
| description | Yes | Use when... <example>... |
| model | Yes | inherit |
| color | Yes | blue |
| tools | No | ["Read", "Grep"] |

### Tool Sets by Purpose

- **Validation**: `["Read", "Grep", "Glob"]`
- **Generation**: `["Read", "Write", "Edit"]`
- **Testing**: `["Read", "Bash", "Grep"]`
- **Analysis**: `["Read", "Grep", "Bash"]`
- **Full**: Omit field or `["*"]`

## Additional Resources

### Reference Files

For detailed guidance:
- **`references/system-prompt-examples.md`** - Complete system prompt patterns
- **`references/triggering-best-practices.md`** - Example format guidelines

### Example Files

Working examples:
- **`examples/validation-agent.md`** - Complete validation agent
- **`examples/generator-agent.md`** - Complete generation agent

Focus on clear triggering conditions, comprehensive system prompts, and appropriate tool restrictions for effective OpenClaw agents.
