#!/bin/bash
# OpenClaw QA Testing Framework - 通用测试工具库
# Version: 1.0.0

# === 颜色输出 ===
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# === 全局变量 ===
export TOTAL_TESTS=0
export PASSED_TESTS=0
export FAILED_TESTS=0
export WARNING_TESTS=0
export SKIPPED_TESTS=0

# === 日志函数 ===
log() {
  local level="${2:-INFO}"
  echo -e "${BLUE}[$(date '+%H:%M:%S')] [$level]${NC} $1" | tee -a "${TEST_LOG:-/tmp/qa-test.log}"
}

log_success() {
  echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}" | tee -a "${TEST_LOG:-/tmp/qa-test.log}"
}

log_error() {
  echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}" | tee -a "${TEST_LOG:-/tmp/qa-test.log}"
}

log_warning() {
  echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}" | tee -a "${TEST_LOG:-/tmp/qa-test.log}"
}

log_scene() {
  echo -e "${PURPLE}[$(date '+%H:%M:%S')] 🎬 $1${NC}" | tee -a "${TEST_LOG:-/tmp/qa-test.log}"
}

log_debug() {
  if [ "${DEBUG:-0}" = "1" ]; then
    echo -e "${CYAN}[$(date '+%H:%M:%S')] [DEBUG] $1${NC}" | tee -a "${TEST_LOG:-/tmp/qa-test.log}"
  fi
}

# === 快速测试函数 ===
quick_test() {
  local name="$1"
  local cmd="$2"
  local timeout="${3:-10}"

  ((TOTAL_TESTS++))
  local start=$(date +%s)

  if eval "$cmd" > /dev/null 2>&1; then
    local duration=$(($(date +%s) - start))
    log_success "$name (${duration}s)"
    ((PASSED_TESTS++))
    return 0
  else
    local duration=$(($(date +%s) - start))
    log_error "$name FAILED (${duration}s)"
    ((FAILED_TESTS++))
    return 1
  fi
}

# === 详细测试函数（带输出）===
detailed_test() {
  local name="$1"
  local cmd="$2"
  local timeout="${3:-30}"
  local output_file="${4:-/tmp/test-output-$$.txt}"

  ((TOTAL_TESTS++))
  local start=$(date +%s)

  if eval "$cmd" > "$output_file" 2>&1; then
    local duration=$(($(date +%s) - start))
    log_success "$name (${duration}s)"
    ((PASSED_TESTS++))
    return 0
  else
    local duration=$(($(date +%s) - start))
    log_error "$name FAILED (${duration}s)"
    log_debug "Output: $(cat "$output_file" | head -10)"
    ((FAILED_TESTS++))
    return 1
  fi
}

# === Agent 响应测试（通用）===
test_agent_response() {
  local agent_name="$1"
  local message="$2"
  local expected_pattern="${3:-}"
  local timeout="${4:-30}"

  ((TOTAL_TESTS++))
  log "测试 $agent_name 响应: $message"

  local output_file="/tmp/agent-response-$$.json"
  if openclaw agent --agent "$agent_name" -m "$message" --json > "$output_file" 2>&1; then
    local content=$(jq -r '.content' "$output_file" 2>/dev/null || echo "")

    if [ -n "$content" ]; then
      if [ -n "$expected_pattern" ]; then
        if echo "$content" | grep -q "$expected_pattern"; then
          log_success "$agent_name 响应正常（匹配: $expected_pattern）"
          ((PASSED_TESTS++))
          rm -f "$output_file"
          return 0
        else
          log_error "$agent_name 响应不匹配（期望: $expected_pattern）"
          ((FAILED_TESTS++))
          rm -f "$output_file"
          return 1
        fi
      else
        log_success "$agent_name 响应正常"
        ((PASSED_TESTS++))
        rm -f "$output_file"
        return 0
      fi
    else
      log_error "$agent_name 响应为空"
      ((FAILED_TESTS++))
      rm -f "$output_file"
      return 1
    fi
  else
    log_error "$agent_name 调用失败"
    ((FAILED_TESTS++))
    rm -f "$output_file"
    return 1
  fi
}

