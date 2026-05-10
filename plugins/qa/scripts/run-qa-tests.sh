#!/usr/bin/env bash
# Sandbox-safe QA runner for openclaw-dev capability checks.
# Usage:
#   bash plugins/qa/scripts/run-qa-tests.sh --agent <agent-id> [--quick|--full]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QA_ROOT="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(cd "$QA_ROOT/../.." && pwd)"

AGENT_ID=""
MODE="quick"
FOCUS_AREA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      AGENT_ID="${2:-}"
      shift 2
      ;;
    --quick)
      MODE="quick"
      shift
      ;;
    --full)
      MODE="full"
      shift
      ;;
    --fix)
      # This runner is intentionally read-only. Accept the flag for compatibility.
      shift
      ;;
    --help|-h)
      cat <<'EOF'
Usage: bash plugins/qa/scripts/run-qa-tests.sh --agent <agent-id> [--quick|--full] [--fix] [focus-area]

Read-only QA checks for openclaw-dev:
  --agent <id>   Required logical target agent id
  --quick        Core lint + runtime checks
  --full         Adds security scan, shell/python syntax, and route smoke tests
  --fix          Accepted for compatibility; no mutations are performed
EOF
      exit 0
      ;;
    *)
      if [[ -z "$FOCUS_AREA" ]]; then
        FOCUS_AREA="$1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$AGENT_ID" ]]; then
  echo "run-qa-tests.sh: missing required --agent <agent-id>" >&2
  exit 2
fi

OPENCLAW_HOME_DIR="${OPENCLAW_HOME_DIR:-${OPENCLAW_HOME:-$HOME/.openclaw}}"
QA_REPORT_DIR="${QA_REPORT_DIR:-$QA_ROOT/reports}"
QA_RUNTIME_LOG_DIR="${QA_RUNTIME_LOG_DIR:-/tmp/openclaw}"
REPORT_TS="$(date '+%Y%m%d-%H%M%S')"
REPORT_PATH="${QA_REPORT_DIR}/qa-report-${REPORT_TS}.md"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$QA_REPORT_DIR" "$QA_RUNTIME_LOG_DIR"

PROFILE_ARGS=()
if [[ -n "${OPENCLAW_PROFILE:-}" ]]; then
  PROFILE_ARGS+=(--profile "$OPENCLAW_PROFILE")
fi

FAILURES=0
WARNINGS=0
PASSED=0
CHECK_ROWS=()

run_capture() {
  local name="$1"
  shift
  local slug
  slug="$(echo "$name" | tr ' /' '__' | tr -cd '[:alnum:]_-')"
  local outfile="${TMP_DIR}/${slug}.log"
  local status=0

  if "$@" >"$outfile" 2>&1; then
    status=0
  else
    status=$?
  fi

  local summary
  summary="$(tail -n 20 "$outfile" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g' | sed 's/^ //; s/ $//')"
  if [[ -z "$summary" ]]; then
    summary="(no output)"
  fi

  printf '%s\t%s\t%s\n' "$status" "$outfile" "$summary"
}

record_check() {
  local name="$1" severity="$2" status="$3" summary="$4"
  CHECK_ROWS+=("${name}|${severity}|${status}|${summary}")
  case "$status" in
    PASS) PASSED=$((PASSED + 1)) ;;
    WARN) WARNINGS=$((WARNINGS + 1)) ;;
    FAIL) FAILURES=$((FAILURES + 1)) ;;
  esac
}

run_required() {
  local name="$1"
  shift
  local result status outfile summary
  result="$(run_capture "$name" "$@")"
  status="$(printf '%s' "$result" | cut -f1)"
  outfile="$(printf '%s' "$result" | cut -f2)"
  summary="$(printf '%s' "$result" | cut -f3-)"
  if [[ "$status" == "0" ]]; then
    record_check "$name" "required" "PASS" "$summary"
  else
    record_check "$name" "required" "FAIL" "$summary"
  fi
}

