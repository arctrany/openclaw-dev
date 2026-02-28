#!/bin/bash
# openclaw-dev install script — one-click setup for all code agent platforms
# Usage: bash install.sh [target-project-dir] [--platforms claude,qwen,codex,gemini]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"
PLATFORMS="${2:-auto}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 openclaw-dev installer"
echo "   Source:  $SCRIPT_DIR"
echo "   Target:  $TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

INSTALLED=0
SKIPPED=0

# ─────────────────────────────────────────────
# Claude Code
# Extension model: .claude/commands/*.md + CLAUDE.md
# No native SKILL.md support; uses project-level commands
# ─────────────────────────────────────────────
install_claude_code() {
  echo "📦 Claude Code"
  
  # Commands → .claude/commands/
  mkdir -p "$TARGET/.claude/commands"
  for cmd in "$SCRIPT_DIR/commands/"*.md; do
    name=$(basename "$cmd" .md)
    ln -sf "$cmd" "$TARGET/.claude/commands/$name.md"
  done
  echo "   ✅ Commands: $(ls "$TARGET/.claude/commands/"*.md 2>/dev/null | wc -l | tr -d ' ') linked to .claude/commands/"

  # Skills knowledge → append to CLAUDE.md as reference
  if [ ! -f "$TARGET/CLAUDE.md" ]; then
    cat > "$TARGET/CLAUDE.md" << 'CLAUDEMD'
# Project Instructions

## OpenClaw Dev Skills

This project has openclaw-dev skills installed. For OpenClaw development tasks, reference the following skill files:

CLAUDEMD
  fi

  # Add skill paths if not already present
  if ! grep -q "openclaw-dev-knowledgebase" "$TARGET/CLAUDE.md" 2>/dev/null; then
    cat >> "$TARGET/CLAUDE.md" << CLAUDEMD

### OpenClaw Skills (read these for OpenClaw tasks)
- Architecture & Knowledge: $SCRIPT_DIR/skills/openclaw-dev-knowledgebase/SKILL.md
- Node Operations: $SCRIPT_DIR/skills/openclaw-node-operations/SKILL.md  
- Skill Development: $SCRIPT_DIR/skills/openclaw-skill-development/SKILL.md
CLAUDEMD
    echo "   ✅ CLAUDE.md: skill paths added"
  else
    echo "   ⏭️  CLAUDE.md: skill paths already present"
  fi

  INSTALLED=$((INSTALLED + 1))
}

# ─────────────────────────────────────────────
# Qwen (Tongyi Lingma / Qwen Code)
# Extension model: .qwen/skills/<name>/SKILL.md (project-level)
#                  ~/.qwen/skills/ (user-level)
# Requires settings.json: experimental.skills = true
# ─────────────────────────────────────────────
install_qwen() {
  echo "📦 Qwen"

  mkdir -p "$TARGET/.qwen/skills"
  for skill in "$SCRIPT_DIR/skills/openclaw-"*/; do
    name=$(basename "$skill")
    ln -sf "$skill" "$TARGET/.qwen/skills/$name"
    echo "   ✅ Skill: .qwen/skills/$name"
  done

  # Check if experimental.skills is enabled
  if [ -f "$HOME/.qwen/settings.json" ]; then
    if jq -e '.experimental.skills' "$HOME/.qwen/settings.json" 2>/dev/null | grep -q "true"; then
      echo "   ✅ experimental.skills = true (already enabled)"
    else
      echo "   ⚠️  experimental.skills not enabled in ~/.qwen/settings.json"
      echo "      Add: \"experimental\": { \"skills\": true }"
    fi
  else
    echo "   ⚠️  ~/.qwen/settings.json not found (Qwen may not be installed)"
  fi

  INSTALLED=$((INSTALLED + 1))
}

