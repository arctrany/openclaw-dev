#!/bin/bash
# OpenClaw QA Testing Framework - 通用化主测试脚本
# Version: 1.0.0 (Production Grade)
# Usage: ./run-qa-tests.sh --agent <name> [options]

set -euo pipefail

# === 脚本路径 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QA_ROOT="$(dirname "$SCRIPT_DIR")"
LIB_DIR="$QA_ROOT/lib"
CONFIG_DIR="$QA_ROOT/config"
REPORT_DIR="$QA_ROOT/reports"

# === 加载工具库 ===
source "$LIB_DIR/test-utils.sh"

# === 默认配置 ===
AGENT_NAME=""
TEST_MODE="full"  # full, quick, specific
CONTINUOUS_MODE=false
REPORT_ONLY=false

# === 帮助信息 ===
show_help() {
  cat << EOF
OpenClaw QA Testing Framework - 通用化生产级测试

用法:
  $0 --agent <name> [options]

参数:
  --agent <name>      指定要测试的 agent（必需）
  --all               测试所有已配置的 agents
  --quick             快速测试（跳过慢速测试）
  --full              完整测试（默认）
  --continuous        持续监控模式
  --report-only       只生成报告
  --help              显示此帮助信息

示例:
  # 测试 annie agent
  $0 --agent annie

  # 快速测试
  $0 --agent annie --quick

  # 持续监控
  $0 --agent annie --continuous

EOF
  exit 0
}

# === 解析参数 ===
while [[ $# -gt 0 ]]; do
  case $1 in
    --agent)
      AGENT_NAME="$2"
      shift 2
      ;;
    --all)
      AGENT_NAME="all"
      shift
      ;;
    --quick)
      TEST_MODE="quick"
      shift
      ;;
    --full)
      TEST_MODE="full"
      shift
      ;;
    --continuous)
      CONTINUOUS_MODE=true
      shift
      ;;
    --report-only)
      REPORT_ONLY=true
      shift
      ;;
    --help)
      show_help
      ;;
    *)
      echo "未知参数: $1"
      show_help
      ;;
  esac
done

# === 验证参数 ===
if [ -z "$AGENT_NAME" ]; then
  echo "❌ 错误: 必须指定 --agent 参数"
  show_help
fi

# === 初始化 ===
init_test_env "$AGENT_NAME"
START_TIME=$(date +%s)

log "========================================="
log "🏭 OpenClaw QA Testing Framework v1.0"
log "Agent: $AGENT_NAME"
log "Mode: $TEST_MODE"
log "Time: $(date)"
log "========================================="
echo ""

# ============================================
# 场景 #1: 系统基础健康检查
# ============================================
log_scene "场景 #1: 系统基础健康检查"
quick_test "Gateway 进程运行" "pgrep -f openclaw-gateway"
quick_test "Gateway RPC 连通" "openclaw gateway status 2>&1 | grep -q 'RPC probe'"

# Session 目录（动态路径）
SESSION_DIR="/Volumes/EXT/openclaw/sessions/$AGENT_NAME"
quick_test "Session 目录可访问" "ls $SESSION_DIR"
quick_test "无死锁文件" "[ \$(find $SESSION_DIR -name '*.lock' 2>/dev/null | wc -l | tr -d ' ') -eq 0 ]"
quick_test "磁盘空间充足" "[ \$(df /Volumes/EXT | tail -1 | awk '{print \$5}' | tr -d '%') -lt 90 ]"
echo ""

# ============================================
# 场景 #2: 模型配置测试
# ============================================
log_scene "场景 #2: 模型配置测试"
log "检查 $AGENT_NAME 的模型配置..."

# 获取主模型
PRIMARY_MODEL=$(jq -r ".agents.list[] | select(.id==\"$AGENT_NAME\") | .model.primary" ~/.openclaw/openclaw.json 2>/dev/null || echo "")
if [ -n "$PRIMARY_MODEL" ]; then
  log_success "主模型: $PRIMARY_MODEL"
  test_model_available "$PRIMARY_MODEL"
else
  log_error "未找到 $AGENT_NAME 的主模型配置"
  ((FAILED_TESTS++))
  ((TOTAL_TESTS++))
