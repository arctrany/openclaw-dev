#!/bin/bash
# uninstall.sh — 卸载 openclaw-dev 技能包
# 支持: Claude Code, Gemini Antigravity, Codex CLI, Qwen Code
#
# Usage:
#   ./uninstall.sh                              # 自动检测并卸载全局平台
#   ./uninstall.sh --project ~/myproject        # 从项目卸载 (Gemini/Qwen)
#   ./uninstall.sh --platforms claude,codex     # 只从指定平台卸载
#   ./uninstall.sh --all --project ~/myproject  # 全部平台
#   ./uninstall.sh --dry-run                    # 预览不执行

set -euo pipefail

# ── 颜色 ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── 变量 ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR=""
PLATFORMS=""
DRY_RUN=false
ALL_PLATFORMS=false
REMOVED=0
SKIPPED=0

# ── Skill 列表 ───────────────────────────────────────
SKILL_DIRS=(
  "openclaw-dev-knowledgebase"
  "openclaw-skill-development"
  "openclaw-node-operations"
)

# ── 工具函数 ──────────────────────────────────────────
info()    { echo -e "${BLUE}ℹ${NC}  $1"; }
ok()      { echo -e "${GREEN}✅${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠️${NC}  $1"; }
err()     { echo -e "${RED}❌${NC} $1"; }
step()    { echo -e "${CYAN}▸${NC}  ${BOLD}$1${NC}"; }
dry_run() { echo -e "${YELLOW}[DRY-RUN]${NC} $1"; }

remove_symlink() {
  local path="$1"
  local label="$2"

  if [ -L "$path" ]; then
    if $DRY_RUN; then
      dry_run "rm $path"
    else
      rm "$path"
      ok "$label: 已移除"
    fi
    REMOVED=$((REMOVED + 1))
  elif [ -e "$path" ]; then
    warn "$label: 存在但不是 symlink, 跳过 ($path)"
    SKIPPED=$((SKIPPED + 1))
  else
    warn "$label: 未安装"
    SKIPPED=$((SKIPPED + 1))
  fi
}

# ── 平台卸载函数 ──────────────────────────────────────

uninstall_claude() {
  step "从 Claude Code 卸载"
  remove_symlink "$HOME/.claude/plugins/openclaw-dev" "Claude Code global"

  # 移除项目级 CLAUDE.md 中的 openclaw-dev 段落
  if [ -n "$PROJECT_DIR" ]; then
    local claude_md="$PROJECT_DIR/CLAUDE.md"
    if [ -f "$claude_md" ] && grep -q "openclaw-dev" "$claude_md"; then
      if $DRY_RUN; then
        dry_run "从 $claude_md 移除 openclaw-dev 段落"
      else
        awk '/<!-- openclaw-dev -->/{skip=1} /<!-- \/openclaw-dev -->/{skip=0; next} !skip' "$claude_md" > "$claude_md.tmp" && mv "$claude_md.tmp" "$claude_md"
        ok "Claude CLAUDE.md: 已移除项目级 openclaw-dev 引用"
      fi
      REMOVED=$((REMOVED + 1))
    fi
  fi
}

uninstall_codex() {
  step "从 Codex CLI 卸载"

  # 移除 skills 链接
  remove_symlink "$HOME/.codex/openclaw-dev-skills" "Codex global skills"

  # 辅助函数: 用 awk 安全地移除 marker 块 (避免 sed 与 HTML 注释的转义问题)
  _remove_marker_block() {
    local file="$1"
    local label="$2"
    local marker="openclaw-dev"

    if [ -f "$file" ] && grep -q "$marker" "$file"; then
      if $DRY_RUN; then
        dry_run "从 $file 移除 openclaw-dev 段落"
      else
        awk '/<!-- openclaw-dev -->/{skip=1} /<!-- \/openclaw-dev -->/{skip=0; next} !skip' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        ok "$label: 已移除 openclaw-dev 引用"
      fi
      REMOVED=$((REMOVED + 1))
    else
      warn "$label: 无 openclaw-dev 引用"
      SKIPPED=$((SKIPPED + 1))
    fi
  }

  # 移除全局 instructions.md 中的 openclaw-dev 段落
  _remove_marker_block "$HOME/.codex/instructions.md" "Codex instructions.md"

  # 移除项目级 AGENTS.MD 中的 openclaw-dev 段落
  if [ -n "$PROJECT_DIR" ]; then
    _remove_marker_block "$PROJECT_DIR/AGENTS.MD" "Codex AGENTS.MD"
  fi
}

uninstall_gemini() {
  if [ -z "$PROJECT_DIR" ]; then
    err "Gemini 需要 --project <path> 参数"
    return 1
  fi
  step "从 Gemini Antigravity 卸载 ← $PROJECT_DIR"
  for skill in "${SKILL_DIRS[@]}"; do
    remove_symlink "$PROJECT_DIR/.agents/skills/$skill" "Gemini/$skill"
  done
}