# ─────────────────────────────────────────────
# Codex (OpenAI)
# Extension model: ~/.codex/skills/<name>/SKILL.md (user-level)
#                  .codex/skills/<name>/SKILL.md (project-level)
# Optional: agents/openai.yaml for metadata
# ─────────────────────────────────────────────
install_codex() {
  echo "📦 Codex"

  mkdir -p "$TARGET/.codex/skills"
  for skill in "$SCRIPT_DIR/skills/openclaw-"*/; do
    name=$(basename "$skill")
    ln -sf "$skill" "$TARGET/.codex/skills/$name"
    echo "   ✅ Skill: .codex/skills/$name"
  done

  # Check codex is installed
  if command -v codex >/dev/null 2>&1; then
    echo "   ✅ codex CLI found: $(which codex)"
  else
    echo "   ⚠️  codex CLI not found in PATH"
  fi

  INSTALLED=$((INSTALLED + 1))
}

# ─────────────────────────────────────────────
# Gemini (Antigravity)
# Extension model: .agents/skills/<name>/SKILL.md (project-level)
#                  .agents/workflows/*.md (workflows)
# ─────────────────────────────────────────────
install_gemini() {
  echo "📦 Gemini (Antigravity)"

  mkdir -p "$TARGET/.agents/skills"
  for skill in "$SCRIPT_DIR/skills/openclaw-"*/; do
    name=$(basename "$skill")
    ln -sf "$skill" "$TARGET/.agents/skills/$name"
    echo "   ✅ Skill: .agents/skills/$name"
  done

  # Also link commands as workflows
  mkdir -p "$TARGET/.agents/workflows"
  for cmd in "$SCRIPT_DIR/commands/"*.md; do
    name=$(basename "$cmd")
    ln -sf "$cmd" "$TARGET/.agents/workflows/$name"
  done
  echo "   ✅ Workflows: $(ls "$TARGET/.agents/workflows/"*.md 2>/dev/null | wc -l | tr -d ' ') linked"

  INSTALLED=$((INSTALLED + 1))
}

# ─────────────────────────────────────────────
# Auto-detect and install
# ─────────────────────────────────────────────
if [ "$PLATFORMS" = "auto" ]; then
  echo "🔍 Auto-detecting platforms..."
  echo ""

  # Claude Code
  if command -v claude >/dev/null 2>&1 || [ -d "$HOME/.claude" ]; then
    install_claude_code
  else
    echo "⏭️  Claude Code: not detected"
    SKIPPED=$((SKIPPED + 1))
  fi
  echo ""

  # Qwen
  if command -v qwen >/dev/null 2>&1 || [ -d "$HOME/.qwen" ]; then
    install_qwen
  else
    echo "⏭️  Qwen: not detected"
    SKIPPED=$((SKIPPED + 1))
  fi
  echo ""

  # Codex
  if command -v codex >/dev/null 2>&1 || [ -d "$HOME/.codex" ]; then
    install_codex
  else
    echo "⏭️  Codex: not detected"
    SKIPPED=$((SKIPPED + 1))
  fi
  echo ""

  # Gemini/Antigravity
  if [ -d "$HOME/.gemini" ]; then
    install_gemini
  else
    echo "⏭️  Gemini: not detected"
    SKIPPED=$((SKIPPED + 1))
  fi
  echo ""
else
  IFS=',' read -ra PLATS <<< "$PLATFORMS"
  for p in "${PLATS[@]}"; do
    case "$p" in
      claude) install_claude_code ;;
      qwen) install_qwen ;;
      codex) install_codex ;;
      gemini) install_gemini ;;
      *) echo "❌ Unknown platform: $p" ;;
    esac
    echo ""
  done
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Installed: $INSTALLED platforms"
[ "$SKIPPED" -gt 0 ] && echo "⏭️  Skipped:   $SKIPPED platforms (not detected)"
echo ""
echo "Verify:"
[ -d "$TARGET/.claude/commands" ] && echo "  Claude Code: open project in Claude Code, /diagnose"
[ -d "$TARGET/.qwen/skills" ] && echo "  Qwen:        open project in Qwen, ask about OpenClaw"
[ -d "$TARGET/.codex/skills" ] && echo "  Codex:       open project in Codex, ask about OpenClaw"
[ -d "$TARGET/.agents/skills" ] && echo "  Gemini:      open project in Antigravity, ask about OpenClaw"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
