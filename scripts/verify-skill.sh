#!/bin/bash
# verify-skill.sh — Verify an OpenClaw skill is loaded in an agent's active session
# Usage: bash verify-skill.sh <agent-id> <skill-name>

set -euo pipefail

AGENT_ID="${1:?Usage: verify-skill.sh <agent-id> <skill-name>}"
SKILL_NAME="${2:?Usage: verify-skill.sh <agent-id> <skill-name>}"

SESSIONS_FILE="$HOME/.openclaw/agents/$AGENT_ID/sessions/sessions.json"

if [ ! -f "$SESSIONS_FILE" ]; then
  echo "FAIL: Sessions file not found at $SESSIONS_FILE"
  echo "  Is the agent ID correct? Is the gateway running?"
  exit 1
fi

# Check if skill is in session snapshot prompt
FOUND=$(python3 -c "
import json, sys
with open('$SESSIONS_FILE') as f:
    data = json.load(f)
session = data.get('agent:${AGENT_ID}:main', {})
session_id = session.get('sessionId', 'unknown')
prompt = session.get('skillsSnapshot', {}).get('prompt', '')
skill = '${SKILL_NAME}'
if skill in prompt:
    print(f'FOUND: {skill} is loaded in session {session_id}')
    sys.exit(0)
else:
    print(f'NOT FOUND: {skill} is NOT in session {session_id}')
    print()
    # Show what skills ARE loaded
    skills = session.get('skillsSnapshot', {}).get('skills', [])
    if skills:
        print('Loaded skills:')
        for s in skills:
            name = s.get('name', '?')
            print(f'  - {name}')
    sys.exit(1)
" 2>&1)

echo "$FOUND"

# Also check for latest session log file
LATEST=$(ls -t "$HOME/.openclaw/agents/$AGENT_ID/sessions/"*.jsonl 2>/dev/null | head -1)
if [ -n "$LATEST" ]; then
  echo ""
  echo "Latest session log: $LATEST"
  echo "Size: $(wc -c < "$LATEST" | tr -d ' ') bytes"
  echo "Lines: $(wc -l < "$LATEST" | tr -d ' ')"
fi