uninstall_qwen() {
  if [ -z "$PROJECT_DIR" ]; then
    err "Qwen 需要 --project <path> 参数"
    return 1
  fi
  step "从 Qwen Code 卸载 ← $PROJECT_DIR"
  for skill in "${SKILL_DIRS[@]}"; do
    remove_symlink "$PROJECT_DIR/.qwen/skills/$skill" "Qwen/$skill"
  done
}

# ── 平台检测 ──────────────────────────────────────────

detect_installed() {
  local detected=()

  if [ -L "$HOME/.claude/plugins/openclaw-dev" ]; then
    detected+=("claude")
  fi

  if [ -L "$HOME/.codex/openclaw-dev-skills" ] || \
     ([ -f "$HOME/.codex/instructions.md" ] && grep -q "openclaw-dev" "$HOME/.codex/instructions.md" 2>/dev/null); then
    detected+=("codex")
  fi

  if [ -n "$PROJECT_DIR" ]; then
    # Claude 项目级 CLAUDE.md
    if [ -f "$PROJECT_DIR/CLAUDE.md" ] && grep -q "openclaw-dev" "$PROJECT_DIR/CLAUDE.md" 2>/dev/null; then
      local has_claude=false
      for p in "${detected[@]}"; do [ "$p" = "claude" ] && has_claude=true; done
      if ! $has_claude; then
        detected+=("claude")
      fi
    fi
    for skill in "${SKILL_DIRS[@]}"; do
      if [ -L "$PROJECT_DIR/.agents/skills/$skill" ]; then
        detected+=("gemini")
        break
      fi
    done
    for skill in "${SKILL_DIRS[@]}"; do
      if [ -L "$PROJECT_DIR/.qwen/skills/$skill" ]; then
        detected+=("qwen")
        break
      fi
    done
    # Codex 项目级 AGENTS.MD
    if [ -f "$PROJECT_DIR/AGENTS.MD" ] && grep -q "openclaw-dev" "$PROJECT_DIR/AGENTS.MD" 2>/dev/null; then
      local has_codex=false
      for p in "${detected[@]}"; do [ "$p" = "codex" ] && has_codex=true; done
      if ! $has_codex; then
        detected+=("codex")
      fi
    fi
  fi

  echo "${detected[*]:-}"
}

# ── 使用帮助 ──────────────────────────────────────────

usage() {
  cat <<EOF
${BOLD}openclaw-dev 卸载脚本${NC}

${BOLD}用法:${NC}
  ./uninstall.sh [options]

${BOLD}选项:${NC}
  --project <path>        目标项目路径 (Gemini/Qwen 卸载必需)
  --platforms <list>      逗号分隔的平台列表: claude,codex,gemini,qwen
  --all                   从所有平台卸载
  --dry-run               预览操作，不实际执行
  -h, --help              显示此帮助

${BOLD}示例:${NC}
  ./uninstall.sh                                  # 自动检测并卸载
  ./uninstall.sh --project ~/myproject            # 从项目卸载
  ./uninstall.sh --platforms claude               # 只从 Claude 卸载
  ./uninstall.sh --all --project ~/myproject      # 全部卸载
EOF
}

# ── 参数解析 ──────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_DIR="$(cd "$2" 2>/dev/null && pwd || echo "$2")"
      shift 2
      ;;
    --platforms)
      PLATFORMS="$2"
      shift 2
      ;;
    --all)
      ALL_PLATFORMS=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "未知参数: $1"
      usage
      exit 1
      ;;
  esac
done

# ── 主流程 ────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}🗑️  openclaw-dev 卸载${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if $DRY_RUN; then
  warn "DRY-RUN 模式 — 只预览操作，不实际执行"
  echo ""
fi

# 确定要卸载的平台
if [ -n "$PLATFORMS" ]; then
  IFS=',' read -ra PLATFORM_LIST <<< "$PLATFORMS"
elif $ALL_PLATFORMS; then
  PLATFORM_LIST=(claude codex gemini qwen)
else
  IFS=' ' read -ra PLATFORM_LIST <<< "$(detect_installed)"
  if [ ${#PLATFORM_LIST[@]} -eq 0 ]; then
    info "未检测到已安装的 openclaw-dev"
    exit 0
  fi
  info "检测到已安装: ${PLATFORM_LIST[*]}"
fi
echo ""

# 逐个卸载
for platform in "${PLATFORM_LIST[@]}"; do
  case "$platform" in
    claude)  uninstall_claude ;;
    codex)   uninstall_codex  ;;
    gemini)  uninstall_gemini ;;
    qwen)    uninstall_qwen   ;;
    *)       err "未知平台: $platform" ;;
  esac
  echo ""
done

# ── 汇总 ───────────────────────────────────────────────

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ $REMOVED 项已移除${NC}  ${YELLOW}⏭️  $SKIPPED 项已跳过${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
