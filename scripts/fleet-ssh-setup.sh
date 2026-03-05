#!/usr/bin/env bash
# fleet-ssh-setup.sh — Detect and set up passwordless SSH for a remote host
#
# Usage: fleet-ssh-setup.sh <user@host> [ssh_port] [ssh_key] [password]
#
# Exit codes:
#   0 — BatchMode already works or key deployed successfully
#   1 — Setup failed
#   2 — Missing dependencies (sshpass)

set -euo pipefail

USER_HOST="${1:?Usage: fleet-ssh-setup.sh <user@host> [ssh_port] [ssh_key] [password]}"
SSH_PORT="${2:-22}"
SSH_KEY="${3:-}"
PASSWORD="${4:-}"

SSH_OPTS=(-o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -p "$SSH_PORT")
[[ -n "$SSH_KEY" ]] && SSH_OPTS+=(-i "$SSH_KEY")

# Step 1: Check if BatchMode already works
if ssh -o BatchMode=yes "${SSH_OPTS[@]}" "$USER_HOST" "echo ok" &>/dev/null; then
    echo "OK: BatchMode SSH already works for $USER_HOST"
    exit 0
fi

echo "BatchMode SSH not available for $USER_HOST — setting up key-based auth..."

# Step 2: Ensure we have a local SSH key pair
KEY_PATH="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
if [[ ! -f "$KEY_PATH" ]]; then
    echo "No SSH key found at $KEY_PATH — generating ed25519 key pair..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -N "" -C "fleet-ssh-$(whoami)@$(hostname -s)"
    echo "Generated: $KEY_PATH"
fi

# Step 3: Need password to deploy key
if [[ -z "$PASSWORD" ]]; then
    echo "ERROR: Password required to deploy SSH key. Pass as 4th argument."
    exit 1
fi

# Step 4: Check sshpass availability
if ! command -v sshpass &>/dev/null; then
    echo "ERROR: sshpass is required but not installed."
    echo ""
    echo "Install:"
    echo "  macOS:  brew install hudochenkov/sshpass/sshpass"
    echo "  Linux:  sudo apt install sshpass"
    exit 2
fi

# Step 5: Deploy public key via ssh-copy-id
PUB_KEY="${KEY_PATH}.pub"
if [[ ! -f "$PUB_KEY" ]]; then
    PUB_KEY="$KEY_PATH"  # some keys don't have .pub extension
fi

echo "Deploying public key to $USER_HOST..."
SSHPASS="$PASSWORD" sshpass -e ssh-copy-id \
    -o StrictHostKeyChecking=accept-new \
    -p "$SSH_PORT" \
    ${SSH_KEY:+-i "$SSH_KEY"} \
    "$USER_HOST" 2>&1

# Step 6: Verify BatchMode now works
if ssh -o BatchMode=yes "${SSH_OPTS[@]}" "$USER_HOST" "echo ok" &>/dev/null; then
    echo "OK: Key deployed successfully. Passwordless SSH is now available for $USER_HOST"
    exit 0
else
    echo "ERROR: Key deployment appeared to succeed but BatchMode still fails."
    echo "Check remote ~/.ssh/authorized_keys permissions (should be 600)."
    exit 1
fi