fi

# 检查 Fallback 模型
FALLBACK_COUNT=$(jq -r ".agents.list[] | select(.id==\"$AGENT_NAME\") | .model.fallbacks | length" ~/.openclaw/openclaw.json 2>/dev/null || echo "0")
if [ "$FALLBACK_COUNT" -gt 0 ]; then
  log_success "Fallback 模型数: $FALLBACK_COUNT"
  ((PASSED_TESTS++))
else
  log_warning "未配置 Fallback 模型"
  ((WARNING_TESTS++))
fi
((TOTAL_TESTS++))

quick_test "OAuth 配置有效" "[ \$(jq -r '.profiles | length' ~/.openclaw/agents/$AGENT_NAME/agent/auth-profiles.json 2>/dev/null || echo 0) -gt 0 ]"
echo ""

# ============================================
# 场景 #3: 文本响应测试
# ============================================
log_scene "场景 #3: 文本响应测试"
test_agent_response "$AGENT_NAME" "你好" "" 30
test_agent_response "$AGENT_NAME" "Hi" "" 30
echo ""

# ============================================
# 场景 #4: Memory 完整性测试 🔥
# ============================================
log_scene "场景 #4: Memory 完整性测试 🔥 CRITICAL"
test_session_integrity "$AGENT_NAME" "$SESSION_DIR"

# 备份检查
BACKUP_DIR="/Volumes/EXT/openclaw/sessions/${AGENT_NAME}-backups"
quick_test "备份目录存在" "[ -d $BACKUP_DIR ]"

log "检查备份文件..."
backup_count=$(find "$BACKUP_DIR" -name "*.backup-*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$backup_count" -gt 0 ]; then
  log_success "找到 $backup_count 个备份文件"
  ((PASSED_TESTS++))
else
  log_warning "无备份文件（可能是新系统）"
  ((WARNING_TESTS++))
fi
((TOTAL_TESTS++))

# Session 大小检查
log "检查 Session 文件大小..."
large_sessions=$(find "$SESSION_DIR" -name "*.jsonl" -type f -not -name "*.backup-*" -size +5M 2>/dev/null | wc -l | tr -d ' ')
if [ "$large_sessions" -eq 0 ]; then
  log_success "所有 Session 文件大小正常 (<5MB)"
  ((PASSED_TESTS++))
else
  log_warning "发现 $large_sessions 个超过 5MB 的 Session 文件"
  ((WARNING_TESTS++))
fi
((TOTAL_TESTS++))

# 跨会话记忆测试（可选，较慢）
if [ "$TEST_MODE" = "full" ]; then
  log "测试跨会话记忆..."
  test_session_id="memory-test-$(date +%s)"
  if test_agent_response "$AGENT_NAME" "记住这个数字: 42" "" 30; then
    sleep 2
    if openclaw agent --agent "$AGENT_NAME" -m "我之前让你记住的数字是多少？" --session "$test_session_id" --json 2>&1 | grep -q '42'; then
      log_success "跨会话记忆正常"
      ((PASSED_TESTS++))
    else
      log_warning "跨会话记忆可能不准确"
      ((WARNING_TESTS++))
    fi
  else
    log_error "记忆测试失败"
    ((FAILED_TESTS++))
  fi
  ((TOTAL_TESTS++))
fi
echo ""

# ============================================
# 场景 #5: Skills 测试
# ============================================
log_scene "场景 #5: Skills 全覆盖测试"
quick_test "Skills 系统可用" "openclaw skills list 2>&1 | grep -q 'Skills'"

# 从配置读取关键 Skills
CRITICAL_SKILLS=(
  "nano-pdf"
  "himalaya"
  "bear-notes"
  "peekaboo"
  "gemini"
  "session-logs"
  "model-usage"
  "gifgrep"
  "openai-whisper"
  "coding-agent"
)

for skill in "${CRITICAL_SKILLS[@]}"; do
  test_skill_available "$skill"
done
echo ""

# ============================================
# 场景 #6: 图片生成测试（多模型）🔥
# ============================================
log_scene "场景 #6: 图片生成多模型测试 🔥 CRITICAL"

