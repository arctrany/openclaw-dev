#!/usr/bin/env bash
# skill-lint.sh — Lint all SKILL.md files for OpenClaw best-practice compliance.
# Usage: bash scripts/skill-lint.sh [skills/specific-skill]
# Based on agents/skill-reviewer.md Review Checklist.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-${REPO_ROOT}/skills}"
ERRORS=0
WARNINGS=0
SKILLS_CHECKED=0

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

error() {
  echo -e "  ${RED}✗ [ERROR]${NC} $1"
  ERRORS=$((ERRORS + 1))
}

warn() {
  echo -e "  ${YELLOW}⚠ [WARN]${NC}  $1"
  WARNINGS=$((WARNINGS + 1))
}

ok() {
  echo -e "  ${GREEN}✓${NC} $1"
}

lint_skill() {
  local skill_dir="$1"
  local skill_name
  skill_name=$(basename "$skill_dir")
  local skill_file="${skill_dir}/SKILL.md"

  echo -e "\n${CYAN}━━━ ${skill_name} ━━━${NC}"
  SKILLS_CHECKED=$((SKILLS_CHECKED + 1))

  # ── Check SKILL.md exists ──
  if [[ ! -f "$skill_file" ]]; then
    error "SKILL.md not found in ${skill_dir}"
    return
  fi

  # ── Extract frontmatter ──
  local in_frontmatter=false
  local frontmatter=""
  local body_lines=0
  local past_frontmatter=false

  while IFS= read -r line; do
    line="${line%$'\r'}"
    if [[ "$line" == "---" ]]; then
      if $in_frontmatter; then
        in_frontmatter=false
        past_frontmatter=true
        continue
      elif ! $past_frontmatter; then
        in_frontmatter=true
        continue
      fi
    fi
    if $in_frontmatter; then
      frontmatter+="${line}"$'\n'
    elif $past_frontmatter; then
      body_lines=$((body_lines + 1))
    fi
  done < "$skill_file"

  # ── 1. Frontmatter checks ──

  # Check name exists
  local fm_name
  fm_name=$(echo "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:\s*//' | tr -d '[:space:]' || true)
  if [[ -z "$fm_name" ]]; then
    error "Frontmatter missing 'name' field"
  else
    ok "name: ${fm_name}"

    # Check name is kebab-case
    if ! echo "$fm_name" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
      error "name '${fm_name}' is not kebab-case"
    fi

    # Check name matches directory
    if [[ "$fm_name" != "$skill_name" ]]; then
      error "name '${fm_name}' does not match directory '${skill_name}'"
    fi
  fi

  # Check description exists
  local fm_desc
  fm_desc=$(echo "$frontmatter" | grep -E '^description:' | head -1 | sed 's/^description:\s*//' || true)
  if [[ -z "$fm_desc" ]]; then
    error "Frontmatter missing 'description' field"
  else
    # Check description length (word count)
    local desc_words
    desc_words=$(echo "$fm_desc" | wc -w | tr -d '[:space:]')
    if [[ "$desc_words" -gt 200 ]]; then
      warn "description is ${desc_words} words (recommended ≤ 200)"
    else
      ok "description: ${desc_words} words"
    fi
  fi

  # ── 2. Body length ──
  local total_lines
  total_lines=$(wc -l < "$skill_file" | tr -d '[:space:]')
  if [[ "$total_lines" -gt 500 ]]; then
    warn "SKILL.md is ${total_lines} lines (recommended ≤ 500)"
  else
    ok "body: ${total_lines} lines"
  fi

  # ── 3. Body anti-patterns ──
  if grep -qiE '^#+\s*(when to use|usage|use case)' "$skill_file" 2>/dev/null; then
    warn "'When to use' section found in body (should be in description)"
  fi

  if grep -qiE '^#+\s*(installation|changelog|release notes)' "$skill_file" 2>/dev/null; then
    warn "README-style section found (installation/changelog)"
  fi

  # ── 4. Directory structure ──

  # Check if references/ exists when referenced
  if grep -q 'references/' "$skill_file" 2>/dev/null; then
    if [[ ! -d "${skill_dir}/references" ]]; then
      error "SKILL.md references 'references/' but directory does not exist"
    elif [[ -z "$(ls -A "${skill_dir}/references" 2>/dev/null)" ]]; then
      error "references/ directory is empty"
    else
      local ref_count
      ref_count=$(find "${skill_dir}/references" -type f | wc -l | tr -d '[:space:]')
      ok "references/: ${ref_count} file(s)"
    fi
  fi

  # Check if scripts/ has executable permissions
  if [[ -d "${skill_dir}/scripts" ]]; then
    local non_exec=0
    while IFS= read -r script; do
      if [[ ! -x "$script" ]]; then
        warn "Script not executable: $(basename "$script")"
        ((non_exec++))
      fi
    done < <(find "${skill_dir}/scripts" -name "*.sh" -type f 2>/dev/null)

    if [[ "$non_exec" -eq 0 ]]; then
      local script_count
      script_count=$(find "${skill_dir}/scripts" -name "*.sh" -type f | wc -l | tr -d '[:space:]')
      if [[ "$script_count" -gt 0 ]]; then
        ok "scripts/: ${script_count} executable(s)"
      fi
    fi
  fi

  # ── 5. No hardcoded paths ──
  if grep -nE '/Users/[a-zA-Z]|/home/[a-zA-Z]|C:\\Users\\' "$skill_file" 2>/dev/null | grep -v '/Users/xxx' | head -3 | while IFS= read -r match; do
    error "Hardcoded path in SKILL.md: ${match}"
  done; then
    :
  fi
}

# ── Main ────────────────────────────────────────────────────────────────────

echo "🔍 OpenClaw SKILL Lint"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "${TARGET}/SKILL.md" ]]; then
  # Single skill
  lint_skill "$TARGET"
