#!/usr/bin/env bash
# verify-skill-loaded.sh - Verify skill loaded in agent session
# NO HARDCODED PATHS - supports local and remote agents

set -e

usage() {
    cat <<EOF
Usage: verify-skill-loaded.sh [OPTIONS] SKILL_NAME

Verify that a skill is loaded in an agent's active session.

OPTIONS:
    -h, --help              Show this help message
    -r, --remote HOST       Check remote agent via SSH
    -a, --agent ID          Target agent ID (required)
    -c, --config PATH       Path to openclaw.json (default: ~/.openclaw/openclaw.json)
    -v, --verbose           Show detailed output

ARGUMENTS:
    SKILL_NAME              Name of skill to verify

EXAMPLES:
    # Check local agent
    verify-skill-loaded.sh -a momiji openclaw-skill-development

    # Check remote agent
    verify-skill-loaded.sh -r user@remote-host -a momiji openclaw-skill-development

OUTPUT:
    - ✅ Skill found in session
    - ❌ Skill not loaded (suggests troubleshooting steps)
EOF
}

# Default values
REMOTE_HOST=""
AGENT_ID=""
CONFIG_PATH="$HOME/.openclaw/openclaw.json"
VERBOSE=0
SKILL_NAME=""

# Parse arguments
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
        -c|--config)
            CONFIG_PATH="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        *)
            SKILL_NAME="$1"
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$SKILL_NAME" ] || [ -z "$AGENT_ID" ]; then
    echo "Error: SKILL_NAME and AGENT_ID required"
    usage
    exit 1
fi

# Expand config path
CONFIG_PATH=$(eval echo "$CONFIG_PATH")

# SSH helper: hardened ssh wrapper (avoids Too many auth failures)
ssh_cmd() {
    ssh -o IdentitiesOnly=yes -o ConnectTimeout=10 -o BatchMode=yes "$REMOTE_HOST" "$@"
}

# SSH pre-check: layered connectivity test
ssh_precheck() {
    echo "🔗 Pre-checking SSH to $REMOTE_HOST..."
    echo "🖥️ 当前: $(hostname) | $(whoami)"
    if ! ssh_cmd "true" 2>/dev/null; then
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
}

echo "🔍 Verifying skill: $SKILL_NAME"
echo "🤖 Agent: $AGENT_ID"
[ -n "$REMOTE_HOST" ] && echo "📡 Remote host: $REMOTE_HOST"

# Pre-check SSH if remote
[ -n "$REMOTE_HOST" ] && ssh_precheck

# Resolve agent directory from config
if [ -n "$REMOTE_HOST" ]; then
    AGENT_DIR=$(ssh_cmd "echo \$HOME/.openclaw/agents/$AGENT_ID")
else
    AGENT_DIR="$HOME/.openclaw/agents/$AGENT_ID"
fi

echo "📂 Agent directory: $AGENT_DIR"

# Check if agent directory exists
if [ -n "$REMOTE_HOST" ]; then
    if ! ssh_cmd "test -d $AGENT_DIR"; then
        echo "❌ Error: Agent directory not found: $AGENT_DIR"
        echo "   Agent may not exist or hasn't started yet"
        exit 1
    fi
else
    if [ ! -d "$AGENT_DIR" ]; then
        echo "❌ Error: Agent directory not found: $AGENT_DIR"
        echo "   Agent may not exist or hasn't started yet"
        exit 1
    fi
fi

# Check session snapshot
SESSION_FILE="$AGENT_DIR/sessions/sessions.json"

if [ -n "$REMOTE_HOST" ]; then
    if ! ssh_cmd "test -f $SESSION_FILE"; then
        echo "⚠️  Warning: No session file found at $SESSION_FILE"
        echo "   Agent may not have any active sessions yet"
        exit 1
    fi
else
    if [ ! -f "$SESSION_FILE" ]; then
        echo "⚠️  Warning: No session file found at $SESSION_FILE"
        echo "   Agent may not have any active sessions yet"
        exit 1
    fi
fi

# Search for skill in session snapshot
echo "🔎 Checking session snapshot..."

if [ -n "$REMOTE_HOST" ]; then
    FOUND=$(ssh_cmd "cat $SESSION_FILE | python3 -c \"
import sys, json
data = json.load(sys.stdin)
session = data.get('agent:$AGENT_ID:main', {})
prompt = session.get('skillsSnapshot', {}).get('prompt', '')
print('yes' if '$SKILL_NAME' in prompt else 'no')
\"")
else
    FOUND=$(cat "$SESSION_FILE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
session = data.get('agent:$AGENT_ID:main', {})
prompt = session.get('skillsSnapshot', {}).get('prompt', '')
print('yes' if '$SKILL_NAME' in prompt else 'no')
")
fi

# Report results
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$FOUND" = "yes" ]; then
    echo "✅ Skill LOADED: $SKILL_NAME found in agent session"
    echo ""
    echo "The skill is active and ready to use."
    exit 0
else
    echo "❌ Skill NOT LOADED: $SKILL_NAME not found in session"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if skill exists in workspace:"
    if [ -n "$REMOTE_HOST" ]; then
        echo "   ssh $REMOTE_HOST \"ls -la \\\$HOME/.openclaw/workspace-$AGENT_ID/skills/\""
    else
        echo "   ls -la \$HOME/.openclaw/workspace-$AGENT_ID/skills/"
    fi
    echo ""
    echo "2. Send '/new' to agent $AGENT_ID to create fresh session"
    echo ""
    echo "3. Check gateway logs for skill loading errors:"
    if [ -n "$REMOTE_HOST" ]; then
        echo "   ssh $REMOTE_HOST \"tail -f ~/.openclaw/logs/gateway.log\""
    else
        echo "   tail -f ~/.openclaw/logs/gateway.log"
    fi
    exit 1
fi