run_optional() {
  local name="$1"
  shift
  local result status outfile summary
  result="$(run_capture "$name" "$@")"
  status="$(printf '%s' "$result" | cut -f1)"
  outfile="$(printf '%s' "$result" | cut -f2)"
  summary="$(printf '%s' "$result" | cut -f3-)"
  if [[ "$status" == "0" ]]; then
    record_check "$name" "runtime" "PASS" "$summary"
  else
    record_check "$name" "runtime" "WARN" "$summary"
  fi
}

if command -v openclaw >/dev/null 2>&1; then
  run_required "openclaw --version" openclaw --version
  run_optional "openclaw update status" openclaw "${PROFILE_ARGS[@]}" update status --json
  run_optional "openclaw health" openclaw "${PROFILE_ARGS[@]}" health --json
  run_optional "openclaw status --deep --all" openclaw "${PROFILE_ARGS[@]}" status --deep --all --json
  run_optional "openclaw doctor" openclaw "${PROFILE_ARGS[@]}" doctor
else
  record_check "openclaw binary" "required" "FAIL" "openclaw command not found in PATH"
fi

run_required "skill-lint node-operations" bash "$REPO_ROOT/scripts/skill-lint.sh" "$REPO_ROOT/skills/openclaw-node-operations"
run_required "skill-lint skill-development" bash "$REPO_ROOT/scripts/skill-lint.sh" "$REPO_ROOT/skills/openclaw-skill-development"
run_required "skill-lint dev-knowledgebase" bash "$REPO_ROOT/scripts/skill-lint.sh" "$REPO_ROOT/skills/openclaw-dev-knowledgebase"
run_required "routing validate_policy" python3 "$REPO_ROOT/skills/model-routing-governor/scripts/validate_policy.py"

if [[ "$MODE" == "full" ]]; then
  run_required "routing smoke_test_routes" python3 "$REPO_ROOT/skills/model-routing-governor/scripts/smoke_test_routes.py"
  run_required "security-scan --strict" bash "$REPO_ROOT/scripts/security-scan.sh" --strict
  run_required "git diff --check" git -C "$REPO_ROOT" diff --check
  run_required "shell syntax plugins/qa/scripts" bash -n "$SCRIPT_DIR/codex-diagnose.sh" "$SCRIPT_DIR/run-qa-tests.sh"
  run_required "python compile scripts" python3 -m py_compile "$REPO_ROOT"/scripts/*.py
fi

{
  echo "# OpenClaw QA Report"
  echo
  echo "- generated_at: $(date -Iseconds)"
  echo "- generated_by: ${QA_GENERATED_BY:-OpenClaw QA Framework via Codex}"
  echo "- agent_id: ${AGENT_ID}"
  echo "- mode: ${MODE}"
  echo "- focus_area: ${FOCUS_AREA:-none}"
  echo "- repo_root: ${REPO_ROOT}"
  echo "- openclaw_home_dir: ${OPENCLAW_HOME_DIR}"
  echo "- openclaw_profile: ${OPENCLAW_PROFILE:-default}"
  echo "- report_path: ${REPORT_PATH}"
  echo
  echo "## Summary"
  echo
  echo "- passed: ${PASSED}"
  echo "- warnings: ${WARNINGS}"
  echo "- failures: ${FAILURES}"
  echo
  echo "## Checks"
  echo
  echo "| Check | Severity | Status | Summary |"
  echo "|------|----------|--------|---------|"
  for row in "${CHECK_ROWS[@]}"; do
    IFS='|' read -r name severity status summary <<<"$row"
    echo "| ${name} | ${severity} | ${status} | ${summary//|/\\/} |"
  done
  echo
  echo "## Notes"
  echo
  cat <<'EOF'
- Runtime checks are read-only. This runner never calls `openclaw doctor --fix`, onboarding, channel send, pairing, or destructive commands.
- `WARN` on runtime checks usually means the selected profile is intentionally isolated or unconfigured, not that repo changes regressed.
- Use `OPENCLAW_HOME`, `OPENCLAW_PROFILE`, and `OPENCLAW_WORKSPACE` to point QA at a sandbox profile.
EOF
} >"$REPORT_PATH"

echo "QA report written to ${REPORT_PATH}"
echo "Summary: passed=${PASSED} warnings=${WARNINGS} failures=${FAILURES}"

if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi
