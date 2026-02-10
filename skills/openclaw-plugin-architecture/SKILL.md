---
name: openclaw-plugin-architecture
description: This skill should be used when the user asks to "create an OpenClaw plugin", "structure OpenClaw plugin", "organize OpenClaw components", "plugin manifest for OpenClaw", "OpenClaw plugin.json", "how to build OpenClaw plugins", or needs guidance on OpenClaw plugin directory structure, component organization, manifest configuration, or plugin architecture best practices.
metadata: {"clawdbot":{"always":false,"emoji":"🏗️"}}
version: 1.0.0
---

# OpenClaw Plugin Architecture

## Overview

OpenClaw plugins extend agent capabilities through modular components. Understanding plugin structure, manifest configuration, and component organization enables creating powerful, maintainable OpenClaw extensions.

**Key concepts:**
- Standardized directory structure with `.claude-plugin/`
- Manifest-driven configuration in `plugin.json`
- Component-based organization (skills, commands, agents, hooks)
- Auto-discovery of components
- Workspace-aware skill resolution

## Plugin Directory Structure

Every OpenClaw plugin follows this organizational pattern:

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json          # Required: Plugin manifest
├── skills/                   # Agent skills (subdirectories)
│   └── skill-name/
│       └── SKILL.md         # Required for each skill
├── commands/                 # Slash commands (.md files)
├── agents/                   # Subagent definitions (.md files)
├── hooks/
│   └── hooks.json           # Event handler configuration
├── .mcp.json                # MCP server definitions (optional)
└── scripts/                 # Helper scripts and utilities
```

**Critical rules:**

1. **Manifest location**: The `plugin.json` manifest MUST be in `.claude-plugin/` directory
2. **Component locations**: All component directories (skills, commands, agents, hooks) MUST be at plugin root level, NOT nested inside `.claude-plugin/`
3. **Optional components**: Only create directories for components the plugin actually uses
4. **Naming convention**: Use kebab-case for all directory and file names

## Plugin Manifest (plugin.json)

The manifest defines plugin metadata and configuration. Located at `.claude-plugin/plugin.json`:

### Required Fields

```json
{
  "name": "plugin-name"
}
```

**Name requirements:**
- Use kebab-case format (lowercase with hyphens)
- Must be unique across installed plugins
- No spaces or special characters
- Example: `openclaw-dev`, `skill-toolkit`, `agent-builder`

### Recommended Metadata

```json
{
  "name": "plugin-name",
  "version": "1.0.0",
  "description": "Brief explanation of plugin purpose",
  "author": {
    "name": "Author Name",
    "email": "author@example.com"
  },
  "keywords": ["openclaw", "development", "toolkit"]
}
```

**Version format**: Follow semantic versioning (MAJOR.MINOR.PATCH)

**Keywords**: Use for plugin discovery and categorization

### Component Path Configuration

Specify custom paths for components (supplements default directories):

```json
{
  "name": "plugin-name",
  "commands": "./custom-commands",
  "agents": ["./agents", "./specialized-agents"],
  "skills": "./skills"
}
```

**Important**: Custom paths supplement defaults—they don't replace them. Components in both default directories and custom paths will load.

## Component Organization

### Skills

**Location**: `skills/` directory with subdirectories per skill
**Format**: Each skill in its own directory with `SKILL.md` file
**Auto-discovery**: All `SKILL.md` files in skill subdirectories load automatically

**Example structure**:
```
skills/
├── api-testing/
│   ├── SKILL.md
│   ├── scripts/
│   │   └── test-runner.py
│   └── references/
│       └── api-spec.md
└── database-migrations/
    ├── SKILL.md
    └── examples/
        └── migration-template.sql
```

**SKILL.md format**:
```markdown
---
name: skill-name
description: Comprehensive description with trigger phrases. This is the primary trigger mechanism.
metadata: {"clawdbot":{"always":false,"emoji":"🔧"}}
user-invocable: true
---

# Skill Title