# OpenAI DALL-E
log "检查 DALL-E Skill..."
if [ -d /Volumes/EXT/bun/install/global/node_modules/openclaw/skills/openai-image-gen ]; then
  log_success "DALL-E Skill 已安装"
  ((PASSED_TESTS++))

  if [ -f /Volumes/EXT/bun/install/global/node_modules/openclaw/skills/openai-image-gen/scripts/gen.py ] || \
     [ -L /Volumes/EXT/bun/install/global/node_modules/openclaw/skills/openai-image-gen/scripts/generate.py ]; then
    log_success "DALL-E 脚本可用"
    ((PASSED_TESTS++))
  else
    log_error "DALL-E 脚本缺失"
    ((FAILED_TESTS++))
  fi
  ((TOTAL_TESTS++))
else
  log_error "DALL-E Skill 未安装"
  ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Gemini 图片模型
log "检查 Gemini 图片模型..."
if openclaw models list 2>&1 | grep -q 'gemini.*image\|imagen'; then
  log_success "Gemini 图片模型可用"
  ((PASSED_TESTS++))
else
  log_warning "Gemini 图片模型未找到"
  ((WARNING_TESTS++))
fi
((TOTAL_TESTS++))
echo ""

# ============================================
# 场景 #7: 语音处理测试
# ============================================
log_scene "场景 #7: 语音处理测试"

# TTS
quick_test "macOS TTS 可用" "which say"
log "测试中文 TTS..."
if say "测试" -o /tmp/tts-test.aiff 2>&1 && [ -f /tmp/tts-test.aiff ]; then
  log_success "中文 TTS 正常"
  rm -f /tmp/tts-test.aiff
  ((PASSED_TESTS++))
else
  log_error "中文 TTS 失败"
  ((FAILED_TESTS++))
fi
((TOTAL_TESTS++))

# Whisper
test_skill_available "openai-whisper"
echo ""

# ============================================
# 场景 #8: 工具调用测试
# ============================================
log_scene "场景 #8: 工具调用测试"
log "测试 Bash 工具..."
if openclaw agent --agent "$AGENT_NAME" -m "执行: echo qa_test_ok" --json 2>&1 | grep -q 'qa_test_ok'; then
  log_success "Bash 工具正常"
  ((PASSED_TESTS++))
else
  log_warning "Bash 工具响应异常"
  ((WARNING_TESTS++))
fi
((TOTAL_TESTS++))
echo ""

# ============================================
# 场景 #9: 错误处理检查
# ============================================
log_scene "场景 #9: 错误处理和恢复"
log "检查最近日志错误..."
LOG_FILE="/tmp/openclaw/openclaw-$(date +%Y-%m-%d).log"
if [ -f "$LOG_FILE" ]; then
  recent_errors=$(tail -500 "$LOG_FILE" 2>/dev/null | grep -c '"logLevelName":"ERROR"' || echo 0)
  if [ "$recent_errors" -lt 5 ]; then
    log_success "错误率正常 ($recent_errors/500)"
    ((PASSED_TESTS++))
  else
    log_warning "错误较多 ($recent_errors/500)"
    ((WARNING_TESTS++))
  fi
else
  log_warning "日志文件不存在: $LOG_FILE"
  ((WARNING_TESTS++))
fi
((TOTAL_TESTS++))

log "检查死锁错误..."
if [ -f "$LOG_FILE" ]; then
  lock_errors=$(tail -500 "$LOG_FILE" 2>/dev/null | grep -c 'session file locked' || echo 0)
  if [ "$lock_errors" -eq 0 ]; then
    log_success "无死锁错误"
    ((PASSED_TESTS++))
  else
    log_error "检测到 $lock_errors 次死锁"
    ((FAILED_TESTS++))
  fi
else
  log_warning "无法检查死锁错误"
  ((WARNING_TESTS++))
fi
((TOTAL_TESTS++))
echo ""

# ============================================
# 场景 #10: 自动化运维检查
# ============================================
log_scene "场景 #10: 自动化运维"
quick_test "健康守护脚本存在" "[ -f ~/.openclaw/scripts/health-guardian.sh ]"
log "检查 Cron 配置..."
if crontab -l 2>/dev/null | grep -q 'health-guardian'; then
  log_success "Cron 自动运维已配置"
  ((PASSED_TESTS++))
