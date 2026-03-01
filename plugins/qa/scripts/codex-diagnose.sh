#!/bin/bash
# Codex-friendly wrapper for OpenClaw QA diagnostics.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QA_ROOT="$(dirname "$SCRIPT_DIR")"

export QA_REPORT_DIR="${QA_REPORT_DIR:-$QA_ROOT/reports}"
export QA_GENERATED_BY="${QA_GENERATED_BY:-OpenClaw QA Framework via Codex}"
export OPENCLAW_HOME_DIR="${OPENCLAW_HOME_DIR:-${OPENCLAW_HOME:-$HOME/.openclaw}}"

# Best-effort auto-detection for common session layouts.
if [ -z "${QA_SESSIONS_ROOT:-}" ]; then
  if [ -d /Volumes/EXT/openclaw/sessions ]; then
    export QA_SESSIONS_ROOT="/Volumes/EXT/openclaw/sessions"
  elif [ -d "$HOME/.openclaw/sessions" ]; then
    export QA_SESSIONS_ROOT="$HOME/.openclaw/sessions"
  fi
fi

mkdir -p "$QA_REPORT_DIR"

set +e
"$SCRIPT_DIR/run-qa-tests.sh" "$@"
status=$?
set -e

latest_report=""
if [ -d "$QA_REPORT_DIR" ]; then
  latest_report="$(find "$QA_REPORT_DIR" -type f -name 'qa-report-*.md' -print 2>/dev/null | sort | tail -1 || true)"
fi

if [ -n "$latest_report" ]; then
  echo ""
  echo "Latest QA report: $latest_report"
fi

exit "$status"
