#!/usr/bin/env bash
# validate-skill.sh - Validate OpenClaw skill structure
# Supports both local and remote OpenClaw agents

set -e

usage() {
    cat <<EOF
Usage: validate-skill.sh [OPTIONS] SKILL_DIR

Validate OpenClaw skill structure and metadata.

OPTIONS:
    -h, --help          Show this help message
    -r, --remote HOST   Validate skill on remote host via SSH
    -a, --agent ID      Target agent ID (for workspace resolution)
    -v, --verbose       Show detailed output

EXAMPLES:
    # Validate local skill
    validate-skill.sh /path/to/skill-name

    # Validate skill in agent workspace
    validate-skill.sh -a momiji skill-name

    # Validate skill on remote agent
    validate-skill.sh -r user@remote-host -a momiji skill-name
EOF
}

# Parse arguments
REMOTE_HOST=""
AGENT_ID=""
VERBOSE=0
SKILL_DIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -r|--remote)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -a|--agent)
            AGENT_ID="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        *)
            SKILL_DIR="$1"
            shift
            ;;
    esac
done

if [ -z "$SKILL_DIR" ]; then
    echo "Error: SKILL_DIR required"
    usage
    exit 1
fi

# Function to run commands locally or remotely (hardened SSH)
run_cmd() {
    if [ -n "$REMOTE_HOST" ]; then
        ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_HOST" "$@"
    else
        eval "$@"
    fi
}

