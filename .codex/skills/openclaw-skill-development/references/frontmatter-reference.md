# OpenClaw Skill Frontmatter Reference

## Required Fields

```yaml
name: my-skill-name
description: What this skill does and when to trigger it.
```

## Optional Fields

```yaml
metadata: {"clawdbot":{"always":false,"emoji":"🔧","requires":{"bins":["jq"],"anyBins":["codex","claude"],"env":["API_KEY"],"config":["skills.entries.my-skill"]},"install":[{"kind":"brew","formula":"jq"}],"os":["darwin"],"skillKey":"my-skill","primaryEnv":"MY_API_KEY","homepage":"https://example.com"}}
user-invocable: true
```

## Metadata Fields Detail

| Path | Type | Default | Description |
|------|------|---------|-------------|
| `clawdbot.always` | boolean | false | Inject into every session prompt |
| `clawdbot.emoji` | string | — | Display emoji |
| `clawdbot.skillKey` | string | — | Key in `openclaw.json` → `skills.entries.<key>` for per-skill config |
| `clawdbot.primaryEnv` | string | — | Primary env var; skill hidden if unset |
| `clawdbot.os` | string[] | all | Restrict to OS: `["darwin"]`, `["linux"]` |
| `clawdbot.homepage` | string | — | Link for skill info |
| `clawdbot.requires.bins` | string[] | — | ALL must exist in PATH |
| `clawdbot.requires.anyBins` | string[] | — | At least ONE must exist |
| `clawdbot.requires.env` | string[] | — | Required env vars |
| `clawdbot.requires.config` | string[] | — | Required config paths |
| `clawdbot.install` | array | — | Auto-install specs |

## Install Spec Kinds

| Kind | Fields | Example |
|------|--------|---------|
| `brew` | `formula`, `bins` | `{"kind":"brew","formula":"jq","bins":["jq"]}` |
| `node` | `package`, `bins` | `{"kind":"node","package":"typescript","bins":["tsc"]}` |
| `go` | `module`, `bins` | `{"kind":"go","module":"github.com/x/y","bins":["y"]}` |
| `uv` | `package`, `bins` | `{"kind":"uv","package":"ruff","bins":["ruff"]}` |
| `download` | `url`, `targetDir`, `extract`, `stripComponents` | `{"kind":"download","url":"https://...","targetDir":"/usr/local/bin"}` |

## Invocation Policy

| Frontmatter | Effect |
|-------------|--------|
| (omitted) | Model-triggered only (based on description match) |
| `user-invocable: true` | User can trigger via `/skill-name` AND model can auto-trigger |
| `user-invocable: true` + body has `disable-model-invocation: true` | User-only, model cannot auto-trigger |

## Resolution Precedence

1. `<agent-workspace>/skills/` — highest priority, per-agent
2. `~/.openclaw/skills/` — managed/global skills
3. `<openclaw-install>/skills/` — bundled with package
4. `skills.load.extraDirs` in config — lowest priority

Same-name skill at higher level shadows lower level.