elif [[ -d "$TARGET" ]]; then
  # Directory of skills
  for skill_dir in "${TARGET}"/*/; do
    [[ -d "$skill_dir" ]] || continue
    lint_skill "$skill_dir"
  done
else
  echo "Error: ${TARGET} is not a valid skill directory"
  exit 2
fi

# ── Cross-reference checks ──────────────────────────────────────────────────

echo -e "\n${CYAN}━━━ Cross-Reference Checks ━━━${NC}"

# Build list of existing command names from commands/ directory
VALID_COMMANDS=""
for cmd_file in "${REPO_ROOT}"/commands/*.md "${REPO_ROOT}"/commands/maintainer/*.md; do
  [[ -f "$cmd_file" ]] || continue
  local_name=$(grep -E '^name:' "$cmd_file" 2>/dev/null | head -1 | sed 's/^name:[[:space:]]*//' | tr -d '[:space:]"' || true)
  if [[ -n "$local_name" ]]; then
    VALID_COMMANDS="${VALID_COMMANDS} ${local_name}"
  fi
done

# Check for references to old/deleted command names in active files
OLD_COMMANDS="openclaw-status diagnose-openclaw evolve-openclaw-capability collect-signals evolve-openclaw-dev sync-knowledge"

for old_cmd in $OLD_COMMANDS; do
  # Search for /command-name as a standalone reference (preceded by space, backtick, or start of line)
  # Exclude matches that are part of file paths (e.g., /scripts/collect-signals.py, /references/sync-knowledge-runbook.md)
  matches=$(grep -rlE "(^|[[:space:]\`])/${old_cmd}([[:space:]\`\)\.]|$)" "${REPO_ROOT}/skills/" "${REPO_ROOT}/commands/" "${REPO_ROOT}/CLAUDE.md" "${REPO_ROOT}/README.md" 2>/dev/null | grep -v 'docs/plans' || true)
  if [[ -n "$matches" ]]; then
    error "Stale command reference '/${old_cmd}' found in: $(echo "$matches" | tr '\n' ', ')"
  fi
done

ok "Cross-reference check complete"

# ── Summary ─────────────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Skills checked: ${SKILLS_CHECKED}"
echo -e "Errors: ${RED}${ERRORS}${NC}  Warnings: ${YELLOW}${WARNINGS}${NC}"

if [[ "$ERRORS" -gt 0 ]]; then
  echo -e "${RED}❌ Lint failed${NC}"
  exit 1
else
  echo -e "${GREEN}✅ All skills passed${NC}"
  exit 0
fi
