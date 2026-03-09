#!/usr/bin/env bash
# Wrapper — delegates to the canonical script in skills/openclaw-skill-development/scripts/
exec "$(cd "$(dirname "$0")/.." && pwd)/skills/openclaw-skill-development/scripts/validate-skill.sh" "$@"
