#!/usr/bin/env bash
# fleet-tmux.sh — Create or reattach a tmux monitoring panel for fleet nodes
#
# Usage: fleet-tmux.sh <session_name> <nodes_json>
#
# nodes_json format: [{"name":"node-a","user":"your-user","host":"10.0.0.1","port":"22","key":""}]
#
# Each pane runs `tail -f /tmp/fleet-<session>-<name>.log`
# The main agent writes command output to those log files via SSH.
# Max 4 panes.

set -euo pipefail

SESSION_NAME="${1:?Usage: fleet-tmux.sh <session_name> <nodes_json>}"
NODES_JSON="${2:?Missing nodes_json}"

# Check tmux
if ! command -v tmux &>/dev/null; then
    echo "ERROR: tmux is required but not installed."
    echo "  macOS:  brew install tmux"
    echo "  Linux:  sudo apt install tmux"
    exit 1
fi

# Check jq
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq is required but not installed."
    echo "  macOS:  brew install jq"
    echo "  Linux:  sudo apt install jq"
    exit 1
fi

# ── Session reattach check ────────────────────────────────────────────────────
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "SESSION_EXISTS: Fleet session '$SESSION_NAME' is already running."

    # Append reattach marker to all existing log files
    for logfile in /tmp/fleet-"${SESSION_NAME}"-*.log; do
        [[ -f "$logfile" ]] || continue
        echo "" >> "$logfile"
        echo "━━━ $(date '+%H:%M:%S') Session reattached ━━━" >> "$logfile"
    done

    # Attach based on terminal type
    if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] || pgrep -q iTerm2 2>/dev/null; then
        tmux -CC attach -t "$SESSION_NAME"
    else
        echo "Attach:  tmux attach -t $SESSION_NAME"
    fi

    echo "FLEET_SESSION_INFO:{\"session\":\"$SESSION_NAME\",\"reattached\":true}"
    exit 0
fi

# ── New session creation ──────────────────────────────────────────────────────

# Parse nodes
NODE_COUNT=$(echo "$NODES_JSON" | jq 'length')
if [[ "$NODE_COUNT" -eq 0 ]]; then
    echo "ERROR: No nodes provided."
    exit 1
fi
if [[ "$NODE_COUNT" -gt 4 ]]; then
    echo "WARNING: Max 4 panes supported. Using first 4 nodes only."
    NODE_COUNT=4
fi

# Initialize log files (append, don't truncate — preserve history)
for i in $(seq 0 $((NODE_COUNT - 1))); do
    NODE_NAME=$(echo "$NODES_JSON" | jq -r ".[$i].name")
    LOG_FILE="/tmp/fleet-${SESSION_NAME}-${NODE_NAME}.log"
    echo "" >> "$LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$LOG_FILE"
    echo "━━━ $(date '+%Y-%m-%d %H:%M:%S') Fleet Monitor: ${NODE_NAME} ━━━" >> "$LOG_FILE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >> "$LOG_FILE"
    echo "Waiting for commands..." >> "$LOG_FILE"
done

# Create tmux session with first node
FIRST_NAME=$(echo "$NODES_JSON" | jq -r '.[0].name')
FIRST_LOG="/tmp/fleet-${SESSION_NAME}-${FIRST_NAME}.log"

tmux new-session -d -s "$SESSION_NAME" -x "$(tput cols)" -y "$(tput lines)" \
    "tail -f $FIRST_LOG"

# Set pane border format to show node name
tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_index}: #{pane_title} "
tmux set-option -t "$SESSION_NAME" pane-border-status top

# Rename first pane
tmux select-pane -t "$SESSION_NAME" -T "$FIRST_NAME"

# Add remaining panes
for i in $(seq 1 $((NODE_COUNT - 1))); do
    NODE_NAME=$(echo "$NODES_JSON" | jq -r ".[$i].name")
    LOG_FILE="/tmp/fleet-${SESSION_NAME}-${NODE_NAME}.log"

    tmux split-window -t "$SESSION_NAME" "tail -f $LOG_FILE"
    tmux select-pane -t "$SESSION_NAME" -T "$NODE_NAME"
done

# Tile panes evenly
tmux select-layout -t "$SESSION_NAME" tiled

# ── Terminal-aware attach ─────────────────────────────────────────────────────

if [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] || pgrep -q iTerm2 2>/dev/null; then
    # iTerm2: use tmux -CC control mode for native tab/split integration
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Fleet Monitor: $SESSION_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "iTerm2 detected — attaching with tmux -CC..."
    echo "Detach: press Esc or close the tmux tab"
    echo "Reattach: tmux -CC attach -t $SESSION_NAME"
    echo "Stop:   /watch stop"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    # Note: tmux -CC attach is handled by the calling agent
    # because it needs to run in the foreground terminal
elif [[ "$(uname)" == "Darwin" ]]; then
    # macOS Terminal.app: open in new tab
    osascript -e "
tell application \"Terminal\"
    activate
    do script \"tmux attach -t '${SESSION_NAME}'\"
end tell
"
else
    # Linux / remote: print instructions
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Fleet Monitor: $SESSION_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Attach:   tmux attach -t $SESSION_NAME"
    echo "Stop:     /watch stop"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

# Output session info as JSON for the calling agent
echo ""
echo "FLEET_SESSION_INFO:$(jq -n \
    --arg session "$SESSION_NAME" \
    --arg count "$NODE_COUNT" \
    --argjson nodes "$NODES_JSON" \
    '{session: $session, panes: ($count | tonumber), nodes: [$nodes[].name][:($count | tonumber)], reattached: false}'  \
    2>/dev/null || echo "{\"session\":\"$SESSION_NAME\",\"panes\":$NODE_COUNT}"
)"