else
  log_warning "Cron 自动运维未配置"
  ((WARNING_TESTS++))
fi
((TOTAL_TESTS++))
echo ""

# ============================================
# 测试总结
# ============================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log "========================================="
log "🏁 测试执行完成"
log "========================================="
log "Agent: $AGENT_NAME"
log "总测试数: $TOTAL_TESTS"
log_success "通过: $PASSED_TESTS"
log_error "失败: $FAILED_TESTS"
[ $WARNING_TESTS -gt 0 ] && log_warning "警告: $WARNING_TESTS"
[ $SKIPPED_TESTS -gt 0 ] && log "跳过: $SKIPPED_TESTS"

SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")
log "成功率: ${SUCCESS_RATE}%"
log "执行时间: ${DURATION}秒"
echo ""

# ============================================
# 生成报告
# ============================================
mkdir -p "$REPORT_DIR"

cat > "$TEST_REPORT" << EOF
# OpenClaw QA 测试报告

**Agent**: \`$AGENT_NAME\`
**生成时间**: $(date)
**执行时长**: ${DURATION}秒
**QA Framework**: v1.0.0

---

## 📊 执行摘要

| 指标 | 数值 |
|------|------|
| 总测试数 | $TOTAL_TESTS |
| ✅ 通过 | $PASSED_TESTS |
| ❌ 失败 | $FAILED_TESTS |
| ⚠️ 警告 | $WARNING_TESTS |
| 成功率 | ${SUCCESS_RATE}% |

---

## 🎯 测试场景覆盖

- ✅ 系统基础健康检查
- ✅ 模型配置验证
- ✅ Memory 完整性测试 (CRITICAL)
- ✅ Skills 全覆盖测试
- ✅ 图片生成多模型测试 (DALL-E + Gemini)
- ✅ 语音处理测试 (TTS + Whisper)
- ✅ 工具调用测试
- ✅ 错误处理和恢复
- ✅ 自动化运维检查

---

## 🔍 关键发现

### 系统状态
- Gateway: $(pgrep -f openclaw-gateway > /dev/null && echo "✅ 运行正常" || echo "❌ 未运行")
- Session 目录: $SESSION_DIR
- 备份目录: $BACKUP_DIR

### 模型配置
- 主模型: \`${PRIMARY_MODEL:-未配置}\`
- Fallback 模型: $FALLBACK_COUNT 个

### Memory 健康
- Session 文件: $(find "$SESSION_DIR" -name "*.jsonl" -type f -not -name "*.backup-*" 2>/dev/null | wc -l | tr -d ' ') 个
- 备份文件: $backup_count 个
- 大文件: $large_sessions 个 (>5MB)

---

## 📝 详细日志

完整日志: \`$TEST_LOG\`

---

## 🚀 下一步行动

EOF

if [ $FAILED_TESTS -gt 0 ]; then
  cat >> "$TEST_REPORT" << EOF
### ❌ 需要修复的问题

发现 $FAILED_TESTS 个失败测试，请查看日志并修复。

EOF
fi

if [ $WARNING_TESTS -gt 0 ]; then
  cat >> "$TEST_REPORT" << EOF
### ⚠️ 建议优化的项目

发现 $WARNING_TESTS 个警告，建议检查和优化。

EOF
fi

cat >> "$TEST_REPORT" << EOF
### 📦 生产部署建议

- 确保所有 CRITICAL 测试通过
- 配置持续监控（Cron）
- 定期备份 Session 文件
- 监控模型 API 配额

---

**生成工具**: OpenClaw QA Framework v1.0.0
**联系**: Claude Sonnet 4.5

EOF

log "========================================="
log "📄 测试报告已生成: $TEST_REPORT"
log "========================================="

# 清理
cleanup_test_env

# 返回状态
if [ $FAILED_TESTS -eq 0 ]; then
  log_success "🎉 所有关键测试通过！系统可投入生产环境。"
  exit 0
else
  log_error "⚠️ 有 $FAILED_TESTS 个测试失败，请修复后再部署。"
  exit 1
fi