# SSH pre-check if remote
if [ -n "$REMOTE_HOST" ]; then
    echo "🖥️ 当前: $(hostname) | $(whoami)"
    echo "🔗 Pre-checking SSH to $REMOTE_HOST..."
    if ! run_cmd "true" 2>/dev/null; then
        ERR=$(ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_HOST" "true" 2>&1)
        if echo "$ERR" | grep -q "Host key"; then
            echo "❌ Host key verification failed → ssh-keygen -R $(echo "$REMOTE_HOST" | sed 's/.*@//')"
        elif echo "$ERR" | grep -q "Too many authentication"; then
            echo "❌ Too many auth failures → add -o IdentitiesOnly=yes -i <key>"
        else
            echo "❌ SSH failed: $ERR"
            echo "   Check: ~/.ssh/authorized_keys permissions (700/600)"
        fi
        exit 1
    fi
fi

# Resolve skill directory if agent ID provided
if [ -n "$AGENT_ID" ]; then
    if [ -n "$REMOTE_HOST" ]; then
        WORKSPACE=$(run_cmd "jq -r '.agents.list[] | select(.id==\"$AGENT_ID\") | .workspace' ~/.openclaw/openclaw.json")
        WORKSPACE=$(run_cmd "eval echo $WORKSPACE")
    else
        WORKSPACE=$(jq -r ".agents.list[] | select(.id==\"$AGENT_ID\") | .workspace" ~/.openclaw/openclaw.json)
        WORKSPACE=$(eval echo "$WORKSPACE")
    fi
    SKILL_DIR="$WORKSPACE/skills/$SKILL_DIR"
fi

echo "🔍 Validating skill: $SKILL_DIR"
[ -n "$REMOTE_HOST" ] && echo "📡 Remote host: $REMOTE_HOST"

# Validation checks
ERRORS=0
WARNINGS=0

# 1. SKILL.md exists
if run_cmd "test -f \"$SKILL_DIR/SKILL.md\""; then
    echo "✅ SKILL.md exists"
else
    echo "❌ FAIL: Missing SKILL.md"
    ((ERRORS++))
    exit 1
fi

# 2. Frontmatter has required fields
if run_cmd "head -20 \"$SKILL_DIR/SKILL.md\" | grep -q '^name:'"; then
    echo "✅ Has 'name' field"
else
    echo "❌ FAIL: Missing 'name' field"
    ((ERRORS++))
fi

if run_cmd "head -20 \"$SKILL_DIR/SKILL.md\" | grep -q '^description:'"; then
    echo "✅ Has 'description' field"
else
    echo "❌ FAIL: Missing 'description' field"
    ((ERRORS++))
fi

# 3. Name matches directory
DIRNAME=$(basename "$SKILL_DIR")
if [ -n "$REMOTE_HOST" ]; then
    SKILLNAME=$(ssh "$REMOTE_HOST" "head -20 \"$SKILL_DIR/SKILL.md\" | grep '^name:' | sed 's/name: *//'")
else
    SKILLNAME=$(head -20 "$SKILL_DIR/SKILL.md" | grep "^name:" | sed 's/name: *//')
fi

if [ "$DIRNAME" = "$SKILLNAME" ]; then
    echo "✅ Name '$SKILLNAME' matches directory"
else
    echo "❌ FAIL: Name '$SKILLNAME' != directory '$DIRNAME'"
    ((ERRORS++))
fi

# 4. Metadata JSON is valid (if present)
if [ -n "$REMOTE_HOST" ]; then
    META=$(ssh "$REMOTE_HOST" "head -20 \"$SKILL_DIR/SKILL.md\" | grep '^metadata:' | sed 's/metadata: *//'")
else
    META=$(head -20 "$SKILL_DIR/SKILL.md" | grep "^metadata:" | sed 's/metadata: *//')
fi

if [ -n "$META" ]; then
    if echo "$META" | jq . > /dev/null 2>&1; then
        echo "✅ Valid metadata JSON"

        # Check for emoji
        if echo "$META" | jq -e '.clawdbot.emoji' > /dev/null 2>&1; then
            EMOJI=$(echo "$META" | jq -r '.clawdbot.emoji')
            echo "  📍 Emoji: $EMOJI"
        else
            echo "⚠️  WARN: No emoji in metadata"
            ((WARNINGS++))
        fi
    else
        echo "❌ FAIL: Invalid metadata JSON"
        ((ERRORS++))
    fi
fi

# 5. Line count check
if [ -n "$REMOTE_HOST" ]; then
    LINES=$(ssh "$REMOTE_HOST" "wc -l < \"$SKILL_DIR/SKILL.md\"")
else
    LINES=$(wc -l < "$SKILL_DIR/SKILL.md")
fi

if [ "$LINES" -le 500 ]; then
    echo "✅ Line count: $LINES lines (under 500)"
else
    echo "⚠️  WARN: $LINES lines (over 500, consider using references/)"
    ((WARNINGS++))
fi

# 6. Check for references/ usage if over 300 lines
if [ "$LINES" -gt 300 ]; then
    if run_cmd "test -d \"$SKILL_DIR/references\""; then
        echo "✅ Using references/ for progressive disclosure"
    else
        echo "⚠️  WARN: Skill is long but no references/ directory"
        echo "   Consider moving detailed content to references/"
        ((WARNINGS++))
    fi
fi

# 7. Check description quality
if [ -n "$REMOTE_HOST" ]; then
    DESC=$(ssh "$REMOTE_HOST" "head -20 \"$SKILL_DIR/SKILL.md\" | grep '^description:' | sed 's/description: *//'")
else
    DESC=$(head -20 "$SKILL_DIR/SKILL.md" | grep "^description:" | sed 's/description: *//')
fi

if [ -n "$DESC" ]; then
    DESC_LEN=${#DESC}
    if [ "$DESC_LEN" -lt 50 ]; then
        echo "⚠️  WARN: Description is short ($DESC_LEN chars)"
        echo "   Add specific trigger phrases and examples"
        ((WARNINGS++))
    else
        echo "✅ Description length: $DESC_LEN chars"
    fi
fi

# 8. Check for third-person format in description
if echo "$DESC" | grep -q "This skill should be used when"; then
    echo "✅ Description uses third-person format"
elif echo "$DESC" | grep -qE "^(Use|Load) (this|when)"; then
    echo "⚠️  WARN: Description should use third-person format"
    echo "   Start with 'This skill should be used when...'"
    ((WARNINGS++))
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ Validation PASSED: No issues found"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Validation PASSED with $WARNINGS warning(s)"
    exit 0
else
    echo "❌ Validation FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
fi