Instructions for the agent in imperative voice...
```

**Key metadata fields**:
- `always: true` - Auto-inject into every session's system prompt
- `emoji` - Display emoji for the skill
- `requires.bins` - Required binaries (ALL must exist)
- `requires.anyBins` - At least ONE must exist
- `requires.env` - Required environment variables
- `os` - OS filter: `["darwin"]`, `["linux"]`, etc.

**Usage**: OpenClaw autonomously activates skills based on task context matching the description

For detailed skill development, see the `openclaw-skill-development` skill.

### Commands

**Location**: `commands/` directory
**Format**: Markdown files with YAML frontmatter
**Auto-discovery**: All `.md` files in `commands/` load automatically

**Example structure**:
```
commands/
├── review.md        # /review command
├── test.md          # /test command
└── deploy.md        # /deploy command
```

**File format**:
```markdown
---
description: Command description
allowed-tools: Read, Write, Bash(git:*)
---

Command implementation instructions FOR Claude...
```

**Usage**: Commands integrate as native slash commands accessible to users

### Agents

**Location**: `agents/` directory
**Format**: Markdown files with YAML frontmatter
**Auto-discovery**: All `.md` files in `agents/` load automatically

**Example structure**:
```
agents/
├── code-reviewer.md
├── test-generator.md
└── skill-validator.md
```

**File format**:
```markdown
---
name: agent-identifier
description: Use this agent when... Examples: <example>...</example>
model: inherit
color: blue
tools: ["Read", "Grep", "Bash"]
---

You are [agent role description]...

**Your Core Responsibilities:**
1. [Responsibility 1]
2. [Responsibility 2]

**Analysis Process:**
[Step-by-step workflow]

**Output Format:**
[What to return]
```

**Usage**: Users can invoke agents manually, or OpenClaw selects them automatically based on task context

For detailed agent development, see the `openclaw-agent-development` skill.

### Hooks

**Location**: `hooks/hooks.json` or inline in `plugin.json`
**Format**: JSON configuration defining event handlers
**Registration**: Hooks register automatically when plugin enables

**Example structure**:
```
hooks/
├── hooks.json           # Hook configuration
└── scripts/
    ├── validate.sh      # Hook script
    └── check-style.sh   # Hook script
```

**Configuration format**:
```json
{
  "PreToolUse": [{
    "matcher": "Write|Edit",
    "hooks": [{
      "type": "command",
      "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/scripts/validate.sh",
      "timeout": 30
    }]
  }]
}
```

**Available events**: PreToolUse, PostToolUse, Stop, SubagentStop, SessionStart, SessionEnd, UserPromptSubmit

**Usage**: Hooks execute automatically in response to OpenClaw events

### Scripts

**Location**: `scripts/` directory
**Format**: Executable scripts (bash, python, etc.)
**Purpose**: Validation, testing, automation utilities

**Example structure**:
```
scripts/
├── validate-skill.sh
├── verify-skill.sh
└── deploy-plugin.sh
```

**Best practices**:
- Make scripts executable: `chmod +x script.sh`
- Use portable shebang: `#!/usr/bin/env bash`
- Reference with `${CLAUDE_PLUGIN_ROOT}/scripts/script.sh`
- Include error handling and helpful output

## OpenClaw-Specific Concepts

### Skill Resolution Order

OpenClaw resolves skills in precedence order (highest first):

1. **Workspace skills**: `<agent-workspace>/skills/<skill-name>/SKILL.md`
2. **Managed skills**: `~/.openclaw/skills/<skill-name>/SKILL.md`
3. **Bundled skills**: `<openclaw-install>/skills/<skill-name>/SKILL.md`

Higher precedence overrides lower. Workspace skills are per-agent (configured via `openclaw.json` → `agents.list[].workspace`).

**Implication for plugins**: If your plugin provides skills, they can be:
- Copied to agent workspace for per-agent customization
- Installed to managed skills directory for global availability
- Bundled with OpenClaw installation

### Agent Workspaces

OpenClaw supports per-agent workspaces defined in `~/.openclaw/openclaw.json`:

```json
{
  "agents": {
    "list": [
      {
        "id": "developer",
        "workspace": "~/openclaw-workspaces/developer",
        "model": "claude-opus-4"
      },
      {
        "id": "analyst",
        "workspace": "~/openclaw-workspaces/analyst",
        "model": "claude-sonnet-4"
      }
    ]
  }
}
```

**Key files in workspace**:
- `skills/*/SKILL.md` - Skill definitions
- `SOUL.md` - Agent personality
- `TOOLS.md` - Tool usage guidance
- `AGENTS.md` - Workflow and delegation rules
- `MEMORY.md` - Persistent memory index
- `memory/*.md` - Memory entries

**Plugin integration**: Plugins can install skills to agent workspaces for agent-specific capabilities.

### Configuration Discovery

OpenClaw discovers configuration from:

1. **Global config**: `~/.openclaw/openclaw.json`
2. **Workspace config**: `<workspace>/openclaw.json` (if exists)
3. **Plugin manifests**: `.claude-plugin/plugin.json` in plugin directories

## Portable Path References

### Using ${CLAUDE_PLUGIN_ROOT}

Use `${CLAUDE_PLUGIN_ROOT}` environment variable for all intra-plugin path references:

```json
{
  "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/run.sh"
}
```

**Why it matters**: Plugins install in different locations depending on:
- User installation method (marketplace, local, custom)
- Operating system conventions
- User preferences

**Where to use it**:
- Hook command paths
- MCP server command arguments
- Script execution references
- Resource file paths

**Never use**:
- Hardcoded absolute paths (`/Users/name/plugins/...`)
- Relative paths from working directory (`./scripts/...` in commands)
- Home directory shortcuts (`~/plugins/...`)

### Path Resolution Examples

**In manifest JSON fields** (hooks, MCP servers):
```json
"command": "${CLAUDE_PLUGIN_ROOT}/scripts/tool.sh"
```

**In component files** (commands, agents, skills):
```markdown
Reference scripts at: ${CLAUDE_PLUGIN_ROOT}/scripts/helper.py
```

**In executed scripts**:
```bash
#!/bin/bash
# ${CLAUDE_PLUGIN_ROOT} available as environment variable
source "${CLAUDE_PLUGIN_ROOT}/lib/common.sh"
```

## File Naming Conventions

### Component Files

**Skills**: Use kebab-case directory names
- `api-testing/`
- `database-migrations/`
- `code-review/`

**Commands**: Use kebab-case `.md` files
- `create-skill.md` → `/create-skill`
- `deploy-plugin.md` → `/deploy-plugin`
- `validate-agent.md` → `/validate-agent`

**Agents**: Use kebab-case `.md` files describing role
- `skill-reviewer.md`
- `plugin-validator.md`
- `code-analyzer.md`

### Supporting Files

**Scripts**: Use descriptive kebab-case names with appropriate extensions
- `validate-skill.sh`
- `verify-deployment.py`
- `run-tests.js`

**Documentation**: Use kebab-case markdown files in skill references/
- `api-reference.md`
- `best-practices.md`
- `troubleshooting.md`

**Configuration**: Use standard names
- `hooks.json`
- `.mcp.json`
- `plugin.json`

## Auto-Discovery Mechanism

OpenClaw/Claude Code automatically discovers and loads components:

1. **Plugin manifest**: Reads `.claude-plugin/plugin.json` when plugin enables
2. **Skills**: Scans `skills/` for subdirectories containing `SKILL.md`
3. **Commands**: Scans `commands/` directory for `.md` files
4. **Agents**: Scans `agents/` directory for `.md` files
5. **Hooks**: Loads configuration from `hooks/hooks.json` or manifest
6. **MCP servers**: Loads configuration from `.mcp.json` or manifest

**Discovery timing**:
- Plugin installation: Components register
- Plugin enable: Components become available
- No restart required: Changes take effect on next session

## Development Workflow

