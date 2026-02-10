#!/bin/bash
# validate-skill.sh — Validate an OpenClaw skill directory
# Usage: bash validate-skill.sh <path-to-skill-dir>

set -uo pipefail

SKILL_DIR="${1:?Usage: validate-skill.sh <path-to-skill-dir>}"
SKILL_FILE="$SKILL_DIR/SKILL.md"
PASS=0
FAIL=0
WARN=0

ok()   { echo "  OK:   $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  WARN: $1"; WARN=$((WARN + 1)); }

echo "Validating: $SKILL_DIR"
echo "---"

# 1. SKILL.md exists
if [ -f "$SKILL_FILE" ]; then
  ok "SKILL.md exists"
else
  fail "SKILL.md not found at $SKILL_FILE"
  echo ""
  echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
  exit 1
fi

# Extract frontmatter (between first two --- lines)
FRONTMATTER=$(awk '/^---$/{n++; next} n==1{print} n>=2{exit}' "$SKILL_FILE")

# 2. name field
SKILLNAME=$(echo "$FRONTMATTER" | grep "^name:" | sed 's/name: *//' | tr -d '\r')
if [ -n "$SKILLNAME" ]; then
  ok "name field: '$SKILLNAME'"
else
  fail "missing 'name' field in frontmatter"
fi

# 3. description field
DESC=$(echo "$FRONTMATTER" | grep "^description:" | sed 's/description: *//' | tr -d '\r')
if [ -n "$DESC" ]; then
  DESC_LEN=${#DESC}
  if [ "$DESC_LEN" -ge 30 ]; then
    ok "description field ($DESC_LEN chars)"
  else
    warn "description is short ($DESC_LEN chars) — longer descriptions trigger more reliably"
  fi
else
  fail "missing 'description' field in frontmatter"
fi

# 4. Name matches directory
DIRNAME=$(basename "$SKILL_DIR")
if [ -n "$SKILLNAME" ]; then
  if [ "$DIRNAME" = "$SKILLNAME" ]; then
    ok "name matches directory"
  else
    fail "name '$SKILLNAME' does not match directory '$DIRNAME'"
  fi
fi

# 5. Name format (kebab-case)
if [ -n "$SKILLNAME" ]; then
  if echo "$SKILLNAME" | grep -qE '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$'; then
    ok "name is kebab-case"
  else
    fail "name '$SKILLNAME' is not kebab-case (use lowercase letters, digits, hyphens)"
  fi
fi

# 6. Metadata JSON valid (if present)
META=$(echo "$FRONTMATTER" | grep "^metadata:" | sed 's/metadata: *//' | tr -d '\r')
if [ -n "$META" ]; then
  if echo "$META" | jq . > /dev/null 2>&1; then
    ok "metadata is valid JSON"

    # Check always flag
    ALWAYS=$(echo "$META" | jq -r '.clawdbot.always // false' 2>/dev/null)
    echo "  INFO: always=$ALWAYS"

    # Check required bins
    BINS=$(echo "$META" | jq -r '.clawdbot.requires.bins[]? // empty' 2>/dev/null)
    if [ -n "$BINS" ]; then
      for bin in $BINS; do
        if command -v "$bin" > /dev/null 2>&1; then
          ok "required binary '$bin' found"
        else
          fail "required binary '$bin' not found in PATH"
        fi
      done
    fi

    # Check anyBins
    ANYBINS=$(echo "$META" | jq -r '.clawdbot.requires.anyBins[]? // empty' 2>/dev/null)
    if [ -n "$ANYBINS" ]; then
      FOUND_ANY=false
      for bin in $ANYBINS; do
        if command -v "$bin" > /dev/null 2>&1; then
          FOUND_ANY=true
          ok "anyBins: '$bin' found"
          break
        fi
      done
      if [ "$FOUND_ANY" = false ]; then
        fail "none of anyBins found: $ANYBINS"
      fi
    fi
  else
    fail "metadata is not valid JSON: $META"
  fi
else
  echo "  INFO: no metadata field (optional)"
fi

# 7. Line count
LINES=$(wc -l < "$SKILL_FILE" | tr -d ' ')
if [ "$LINES" -le 500 ]; then
  ok "SKILL.md is $LINES lines (under 500 limit)"
else
  warn "SKILL.md is $LINES lines (over 500 — consider splitting to references/)"
fi

# 8. No extraneous files
for bad_file in README.md CHANGELOG.md INSTALLATION_GUIDE.md QUICK_REFERENCE.md; do
  if [ -f "$SKILL_DIR/$bad_file" ]; then
    warn "extraneous file '$bad_file' found — skills should only contain SKILL.md and functional resources"
  fi
done

# 9. Check for "When to use" in body (should be in description instead)
BODY=$(awk '/^---$/{n++; next} n>=2{print}' "$SKILL_FILE")
if echo "$BODY" | grep -qi "when to use"; then
  warn "'When to use' found in body — this should be in the description field for proper triggering"
fi

# 10. Frontmatter delimiter check
DELIM_COUNT=$(grep -c "^---$" "$SKILL_FILE" || true)
if [ "$DELIM_COUNT" -ge 2 ]; then
  ok "frontmatter delimiters present"
else
  fail "missing frontmatter delimiters (need opening and closing ---)"
fi

echo ""
echo "---"
echo "Result: $PASS passed, $FAIL failed, $WARN warnings"
if [ "$FAIL" -gt 0 ]; then
  echo "Status: INVALID — fix failures before deploying"
  exit 1
else
  echo "Status: VALID"
  exit 0
fi