# === Memory 测试工具 ===
test_session_integrity() {
  local agent_name="$1"
  local session_dir="${2:-/Volumes/EXT/openclaw/sessions/$agent_name}"

  log "检查 $agent_name Session 完整性..."

  # 检查目录存在
  if [ ! -d "$session_dir" ]; then
    log_error "Session 目录不存在: $session_dir"
    ((FAILED_TESTS++))
    ((TOTAL_TESTS++))
    return 1
  fi

  # 检查 JSON 格式
  local corrupted=0
  local total=0
  for session in "$session_dir"/*.jsonl; do
    [ -f "$session" ] || continue
    ((total++))
    if ! tail -1 "$session" | jq empty 2>/dev/null; then
      log_error "Session 文件损坏: $(basename "$session")"
      ((corrupted++))
    fi
  done

  ((TOTAL_TESTS++))
  if [ $corrupted -eq 0 ]; then
    log_success "所有 Session 文件格式正确 ($total 个)"
    ((PASSED_TESTS++))
    return 0
  else
    log_error "发现 $corrupted/$total 个损坏的 Session 文件"
    ((FAILED_TESTS++))
    return 1
  fi
}

# === Skills 测试工具 ===
test_skill_available() {
  local skill_name="$1"

  ((TOTAL_TESTS++))
  if openclaw skills list 2>&1 | grep -q "$skill_name"; then
    log_success "Skill 可用: $skill_name"
    ((PASSED_TESTS++))
    return 0
  else
    log_error "Skill 不可用: $skill_name"
    ((FAILED_TESTS++))
    return 1
  fi
}

# === 模型测试工具 ===
test_model_available() {
  local model_name="$1"

  ((TOTAL_TESTS++))
  if openclaw models list 2>&1 | grep -q "$model_name"; then
    log_success "模型可用: $model_name"
    ((PASSED_TESTS++))
    return 0
  else
    log_error "模型不可用: $model_name"
    ((FAILED_TESTS++))
    return 1
  fi
}

# === 获取测试统计 ===
get_test_stats() {
  local success_rate=0
  if [ $TOTAL_TESTS -gt 0 ]; then
    success_rate=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")
  fi

  cat << EOF
{
  "total": $TOTAL_TESTS,
  "passed": $PASSED_TESTS,
  "failed": $FAILED_TESTS,
  "warnings": $WARNING_TESTS,
  "skipped": $SKIPPED_TESTS,
  "success_rate": $success_rate
}
EOF
}

# === 读取配置 ===
load_config() {
  local config_file="${1:-/Volumes/EXT/projects/openclaw-dev/plugins/qa/config/qa-config.json}"

  if [ ! -f "$config_file" ]; then
    log_warning "配置文件不存在: $config_file，使用默认配置"
    export TIMEOUT_FAST=10
    export TIMEOUT_NORMAL=30
    export TIMEOUT_SLOW=60
    return 1
  fi

  export TIMEOUT_FAST=$(jq -r '.timeout.fast // 10' "$config_file")
  export TIMEOUT_NORMAL=$(jq -r '.timeout.normal // 30' "$config_file")
  export TIMEOUT_SLOW=$(jq -r '.timeout.slow // 60' "$config_file")

  log_debug "配置已加载: FAST=${TIMEOUT_FAST}s, NORMAL=${TIMEOUT_NORMAL}s, SLOW=${TIMEOUT_SLOW}s"
}

# === 初始化测试环境 ===
init_test_env() {
  local agent_name="${1:-default}"

  export TEST_LOG="/tmp/qa-test-${agent_name}-$(date +%s).log"
  export TEST_REPORT="/Volumes/EXT/projects/openclaw-dev/plugins/qa/reports/qa-report-${agent_name}-$(date +%s).md"

  # 重置统计
  export TOTAL_TESTS=0
  export PASSED_TESTS=0
  export FAILED_TESTS=0
  export WARNING_TESTS=0
  export SKIPPED_TESTS=0

  # 加载配置
  load_config

  log "测试环境初始化完成"
  log "Agent: $agent_name"
  log "日志: $TEST_LOG"
  log "报告: $TEST_REPORT"
}

# === 清理测试环境 ===
cleanup_test_env() {
  log "清理测试环境..."
  # 清理临时文件
  rm -f /tmp/agent-response-*.json
  rm -f /tmp/test-output-*.txt
}