### Creating a New Plugin

1. **Initialize structure**:
   ```bash
   mkdir -p my-plugin/.claude-plugin
   mkdir -p my-plugin/{skills,commands,agents,scripts}
   ```

2. **Create manifest**:
   ```json
   {
     "name": "my-plugin",
     "version": "0.1.0",
     "description": "Plugin description",
     "author": {"name": "Your Name"}
   }
   ```

3. **Add components**: Create skills, commands, agents as needed

4. **Test locally**: Install to OpenClaw and test functionality

5. **Iterate**: Refine based on usage and feedback

### Adding Skills to Plugin

1. Create skill directory: `mkdir -p skills/skill-name/{references,examples}`
2. Write `SKILL.md` with frontmatter and instructions
3. Add supporting resources (scripts, references, examples)
4. Test skill triggers correctly
5. Validate with skill-reviewer agent

### Adding Commands to Plugin

1. Create command file: `touch commands/command-name.md`
2. Write frontmatter with description and allowed-tools
3. Write instructions FOR Claude (not TO user)
4. Test command execution
5. Document arguments with argument-hint

### Adding Agents to Plugin

1. Create agent file: `touch agents/agent-name.md`
2. Write frontmatter with triggering examples
3. Write system prompt in second person
4. Test agent triggers on expected scenarios
5. Validate agent configuration

## Testing Plugins

### Local Testing

**Install to OpenClaw**:
```bash
# Link plugin to OpenClaw plugins directory
ln -s /path/to/my-plugin ~/.openclaw/plugins/my-plugin

# Or copy plugin
cp -r /path/to/my-plugin ~/.openclaw/plugins/
```

**Verify components load**:
- Skills: Check they trigger with expected phrases
- Commands: Run `/help` and verify commands listed
- Agents: Test with scenarios from examples
- Hooks: Use debug mode to see hook execution

### Component Testing

**Test skills**:
- Ask questions using trigger phrases from description
- Verify skill body loads and provides guidance
- Check references and scripts are accessible

**Test commands**:
- Run `/command-name` with various arguments
- Verify allowed-tools restrictions work
- Check file references and bash execution

**Test agents**:
- Create scenarios matching agent examples
- Verify agent triggers and executes correctly
- Check system prompt provides proper guidance

**Test hooks**:
- Trigger hook events
- Verify hooks execute correctly
- Check hook output is processed

## Best Practices

### Organization

1. **Logical grouping**: Group related components together
   - Create subdirectories in `commands/` for categories
   - Use consistent naming across components

2. **Minimal manifest**: Keep `plugin.json` lean
   - Only specify custom paths when necessary
   - Rely on auto-discovery for standard layouts

3. **Documentation**: Include README files
   - Plugin root: Overall purpose and installation
   - Component directories: Specific usage guidance

### Naming

1. **Consistency**: Use consistent naming across components
   - If command is `create-skill`, name related agent `skill-creator`
   - Match skill directory names to their purpose

2. **Clarity**: Use descriptive names that indicate purpose
   - Good: `api-integration-testing/`, `code-quality-checker.md`
   - Avoid: `utils/`, `misc.md`, `temp.sh`

3. **Length**: Balance brevity with clarity
   - Commands: 2-3 words (`review-code`, `run-tests`)
   - Agents: Describe role clearly (`code-reviewer`, `test-generator`)
   - Skills: Topic-focused (`error-handling`, `api-design`)

### Portability

1. **Always use ${CLAUDE_PLUGIN_ROOT}**: Never hardcode paths
2. **Test on multiple systems**: Verify on different environments
3. **Document dependencies**: List required tools and versions
4. **Avoid system-specific features**: Use portable constructs

### Maintenance

1. **Version consistently**: Update version in plugin.json for releases
2. **Document breaking changes**: Note changes affecting existing users
3. **Test thoroughly**: Verify all components work after changes
4. **Deprecate gracefully**: Mark old components before removal

## Common Patterns

### Minimal Plugin

