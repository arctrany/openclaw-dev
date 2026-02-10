#!/usr/bin/env bash
# deploy-skill.sh - Deploy OpenClaw skill to local or remote agent
# NO HARDCODED PATHS - all paths resolved dynamically

set -e

usage() {
    cat <<EOF
Usage: deploy-skill.sh [OPTIONS] SKILL_SOURCE AGENT_ID

Deploy OpenClaw skill to agent workspace (local or remote).

OPTIONS:
    -h, --help              Show this help message
    -r, --remote HOST       Deploy to remote host via SSH/rsync
    -m, --method METHOD     Deployment method: rsync (default), scp, git
    -c, --config PATH       Path to openclaw.json (default: ~/.openclaw/openclaw.json)
    -n, --no-verify         Skip post-deployment verification
    -v, --verbose           Show detailed output

ARGUMENTS:
    SKILL_SOURCE            Path to skill directory (or skill name if in current plugin)
    AGENT_ID                Target agent ID (workspace resolved from config)

EXAMPLES:
    # Deploy local skill to local agent
    deploy-skill.sh ./my-skill momiji

    # Deploy to remote agent via rsync
    deploy-skill.sh -r user@remote-host ./my-skill momiji

    # Deploy using git method
    deploy-skill.sh -m git -r user@remote-host my-skill momiji

DEPLOYMENT METHODS:
    rsync   - Sync files via rsync (fast, incremental)
    scp     - Copy files via SCP (simple, one-time)
    git     - Commit and push, then remote pull (version controlled)
EOF
}

# Default values
REMOTE_HOST=""
METHOD="rsync"
CONFIG_PATH="$HOME/.openclaw/openclaw.json"
NO_VERIFY=0
VERBOSE=0
SKILL_SOURCE=""
AGENT_ID=""

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
        -m|--method)
            METHOD="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_PATH="$2"
            shift 2
            ;;
        -n|--no-verify)
            NO_VERIFY=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        *)
            if [ -z "$SKILL_SOURCE" ]; then
                SKILL_SOURCE="$1"
            elif [ -z "$AGENT_ID" ]; then
                AGENT_ID="$1"
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$SKILL_SOURCE" ] || [ -z "$AGENT_ID" ]; then
    echo "Error: SKILL_SOURCE and AGENT_ID required"
    usage
    exit 1
fi

# Expand config path
CONFIG_PATH=$(eval echo "$CONFIG_PATH")

echo "🚀 Deploying skill to agent: $AGENT_ID"
[ -n "$REMOTE_HOST" ] && echo "📡 Remote host: $REMOTE_HOST"
echo "📦 Method: $METHOD"

# Resolve workspace path from config
if [ -n "$REMOTE_HOST" ]; then
    WORKSPACE=$(ssh "$REMOTE_HOST" "jq -r '.agents.list[] | select(.id==\"$AGENT_ID\") | .workspace' $CONFIG_PATH")
    WORKSPACE=$(ssh "$REMOTE_HOST" "eval echo $WORKSPACE")
else
    WORKSPACE=$(jq -r ".agents.list[] | select(.id==\"$AGENT_ID\") | .workspace" "$CONFIG_PATH")
    WORKSPACE=$(eval echo "$WORKSPACE")
fi

if [ -z "$WORKSPACE" ]; then
    echo "❌ Error: Agent '$AGENT_ID' not found in $CONFIG_PATH"
    exit 1
fi

echo "📂 Target workspace: $WORKSPACE"

# Get skill name from source
SKILL_NAME=$(basename "$SKILL_SOURCE")
TARGET_PATH="$WORKSPACE/skills/$SKILL_NAME"

# Deploy based on method
case $METHOD in
    rsync)
        if [ -n "$REMOTE_HOST" ]; then
            echo "🔄 Syncing via rsync to $REMOTE_HOST:$TARGET_PATH"
            rsync -avz --progress "$SKILL_SOURCE/" "$REMOTE_HOST:$TARGET_PATH/"
        else
            echo "🔄 Syncing locally to $TARGET_PATH"
            rsync -av "$SKILL_SOURCE/" "$TARGET_PATH/"
        fi
        ;;
    scp)
        if [ -n "$REMOTE_HOST" ]; then
            echo "📤 Copying via SCP to $REMOTE_HOST:$TARGET_PATH"
            ssh "$REMOTE_HOST" "mkdir -p $TARGET_PATH"
            scp -r "$SKILL_SOURCE/"* "$REMOTE_HOST:$TARGET_PATH/"
        else
            echo "📂 Copying locally to $TARGET_PATH"
            mkdir -p "$TARGET_PATH"
            cp -r "$SKILL_SOURCE/"* "$TARGET_PATH/"
        fi
        ;;
    git)
        echo "🔀 Git deployment (commit + push + remote pull)"

        # Check if in git repo
        if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
            echo "❌ Error: Not in a git repository"
            exit 1
        fi

        # Commit changes
        git add "$SKILL_SOURCE"
        git commit -m "Deploy skill: $SKILL_NAME to agent $AGENT_ID" || echo "No changes to commit"
        git push origin main

        # Pull on remote
        if [ -n "$REMOTE_HOST" ]; then
            ssh "$REMOTE_HOST" "cd $WORKSPACE && git pull origin main"
        else
            cd "$WORKSPACE" && git pull origin main
        fi
        ;;
    *)
        echo "❌ Error: Unknown method '$METHOD'"
        exit 1
        ;;
esac

echo "✅ Deployment complete"

# Verify deployment
if [ $NO_VERIFY -eq 0 ]; then
    echo ""
    echo "🔍 Verifying deployment..."

    if [ -n "$REMOTE_HOST" ]; then
        if ssh "$REMOTE_HOST" "test -f $TARGET_PATH/SKILL.md"; then
            echo "✅ SKILL.md exists at $TARGET_PATH"
        else
            echo "⚠️  Warning: SKILL.md not found at $TARGET_PATH"
        fi
    else
        if [ -f "$TARGET_PATH/SKILL.md" ]; then
            echo "✅ SKILL.md exists at $TARGET_PATH"
        else
            echo "⚠️  Warning: SKILL.md not found at $TARGET_PATH"
        fi
    fi
fi

# Instructions for activation
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📨 Next steps:"
echo "   1. Send '/new' to agent $AGENT_ID via messaging platform"
echo "   2. This creates a new session that loads the skill"
echo "   3. Verify with: verify-skill-loaded.sh -a $AGENT_ID $SKILL_NAME"
[ -n "$REMOTE_HOST" ] && echo "      (add -r $REMOTE_HOST for remote verification)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
