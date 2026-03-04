# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**openclaw-dev** — a Claude Code plugin (v2.0.0) that teaches code agents to develop, operate, and debug OpenClaw. Distributes to Codex, Qwen, and Gemini via `install.sh`; iFlow and OpenCode support is planned. Language: Chinese (zh-CN) for docs/user-facing content; English for code and config.

## Plugin Loading

Claude Code auto-discovers via `.claude-plugin/plugin.json`. No manual registration needed — skills, commands, and agents directories are loaded by convention.

For local development iteration:

```bash
claude --plugin-dir .    # run from repo root
```

## Common Commands

```bash
# Distribute to all detected code agents
bash install.sh

# Install to a specific project
bash install.sh --project /path/to/project

# Uninstall (supports --dry-run, --platforms, --project)
bash uninstall.sh

# Lint a skill definition
bash scripts/skill-lint.sh skills/<skill-name>

# Security scan (hardcoded credentials, sensitive paths)
bash scripts/security-scan.sh

# Model routing
python3 scripts/oc-route.py --list-presets
python3 scripts/oc-route.py sensitive-research -m "..." --pretty
```

No build step, no test framework, no package manager at repo root. The QA sub-plugin under `plugins/qa/` has its own `node_modules`.

## Architecture

### Single Source of Truth

`skills/`, `commands/`, `agents/` are canonical. Claude Code reads them directly via plugin auto-discovery. Other platforms (Codex, Qwen, Gemini) receive copies via `install.sh`.

### 4 Orthogonal Skills

| Skill | Scope | Version |
|-------|-------|---------|
| `openclaw-dev-knowledgebase` | Architecture, internals, theory, "how does X work" | 4.0.0 |
| `openclaw-node-operations` | Install, debug, fix, configure, diagnose | 3.0.0 |
| `openclaw-skill-development` | Skill lifecycle: create → validate → deploy → evolve (Phase 1-5 SOP) | 3.0.0 |
| `model-routing-governor` | Model routing policy, slot-based routing, provider constraints | 0.2.0 |

Knowledgebase = theory. Node-operations = hands-on. No overlap.

### Progressive Disclosure (3 Layers)

1. **Frontmatter `description`** (~100 words) — always evaluated for trigger matching
2. **SKILL.md body** (<5k words) — loaded when skill triggers
3. **`references/` subdirectory** — loaded on demand, unlimited size

### Closed-Loop Evolution

`/diagnose` → log analysis → pattern match → append to `fault-patterns.md` → next `/diagnose` is smarter.

### 13 User Commands + 3 Maintainer Commands

**User commands** (loaded by default):

`/diagnose` `/qa-agent` `/setup-node` `/lint-config` `/status` `/evolve-skill` `/create-skill` `/deploy-skill` `/validate-skill` `/list-skills` `/scaffold-agent` `/scaffold-plugin` `/fleet-ssh`

**Maintainer commands** (loaded when `role: maintainer` in `openclaw-dev.local.md`):

`/maintain-signals` `/maintain-evolve` `/maintain-sync`

Commands are Markdown files with YAML frontmatter in `commands/` (user) and `commands/maintainer/` (maintainer).

### 3 Agents

| Agent | Purpose |
|-------|---------|
| `openclaw-capability-evolver` | Analyzes QA results, evolves capabilities |
| `plugin-validator` | Validates plugin manifests, structure, quality |
| `skill-reviewer` | Reviews skill definitions for compliance |

## Development Guidelines

1. **Privacy first**: Run `bash scripts/security-scan.sh` before every commit. No credentials, personal paths, API keys, emails, or IPs may enter the repo. Treat this as a hard gate — scan failure blocks commit.
2. **Cross-platform compatible**: All skills, commands, and scripts must work across Claude Code, Codex, Qwen, iFlow, Gemini, and OpenCode. Never use platform-specific APIs or directives without a fallback. Test with `bash install.sh` to verify multi-platform distribution.
3. **Portable**: No absolute paths anywhere — skill files, scripts, commands, CLAUDE.md, AGENTS.md. Use `$HOME`, `~`, `$PROJECT_ROOT`, or relative paths. `bash scripts/security-scan.sh` enforces this.
4. **Out-of-the-box**: One command to install (`bash install.sh`), zero manual config required for basic use. Local config (`openclaw-dev.local.md`) is optional customization, never a prerequisite.
5. **Respect agent conventions**: Follow established agent ecosystem standards (MCP protocol, Skills/SKILL.md format, AGENTS.md for Codex, `.claude-plugin/` manifest). Do not invent custom mechanisms where a shared convention exists.
6. **Native first**: Prefer OpenClaw's native commands (`openclaw doctor`, `openclaw health`, `openclaw status --deep`, etc.) over custom scripts that replicate the same logic. AI's role is reasoning, orchestration, and fallback — parse, correlate, and format native command output; only build custom logic when native tools genuinely lack the capability. Never reimplement what OpenClaw already provides; doing so violates Single Source of Truth.
7. **Fewer steps, faster results (FSFR)**: Measure skill quality by real agent effort — reasoning turns, wrong-path retries, confusion points, context consumption. High effort means the skill's execution path is unclear or incomplete and must be improved. Design every skill and runbook for the weakest model that will execute it: use tiered execution (fast path first, fallback second), explicit degradation strategies, and decision tables over prose. This principle drives both evolution paths: `/evolve-skill` (OpenClaw product skills, signal source: session logs) and `/maintain-evolve` (openclaw-dev plugin skills, signal source: agent logs across Claude Code/Codex/Qwen). If a weak model cannot execute a runbook correctly, the runbook is broken.

## Iron Laws

1. **Zero hardcoding**: No absolute paths, emails, IPs, API keys, or model names in skill files. Runtime values come from `openclaw.env` and `openclaw.json`.
2. **Memory immutability**: `memory/` directories are append-only. Never delete, overwrite, or truncate.
3. **Doctor first**: Always run `openclaw doctor` before debugging.

## Skill File Conventions

- Each skill lives in `skills/<skill-name>/SKILL.md` with YAML frontmatter
- Required frontmatter: `name`, `description`, `version`; `metadata` strongly recommended (needed for `always`, `emoji`, `requires`)
- `name` must match its directory name
- `metadata` is a JSON object with `clawdbot` key containing `always`, `emoji`, and optional `requires`
- Body should stay under 500 lines; offload detail to `references/`

## Cross-Platform Distribution

| Platform | Detection | Target |
|----------|-----------|--------|
| Claude Code | `~/.claude` exists | Plugin auto-discovery (no copy needed) |
| Codex | `~/.codex` exists | `~/.codex/skills/` |
| Qwen | `~/.qwen` exists | `~/.qwen/skills/` |
| Gemini | `~/.gemini` + project indicators | `.agents/skills/` (per-project) |

## Local Config

Copy `openclaw-dev.local.md.example` to `.claude/openclaw-dev.local.md` and customize workspace paths, author info, and deployment directories. This file is gitignored.

### Multi-Gateway Management

Configure multiple Gateways in `.claude/openclaw-dev.local.md` under the `gateways:` key. Commands `/diagnose`, `/status`, and `/fleet-ssh` support `[gateway-name|ALL]` arguments for remote Gateway operations.
