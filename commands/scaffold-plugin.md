---
name: scaffold-plugin
description: Interactive workflow to create a new OpenClaw plugin from scratch. Walks through plugin structure, manifest creation, and component setup.
argument-hint: [plugin-name]
---

# Scaffold OpenClaw Plugin

You are guiding the user through creating a new OpenClaw plugin. Follow these steps strictly.

## Step 1: Gather Requirements

Use AskUserQuestion to gather:

1. **Plugin name** (if not provided as $1)
   - Must be kebab-case
   - Should be descriptive
   - Will be used for directory and manifest

2. **Plugin purpose**
   - What problem does it solve?
   - What capabilities does it provide?

3. **Components to include**
   - Skills? (for specialized knowledge)
   - Commands? (for user-initiated actions)
   - Agents? (for autonomous tasks)
   - Hooks? (for event-driven automation)
   - Scripts? (for utilities)

4. **Author information**
   - Name
   - Email (optional)

## Step 2: Validate Plugin Name

```bash
PLUGIN_NAME="${1:-<from AskUserQuestion>}"

# Validate kebab-case format
if ! echo "$PLUGIN_NAME" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "ERROR: Plugin name must be kebab-case (lowercase with hyphens)"
  echo "Examples: my-plugin, openclaw-toolkit, skill-helper"
  exit 1
fi

# Check if directory already exists
if [ -d "$PLUGIN_NAME" ]; then
  echo "WARNING: Directory $PLUGIN_NAME already exists"
  echo "Options:"
  echo "1. Choose a different name"
  echo "2. Merge with existing directory (advanced)"
  echo "3. Cancel"
fi
```

## Step 3: Create Directory Structure

Based on selected components, create the plugin structure:

```bash
# Core structure (always created)
mkdir -p "$PLUGIN_NAME/.claude-plugin"

# Optional component directories (based on user selection)
[ "$INCLUDE_SKILLS" = "true" ] && mkdir -p "$PLUGIN_NAME/skills"
[ "$INCLUDE_COMMANDS" = "true" ] && mkdir -p "$PLUGIN_NAME/commands"
[ "$INCLUDE_AGENTS" = "true" ] && mkdir -p "$PLUGIN_NAME/agents"
[ "$INCLUDE_HOOKS" = "true" ] && mkdir -p "$PLUGIN_NAME/hooks"
[ "$INCLUDE_SCRIPTS" = "true" ] && mkdir -p "$PLUGIN_NAME/scripts"
```

## Step 4: Create plugin.json Manifest

Write the manifest with gathered information:

```json
{
  "name": "<plugin-name>",
  "version": "0.1.0",
  "description": "<plugin-purpose>",
  "author": {
    "name": "<author-name>",
    "email": "<author-email>"
  },
  "keywords": ["openclaw", "<relevant>", "<keywords>"]
}
```

Save to `$PLUGIN_NAME/.claude-plugin/plugin.json`

## Step 5: Create README.md

Generate a comprehensive README:

```markdown
# <Plugin Name>

<Plugin purpose/description>

## Installation

### Local Development
\`\`\`bash
# Link to OpenClaw plugins directory
ln -s /path/to/<plugin-name> ~/.openclaw/plugins/<plugin-name>

# Or copy
cp -r <plugin-name> ~/.openclaw/plugins/
\`\`\`

### Claude Code
\`\`\`bash
# Install to Claude Code
cc --plugin-dir /path/to/<plugin-name>
\`\`\`

## Components

[List created components: skills, commands, agents, hooks]

## Usage

[Provide usage examples based on components]

## Development

### Adding Skills
\`\`\`bash
mkdir -p skills/skill-name
# Create SKILL.md following openclaw-skill-development patterns
\`\`\`

### Adding Commands
\`\`\`bash
# Create command file
touch commands/command-name.md
# Add frontmatter and instructions
\`\`\`

### Adding Agents
\`\`\`bash
# Create agent file
touch agents/agent-name.md
# Add frontmatter with examples and system prompt
\`\`\`

## Testing

### Local Testing
\`\`\`bash
# Test in OpenClaw
~/.openclaw/plugins/<plugin-name>

# Test in Claude Code
cc --plugin-dir /path/to/<plugin-name>
\`\`\`

## License

[License information]

## Author

<Author name> <<author-email>>
```

Save to `$PLUGIN_NAME/README.md`

## Step 6: Create .gitignore (Optional)

If user wants version control:

```
# Claude Code local settings
.claude/*.local.md

# macOS
.DS_Store

# Editor files
.vscode/
.idea/
*.swp
*.swo

# Node modules (if using npm)
node_modules/

# Python
__pycache__/
*.pyc
```

Save to `$PLUGIN_NAME/.gitignore`

## Step 7: Initialize Git (Optional)

If user wants version control:

```bash
cd "$PLUGIN_NAME"
git init
git add .
git commit -m "Initial plugin scaffold: <plugin-name>"
```

## Step 8: Create Component Templates

Based on selected components, create starter templates:

### If Skills Selected

Create example skill structure:
```bash
mkdir -p "$PLUGIN_NAME/skills/example-skill/references"
```

Create `skills/example-skill/SKILL.md`:
```markdown
---
name: example-skill
description: This skill should be used when the user asks to "trigger phrase 1", "trigger phrase 2". Provide comprehensive triggering conditions here.
metadata: {"clawdbot":{"always":false,"emoji":"🔧"}}
---

# Example Skill

[Instructions for the agent in imperative voice...]

## When to Use

[Already covered in description - don't duplicate]

## Process

1. [Step 1]
2. [Step 2]

## Additional Resources

See `references/` for detailed documentation.
```

### If Commands Selected

Create example command:
```markdown
---
description: Example command description
argument-hint: [arg1] [arg2]
allowed-tools: Read, Write
---

# Example Command

[Instructions FOR Claude about what to do when this command runs]

Process $1 with $2 parameters.
```

Save to `commands/example-command.md`

### If Agents Selected

Create example agent:
```markdown
---
name: example-agent
description: Use this agent when... Examples:

<example>
Context: [Scenario]
user: "[User request]"
assistant: "[Response and agent usage]"
<commentary>
[Why trigger this agent]
</commentary>
</example>

model: inherit
color: blue
tools: ["Read", "Grep"]
---

You are an example agent specializing in [domain].

**Your Core Responsibilities:**
1. [Responsibility 1]
2. [Responsibility 2]

**Process:**
1. [Step 1]
2. [Step 2]

**Output Format:**
[What to provide]
```

Save to `agents/example-agent.md`

### If Scripts Selected

Create example validation script:
```bash
#!/usr/bin/env bash
# Example validation script

set -euo pipefail

echo "Running validation..."

# Add validation logic here

echo "✓ Validation complete"
```

Save to `scripts/validate.sh` and make executable:
```bash
chmod +x "$PLUGIN_NAME/scripts/validate.sh"
```

## Step 9: Report Creation Summary

Provide a comprehensive summary:

```
✓ Plugin scaffolded: <plugin-name>
  Location: ./<plugin-name>
  Version: 0.1.0

Structure created:
  ✓ .claude-plugin/plugin.json (manifest)
  ✓ README.md (documentation)
  [✓ skills/ (with example-skill)]
  [✓ commands/ (with example-command)]
  [✓ agents/ (with example-agent)]
  [✓ hooks/]
  [✓ scripts/ (with validate.sh)]
  [✓ .gitignore]
  [✓ Git repository initialized]

Next steps:
1. Review and customize component templates
2. Add your actual skills/commands/agents
3. Test locally:
   - OpenClaw: ln -s $(pwd)/<plugin-name> ~/.openclaw/plugins/
   - Claude Code: cc --plugin-dir $(pwd)/<plugin-name>
4. Run validation: /validate-plugin <plugin-name>
5. Document usage in README.md

Component creation commands:
  - Create skill: /create-skill
  - Create agent: /scaffold-agent
  - Validate plugin: /validate-plugin <plugin-name>
```

## Step 10: Offer Next Actions

Ask user what they want to do next:

1. Create a skill for this plugin
2. Create a command for this plugin
3. Create an agent for this plugin
4. Validate the plugin structure
5. Done for now

Use AskUserQuestion to present these options.

## Important Notes

- Always use ${CLAUDE_PLUGIN_ROOT} in hook commands and scripts for portability
- Keep plugin.json minimal - only required fields initially
- Component templates are starting points - customize based on actual needs
- Test plugin installation before distribution
- Follow openclaw-plugin-architecture patterns for structure
- Use openclaw-skill-development guidelines for skills
- Use openclaw-agent-development guidelines for agents

## Validation Before Completion

Before finishing, verify:
- [ ] plugin.json exists and is valid JSON
- [ ] Directory name matches plugin name in manifest
- [ ] All selected component directories created
- [ ] README.md provides clear installation instructions
- [ ] Example templates follow best practices
- [ ] Scripts are executable (if created)
