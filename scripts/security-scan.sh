#!/usr/bin/env bash
# security-scan.sh — Scan repo for leaked secrets, personal paths, and privacy info.
# Usage: bash scripts/security-scan.sh [--strict]
# Exit 0 = clean, Exit 1 = violations found.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STRICT="${1:-}"
VIOLATIONS=0
TOTAL_FILES=0

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

log_violation() {
  local category="$1" file="$2" line_num="$3" content="$4"
  echo -e "${RED}[VIOLATION]${NC} ${YELLOW}${category}${NC}"
  echo "  File: ${file}"
  echo "  Line: ${line_num}"
  echo "  Content: ${content}"
  echo ""
  ((VIOLATIONS++))
}

# ── Whitelist ───────────────────────────────────────────────────────────────
# Files to skip during scanning
should_skip() {
  local file="$1"
  case "$file" in
    # Skip git internals
    */.git/*) return 0 ;;
    # Skip this script itself
    */security-scan.sh) return 0 ;;
    # Skip example/template files
    *.example) return 0 ;;
    *.example.*) return 0 ;;
    # Skip binary files
    *.png|*.jpg|*.jpeg|*.gif|*.ico|*.woff|*.woff2|*.ttf|*.eot) return 0 ;;
    # Skip generated platform dirs (should be gitignored, but double-check)
    */.claude/*|*/.agents/*|*/.codex/*|*/.qwen/*) return 0 ;;
    # Skip lock files
    */package-lock.json|*/yarn.lock) return 0 ;;
    *) return 1 ;;
  esac
}

# ── Patterns ────────────────────────────────────────────────────────────────

# 1. Personal / absolute path patterns
PATH_PATTERNS=(
  '/Users/[a-zA-Z]'           # macOS home dir
  '/home/[a-zA-Z]'            # Linux home dir
  'C:\\Users\\'               # Windows home dir
  'C:/Users/'                 # Windows (forward slash)
  '/var/folders/'             # macOS temp
  '/Volumes/[a-zA-Z]'        # macOS external disks
)

# 2. Secret / Key patterns
SECRET_PATTERNS=(
  'API_KEY\s*[=:]\s*["\x27][^"'\''<>]+["\x27]'    # API_KEY = "xxx" (not placeholder)
  'SECRET\s*[=:]\s*["\x27][^"'\''<>]+["\x27]'      # SECRET = "xxx" (not placeholder)
  'TOKEN\s*[=:]\s*["\x27][^"'\''<>]+["\x27]'        # TOKEN = "xxx" (not placeholder)
  'PASSWORD\s*[=:]\s*["\x27][^"'\''<>]+["\x27]'     # PASSWORD = "xxx" (not placeholder)
  'sk-[a-zA-Z0-9]{20,}'                           # OpenAI key
  'ghp_[a-zA-Z0-9]{36}'                           # GitHub PAT
  'ghs_[a-zA-Z0-9]{36}'                           # GitHub App token
  'gho_[a-zA-Z0-9]{36}'                           # GitHub OAuth
  'github_pat_[a-zA-Z0-9_]{22,}'                  # GitHub fine-grained PAT
  'AKIA[0-9A-Z]{16}'                              # AWS Access Key
  'xoxb-[0-9]+-[0-9A-Za-z]+'                      # Slack bot token
  'xoxp-[0-9]+-[0-9A-Za-z]+'                      # Slack user token
)

# 3. Privacy patterns
PRIVACY_PATTERNS=(
  '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'    # Email
  '\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b' # IPv4
  'BEGIN .*(PRIVATE KEY|CERTIFICATE)'                     # Private key / cert
)

# Context-aware whitelist for privacy patterns (skip if line matches these)
PRIVACY_WHITELIST=(
  'example\.com'
  'example\.org'
  'your\.email'
  'openclaw\.ai'
  'github\.com'
  'localhost'
  '127\.0\.0\.1'
  '0\.0\.0\.0'
  '255\.255\.'
  '@example\.'
  'x\.x\.x\.x'
  'install\.sh'
  'install\.ps1'
  'curl -fsSL'
  'iwr -useb'
)

is_whitelisted_privacy() {
  local line="$1"
  for wl in "${PRIVACY_WHITELIST[@]}"; do
    if echo "$line" | grep -qiE "$wl"; then
      return 0
    fi
  done
  return 1
}

# Context-aware whitelist for secret patterns (common placeholder/example values)
SECRET_WHITELIST=(
  'shared-secret'
  'your[_-]'
  'example'
  'placeholder'
  'changeme'
  'xxx'
  '<token>'
  '<key>'
  '<secret>'
  '<password>'
)

is_whitelisted_secret() {
  local line="$1"
  for wl in "${SECRET_WHITELIST[@]}"; do
    if echo "$line" | grep -qiE "$wl"; then
      return 0
    fi
  done
  return 1
}

# ── Main scan ───────────────────────────────────────────────────────────────

echo "🔍 OpenClaw Security Scan"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Repo: ${REPO_ROOT}"
echo ""

# Collect files (tracked by git, or all if not a git repo)
if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null; then
  FILES=$(git -C "$REPO_ROOT" ls-files --cached --others --exclude-standard 2>/dev/null || find "$REPO_ROOT" -type f)
else
  FILES=$(find "$REPO_ROOT" -type f -not -path '*/.git/*')
fi

while IFS= read -r file; do
  full_path="${REPO_ROOT}/${file}"
  [[ -f "$full_path" ]] || continue
  should_skip "$full_path" && continue

  # Skip binary files
  file_type=$(file -b --mime-type "$full_path" 2>/dev/null || echo "unknown")
  case "$file_type" in
    text/*|application/json|application/xml|application/javascript) ;;
    *) continue ;;
  esac

  ((TOTAL_FILES++))
  line_num=0

  while IFS= read -r line; do
    ((line_num++))

    # 1. Path leak check
    for pattern in "${PATH_PATTERNS[@]}"; do
      if echo "$line" | grep -q -E -e "$pattern"; then
        log_violation "PERSONAL_PATH" "$file" "$line_num" "$line"
        break
      fi
    done

    # 2. Secret check (with whitelist)
    for pattern in "${SECRET_PATTERNS[@]}"; do
      if echo "$line" | grep -q -E -i -e "$pattern"; then
        if ! is_whitelisted_secret "$line"; then
          log_violation "SECRET_LEAK" "$file" "$line_num" "$line"
        fi
        break
      fi
    done

    # 3. Privacy check (with whitelist)
    for pattern in "${PRIVACY_PATTERNS[@]}"; do
      if echo "$line" | grep -q -E -e "$pattern"; then
        if ! is_whitelisted_privacy "$line"; then
          log_violation "PRIVACY_INFO" "$file" "$line_num" "$line"
        fi
        break
      fi
    done

  done < "$full_path"
done <<< "$FILES"

# ── Summary ─────────────────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Scanned: ${TOTAL_FILES} files"

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo -e "${RED}❌ Found ${VIOLATIONS} violation(s)${NC}"
  if [[ "$STRICT" == "--strict" ]]; then
    exit 1
  else
    echo -e "${YELLOW}⚠️  Run with --strict to fail on violations${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}✅ No violations found${NC}"
  exit 0
fi