Single command with no dependencies:
```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
└── commands/
    └── hello.md
```

### Skill-Focused Plugin

Plugin providing only skills:
```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    ├── skill-one/
    │   └── SKILL.md
    └── skill-two/
        └── SKILL.md
```

### Full-Featured Plugin

Complete plugin with all component types:
```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
├── commands/
├── agents/
├── hooks/
│   ├── hooks.json
│   └── scripts/
├── .mcp.json
└── scripts/
```

## Integration with OpenClaw

### Deployment to Agents

To deploy plugin skills to specific OpenClaw agents:

1. **Find agent workspace**:
   ```bash
   jq -r '.agents.list[] | "\(.id) — \(.workspace)"' ~/.openclaw/openclaw.json
   ```

2. **Copy skills to workspace**:
   ```bash
   cp -r my-plugin/skills/* <workspace>/skills/
   ```

3. **Restart gateway** (if openclaw.json changed):
   ```bash
   pkill -TERM openclaw-gateway
   ```

4. **Trigger new session**: Send `/new` to agent

5. **Verify skills loaded**:
   ```bash
   # Check session includes skills
   cat ~/.openclaw/agents/<agent-id>/sessions/sessions.json | \
     python3 -c "import sys, json; print('skill-name' in json.load(sys.stdin).get('agent:<agent-id>:main', {}).get('skillsSnapshot', {}).get('prompt', ''))"
   ```

### Global vs Per-Agent Skills

**Global skills** (`~/.openclaw/skills/`):
- Available to all agents
- Use for universal capabilities
- Managed centrally

**Per-agent skills** (`<workspace>/skills/`):
- Specific to one agent
- Use for specialized capabilities
- Isolated from other agents

**Plugin skills** (bundled):
- Distributed with plugin
- Can be copied to global or per-agent locations
- Provide reusable capabilities

## Troubleshooting

**Component not loading**:
- Verify file is in correct directory with correct extension
- Check YAML frontmatter syntax
- Ensure skill has `SKILL.md` (not `README.md`)
- Confirm plugin is enabled

**Path resolution errors**:
- Replace hardcoded paths with `${CLAUDE_PLUGIN_ROOT}`
- Verify paths are relative in manifest
- Check referenced files exist
- Test with `echo $CLAUDE_PLUGIN_ROOT` in scripts

**Auto-discovery not working**:
- Confirm directories are at plugin root (not in `.claude-plugin/`)
- Check file naming follows conventions
- Verify custom paths in manifest are correct
- Restart OpenClaw/Claude Code

**OpenClaw integration issues**:
- Check agent workspace path in `openclaw.json`
- Verify skills copied to correct workspace
- Ensure gateway restarted after config changes
- Check new session created (`/new` command)

## Additional Resources

### Reference Files

For detailed guidance, consult:
- **`references/plugin-examples.md`** - Complete plugin examples
- **`references/openclaw-integration.md`** - OpenClaw-specific integration patterns
- **`references/deployment-strategies.md`** - Plugin deployment approaches

### Example Files

Working examples in `examples/`:
- **`minimal-plugin/`** - Simple plugin structure
- **`full-plugin/`** - Complete plugin with all components

## Quick Reference

**Minimal plugin.json**:
```json
{"name": "my-plugin"}
```

**Standard plugin.json**:
```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "description": "Brief description",
  "author": {"name": "Author Name"},
  "keywords": ["openclaw", "keyword"]
}
```

**Directory structure**:
```
plugin-name/
├── .claude-plugin/plugin.json
├── skills/skill-name/SKILL.md
├── commands/command.md
├── agents/agent.md
└── scripts/script.sh
```

**Component naming**:
- Skills: `api-testing/` (kebab-case directory)
- Commands: `create-skill.md` (kebab-case file)
- Agents: `skill-reviewer.md` (kebab-case file)
- Scripts: `validate-skill.sh` (kebab-case file)

Focus on clear structure, portable paths, and comprehensive component organization for maintainable OpenClaw plugins.
