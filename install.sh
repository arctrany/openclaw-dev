#!/usr/bin/env bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# openclaw-dev — Install OpenClaw development skills to your code agents
#
# Install:
#   git clone https://github.com/arctrany/openclaw-dev.git
#   cd openclaw-dev && bash install.sh
#
# Update:
#   cd openclaw-dev && git pull && bash install.sh
#
# Per-project:
#   bash install.sh --project /path/to/project
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/skills"
COMMANDS_DIR="$SCRIPT_DIR/commands"
VERSION=$(grep -m1 "^version:" "$SKILLS_DIR/openclaw-dev-knowledgebase/SKILL.md" 2>/dev/null | sed 's/version: *//' || echo "unknown")

echo ""
echo "  ┌──────────────────────────────────────┐"
echo "  │  🔧 openclaw-dev installer v$VERSION       │"
echo "  │  Skills for OpenClaw development     │"
echo "  └──────────────────────────────────────┘"
echo ""

INSTALLED=0

# Helper: copy skills to target dir (overwrite if exists)
copy_skills() {
  local target="$1"
  mkdir -p "$target"
  for skill in "$SKILLS_DIR"/*/; do
    local name=$(basename "$skill")
    rm -rf "$target/$name"
    cp -rp "$skill" "$target/$name"
  done
}

# Helper: copy commands to target dir
copy_commands() {
  local target="$1"
  mkdir -p "$target"
  for cmd in "$COMMANDS_DIR/"*.md; do
    cp -f "$cmd" "$target/$(basename "$cmd")"
  done
}

# ─────────────────────────────────────────
# Claude Code
# ─────────────────────────────────────────
install_claude() {
  [ ! -d "$HOME/.claude" ] && { echo "  ⏭  Claude Code — not detected"; return; }
  echo "  📦 Claude Code"

  copy_commands "$HOME/.claude/commands"
  echo "     ✅ $(ls "$HOME/.claude/commands/"*.md | wc -l | tr -d ' ') commands → ~/.claude/commands/"

  # User-level CLAUDE.md — only add once
  if ! grep -q "openclaw-dev" "$HOME/.claude/CLAUDE.md" 2>/dev/null; then
    cat >> "$HOME/.claude/CLAUDE.md" << 'EOF'

## OpenClaw Dev Skills
For OpenClaw tasks, read the skill files in ~/.claude/commands/ (slash commands like /diagnose, /setup-node, /lint-config).
For deep knowledge, read the SKILL.md files in the openclaw-dev repo's skills/ directory.
EOF
    echo "     ✅ ~/.claude/CLAUDE.md updated"
  else
    echo "     ⏭  ~/.claude/CLAUDE.md already configured"
  fi
  INSTALLED=$((INSTALLED + 1))
}

# ─────────────────────────────────────────
# Qwen
# ─────────────────────────────────────────
install_qwen() {
  [ ! -d "$HOME/.qwen" ] && { echo "  ⏭  Qwen — not detected"; return; }
  echo "  📦 Qwen"

  copy_skills "$HOME/.qwen/skills"
  echo "     ✅ $(ls -d "$SKILLS_DIR"/*/ | wc -l | tr -d ' ') skills → ~/.qwen/skills/"

  if [ -f "$HOME/.qwen/settings.json" ]; then
    if jq -e '.experimental.skills == true' "$HOME/.qwen/settings.json" >/dev/null 2>&1; then
      echo "     ✅ experimental.skills enabled"
    else
      echo "     ⚠️  Run: jq '.experimental.skills=true' ~/.qwen/settings.json | sponge ~/.qwen/settings.json"
    fi
  fi
  INSTALLED=$((INSTALLED + 1))
}

# ─────────────────────────────────────────
# Codex (OpenAI)
# ─────────────────────────────────────────
install_codex() {
  [ ! -d "$HOME/.codex" ] && { echo "  ⏭  Codex — not detected"; return; }
  echo "  📦 Codex"

  copy_skills "$HOME/.codex/skills"
  echo "     ✅ $(ls -d "$SKILLS_DIR"/*/ | wc -l | tr -d ' ') skills → ~/.codex/skills/"

  command -v codex >/dev/null 2>&1 && echo "     ✅ codex CLI: $(which codex)"
  INSTALLED=$((INSTALLED + 1))
}

# ─────────────────────────────────────────
# Gemini (Antigravity) — per-project install
# ─────────────────────────────────────────
install_gemini() {
  [ ! -d "$HOME/.gemini" ] && { echo "  ⏭  Gemini — not detected"; return; }
  echo "  📦 Gemini (Antigravity)"

  # Gemini uses per-project .agents/ directory
  # Auto-install to current directory if it looks like a project
  if [ -d ".git" ] || [ -f "package.json" ] || [ -d ".agents" ]; then
    copy_skills ".agents/skills"
    echo "     ✅ $(ls -d "$SKILLS_DIR"/*/ | wc -l | tr -d ' ') skills → .agents/skills/"
    INSTALLED=$((INSTALLED + 1))
  else
    echo "     ℹ️  Gemini requires per-project install."
    echo "        Run from your project root, or use:"
    echo "        bash $SCRIPT_DIR/install.sh --project /path/to/project"
  fi
}

# ─────────────────────────────────────────
# Per-project install (Gemini + all platforms)
# ─────────────────────────────────────────
install_project() {
  local project="$1"
  [ ! -d "$project" ] && { echo "  ❌ Not found: $project"; exit 1; }
  echo "  📦 Project: $project"

  # Gemini
  copy_skills "$project/.agents/skills"
  copy_commands "$project/.agents/workflows"
  echo "     ✅ Gemini:  .agents/skills/ + .agents/workflows/"

  # Codex
  copy_skills "$project/.codex/skills"
  echo "     ✅ Codex:   .codex/skills/"

  # Qwen
  copy_skills "$project/.qwen/skills"
  echo "     ✅ Qwen:    .qwen/skills/"

  # Claude Code
  copy_commands "$project/.claude/commands"
  echo "     ✅ Claude:  .claude/commands/"
}

# ─────────────────────────────────────────
# Main
# ─────────────────────────────────────────
if [ "${1:-}" = "--project" ] && [ -n "${2:-}" ]; then
  install_project "$2"
else
  install_claude
  install_qwen
  install_codex
  install_gemini
fi

echo ""
echo "  ── Done: $INSTALLED platforms ──"
echo ""
echo "  Update: cd $(basename "$SCRIPT_DIR") && git pull && bash install.sh"
echo ""
