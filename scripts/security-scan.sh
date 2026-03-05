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
  VIOLATIONS=$((VIOLATIONS + 1))
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

# Context-aware whitelist for path patterns (docs/diagnostic guidance)
PATH_WHITELIST=(
  'grep.*"/Volumes/'           # grep command checking for /Volumes/
  '不应在.*Volumes'             # diagnostic guidance: should not be on /Volumes
  '禁止.*Volumes'               # diagnostic guidance: forbidden on /Volumes
  'Volumes.*禁止'               # diagnostic guidance: /Volumes ... forbidden (reversed order)
  'Forbidden.*Volumes'         # English equivalent
  '<disk-name>'                # placeholder: /Volumes/<disk-name>
  'echo.*Volumes'              # echo/warning about /Volumes
  'must not reference'         # anti-pattern documentation: "must not reference /Volumes/..."
  'Forbidden.*Compliant'       # "Forbidden vs Compliant" table header
  '`/Users/xxx'                # placeholder path in docs: /Users/xxx/
  'grep -nE'                   # grep pattern in lint scripts
  '/Users/\[' # regex pattern like /Users/[^$] in scan scripts
)

is_whitelisted_path() {
  local line="$1"
  shopt -s nocasematch
  for wl in "${PATH_WHITELIST[@]}"; do
    if [[ "$line" =~ $wl ]]; then
      shopt -u nocasematch
      return 0
    fi
  done
  shopt -u nocasematch
  return 1
}

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

# 4. Identity patterns (usernames, hostnames)
IDENTITY_PATTERNS_FILE="${REPO_ROOT}/.security-identities"
IDENTITY_STRINGS=()
if [[ -f "$IDENTITY_PATTERNS_FILE" ]]; then
  while IFS= read -r id_line; do
    # Skip comments and empty lines
    [[ -z "$id_line" || "$id_line" == \#* ]] && continue
    IDENTITY_STRINGS+=("$id_line")
  done < "$IDENTITY_PATTERNS_FILE"
fi

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
  '100\.64\.'              # Tailscale CGNAT range (documentation)
  '10\.0\.0\.'             # Private LAN (documentation)
  '192\.168\.'             # Private LAN (documentation)
  '172\.1[6-9]\.|172\.2[0-9]\.|172\.3[01]\.'  # Private LAN (documentation)
  '169\.254\.'             # Link-local (documentation)
  'Forbidden.*Compliant'   # "Forbidden vs Compliant" table in docs
  '\$GOOGLE_DRIVE'          # anti-pattern doc: user@gmail.com → $GOOGLE_DRIVE_ACCOUNT
)

is_whitelisted_privacy() {
  local line="$1"
  shopt -s nocasematch
  for wl in "${PRIVACY_WHITELIST[@]}"; do
    if [[ "$line" =~ $wl ]]; then
      shopt -u nocasematch
      return 0
    fi
  done
  shopt -u nocasematch
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
  '\.\.\.'                     # password: "..."
  'long-random'                # obviously fake: "long-random-token"
  '[A-Z]+_TOKEN'               # ACME_TOKEN, GATEWAY_TOKEN, etc.
  'EXAMPLE'
  'NOT_A_REAL'
  '\$\{[0-9]'                  # bash positional params: ${1:-}, ${4:-}
  '\$\{[A-Z_]+:-'              # bash default values: ${VAR:-default}
)

is_whitelisted_secret() {
  local line="$1"
  shopt -s nocasematch
  for wl in "${SECRET_WHITELIST[@]}"; do
    if [[ "$line" =~ $wl ]]; then
      shopt -u nocasematch
      return 0
    fi
  done
  shopt -u nocasematch
  return 1
}

# ── Build combined patterns (join arrays with |) ────────────────────────────

join_patterns() {
  local IFS='|'
  echo "$*"
}

COMBINED_PATH="$(join_patterns "${PATH_PATTERNS[@]}")"
COMBINED_SECRET="$(join_patterns "${SECRET_PATTERNS[@]}")"
COMBINED_PRIVACY="$(join_patterns "${PRIVACY_PATTERNS[@]}")"

# Build identity grep file (if any)
IDENTITY_TMP=""
if [[ ${#IDENTITY_STRINGS[@]} -gt 0 ]]; then
  IDENTITY_TMP=$(mktemp)
  printf '%s\n' "${IDENTITY_STRINGS[@]}" > "$IDENTITY_TMP"
  trap 'rm -f "$IDENTITY_TMP"' EXIT
fi

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

  TOTAL_FILES=$((TOTAL_FILES + 1))

  # 1. Path leak check — one grep per file
  while IFS=: read -r line_num content; do
    if ! is_whitelisted_path "$content"; then
      log_violation "PERSONAL_PATH" "$file" "$line_num" "$content"
    fi
  done < <(grep -nE "$COMBINED_PATH" "$full_path" 2>/dev/null || true)

  # 2. Secret check — one grep per file
  while IFS=: read -r line_num content; do
    if ! is_whitelisted_secret "$content"; then
      log_violation "SECRET_LEAK" "$file" "$line_num" "$content"
    fi
  done < <(grep -niE "$COMBINED_SECRET" "$full_path" 2>/dev/null || true)

  # 3. Privacy check — one grep per file
  while IFS=: read -r line_num content; do
    if ! is_whitelisted_privacy "$content"; then
      log_violation "PRIVACY_INFO" "$file" "$line_num" "$content"
    fi
  done < <(grep -nE "$COMBINED_PRIVACY" "$full_path" 2>/dev/null || true)

  # 4. Identity check — one grep per file
  if [[ -n "$IDENTITY_TMP" ]]; then
    while IFS=: read -r line_num content; do
      log_violation "IDENTITY_LEAK" "$file" "$line_num" "$content"
    done < <(grep -niF -f "$IDENTITY_TMP" "$full_path" 2>/dev/null || true)
  fi

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
