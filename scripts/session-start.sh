#!/bin/bash
set -euo pipefail

# SessionStart hook: version check + environment context
# Output goes to transcript so Claude sees it as context

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CACHE_FILE="$CLAUDE_PROJECT_DIR/.claude/openclaw-dev.local.md"

# --- Version info ---
local_version="unknown"
if [ -f "$PLUGIN_ROOT/.claude-plugin/plugin.json" ]; then
  local_version=$(sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$PLUGIN_ROOT/.claude-plugin/plugin.json" | head -1)
fi

# --- Git upgrade check (best-effort, 3s timeout) ---
upgrade_hint=""
if [ -d "$PLUGIN_ROOT/.git" ]; then
  # Fetch silently with timeout; ignore failures (offline, no remote, etc.)
  # Use timeout if available (coreutils), else skip fetch guard (git has its own tcp timeout)
  fetch_ok=false
  if command -v timeout >/dev/null 2>&1; then
    timeout 3 git -C "$PLUGIN_ROOT" fetch --quiet 2>/dev/null && fetch_ok=true
  else
    git -C "$PLUGIN_ROOT" fetch --quiet 2>/dev/null && fetch_ok=true
  fi
  if [ "$fetch_ok" = true ]; then
    local_head=$(git -C "$PLUGIN_ROOT" rev-parse HEAD 2>/dev/null)
    remote_head=$(git -C "$PLUGIN_ROOT" rev-parse origin/main 2>/dev/null || echo "")
    if [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
      behind=$(git -C "$PLUGIN_ROOT" rev-list --count HEAD..origin/main 2>/dev/null || echo "?")
      upgrade_hint=" ⚡ Update available (${behind} commits behind). Run: cd $PLUGIN_ROOT && git pull && bash install.sh"
    fi
  fi
fi

# --- Read cache ---
env_info=""
if [ ! -f "$CACHE_FILE" ]; then
  env_info="No local config. Run /status to initialize, or copy openclaw-dev.local.md.example to .claude/openclaw-dev.local.md."
else
  # Extract YAML frontmatter (between --- delimiters)
  frontmatter=$(sed -n '/^---$/,/^---$/p' "$CACHE_FILE" | sed '1d;$d')

  if [ -z "$frontmatter" ]; then
    env_info="Local config exists but has no YAML frontmatter. Run /status to initialize cache."
  else
    # Extract control_center_status (POSIX-compatible)
    cc_status=$(echo "$frontmatter" | sed -n 's/^control_center_status:[[:space:]]*//p' | head -1)

    # Extract gateway names (POSIX-compatible)
    gw_names=$(echo "$frontmatter" | sed -n 's/^[[:space:]]*-[[:space:]]*name:[[:space:]]*//p')
    gw_count=0
    if [ -n "$gw_names" ]; then
      gw_count=$(echo "$gw_names" | wc -l | tr -d ' ')
    fi

    if [ "$cc_status" = "installed" ]; then
      env_info="Local OpenClaw: installed."
    elif [ "$cc_status" = "not_installed" ]; then
      env_info="Local OpenClaw: not installed."
    fi

    if [ "$gw_count" -gt 0 ]; then
      gw_list=$(echo "$gw_names" | tr '\n' ', ' | sed 's/,[[:space:]]*$//')
      env_info="$env_info Remote gateways ($gw_count): $gw_list."
    fi
  fi
fi

# --- Output ---
echo "openclaw-dev v${local_version}.${env_info:+ $env_info}${upgrade_hint}"
