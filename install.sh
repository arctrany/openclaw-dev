#!/bin/bash
# install.sh — 一键安装 openclaw-dev 技能包到 Agent 平台
# 支持: Claude Code, Gemini Antigravity, Codex CLI, Qwen Code
#
# Usage:
#   ./install.sh                              # 自动检测全局平台
#   ./install.sh --project ~/myproject        # 安装到项目 (Claude/Codex/Gemini/Qwen)
#   ./install.sh --platforms claude,codex     # 只安装到指定平台
#   ./install.sh --project ~/myproject --all  # 安装全部平台
#   ./install.sh --dry-run                    # 预览不执行

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
SKILLS_DIR="$SCRIPT_DIR/skills"
COMMANDS_DIR="$SCRIPT_DIR/commands"
AGENTS_DIR="$SCRIPT_DIR/agents"
PROJECT_DIR=""
PLATFORMS=""
DRY_RUN=false
ALL_PLATFORMS=false
INSTALLED=0
SKIPPED=0
FAILED=0

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

make_symlink() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [ -L "$dst" ]; then
    local existing
    existing="$(readlink "$dst")"
    if [ "$existing" = "$src" ]; then
      warn "$label: 已安装 (symlink 已存在)"
      SKIPPED=$((SKIPPED + 1))
      return 0
    else
      warn "$label: symlink 已存在但指向 $existing, 将替换"
      if $DRY_RUN; then
        dry_run "rm $dst && ln -s $src $dst"
        return 0
      fi
      rm "$dst"
    fi
  elif [ -e "$dst" ]; then
    err "$label: 目标路径已存在且不是 symlink: $dst"
    FAILED=$((FAILED + 1))
    return 1
  fi

  if $DRY_RUN; then
    dry_run "ln -s $src $dst"
    INSTALLED=$((INSTALLED + 1))
    return 0
  fi

  ln -s "$src" "$dst"
  ok "$label: 已安装"
  INSTALLED=$((INSTALLED + 1))
}

# ── 平台安装函数 ──────────────────────────────────────

install_claude() {
  step "安装到 Claude Code"
  local target_dir="$HOME/.claude/plugins"
  mkdir -p "$target_dir"
  make_symlink "$SCRIPT_DIR" "$target_dir/openclaw-dev" "Claude Code global"

  # Claude Code 项目级: CLAUDE.md
  if [ -n "$PROJECT_DIR" ]; then
    local claude_md="$PROJECT_DIR/CLAUDE.md"
    local marker="<!-- openclaw-dev -->"

    if [ -f "$claude_md" ] && grep -q "$marker" "$claude_md"; then
      warn "Claude CLAUDE.md: 已包含 openclaw-dev 引用"
      SKIPPED=$((SKIPPED + 1))
    else
      local claude_content
      claude_content=$(cat <<'CLAUDEMD'

<!-- openclaw-dev -->
## OpenClaw Development Skills

This project uses OpenClaw. The following skill files are installed as a Claude Code plugin at `~/.claude/plugins/openclaw-dev/skills/`:

- **openclaw-dev-knowledgebase**: Complete OpenClaw knowledge base — architecture, config, Plugin API, Agent config, install/debug.
- **openclaw-skill-development**: Skill lifecycle SOP — create, validate, deploy, evolve.
- **openclaw-node-operations**: Node operations — install, Gateway management, networking, debugging.

When working on OpenClaw-related tasks, consult these skills for accurate guidance.
<!-- /openclaw-dev -->
CLAUDEMD
)
      if $DRY_RUN; then
        dry_run "追加 openclaw-dev 引用到 $claude_md"
      else
        echo "$claude_content" >> "$claude_md"
        ok "Claude CLAUDE.md: 已添加项目级 openclaw-dev 引用"
      fi
      INSTALLED=$((INSTALLED + 1))
    fi
  fi
}

install_codex() {
  step "安装到 Codex CLI"
  # Codex 全局: ~/.codex/instructions.md + skills 链接
  local codex_dir="$HOME/.codex"
  mkdir -p "$codex_dir"

  # 安装 skills 为链接
  local skills_target="$codex_dir/openclaw-dev-skills"
  make_symlink "$SKILLS_DIR" "$skills_target" "Codex global skills"

  # 创建/追加全局 instructions 引用
  local instructions_file="$codex_dir/instructions.md"
  local marker="<!-- openclaw-dev -->"

  if [ -f "$instructions_file" ] && grep -q "$marker" "$instructions_file"; then
    warn "Codex instructions.md: 已包含 openclaw-dev 引用"
    SKIPPED=$((SKIPPED + 1))
  else
    local instructions_content
    instructions_content=$(cat <<'INSTRUCTIONS'

<!-- openclaw-dev -->
## OpenClaw Development Skills

The following OpenClaw development skills are available at `~/.codex/openclaw-dev-skills/`:

- **openclaw-dev-knowledgebase**: Complete OpenClaw knowledge base — architecture, config, Plugin API, Agent config, install/debug. Read `~/.codex/openclaw-dev-skills/openclaw-dev-knowledgebase/SKILL.md` when asked about OpenClaw internals.
- **openclaw-skill-development**: Skill lifecycle SOP — create, validate, deploy, evolve. Read `~/.codex/openclaw-dev-skills/openclaw-skill-development/SKILL.md` when asked to create/manage skills.
- **openclaw-node-operations**: Node operations — install, Gateway management, networking, debugging. Read `~/.codex/openclaw-dev-skills/openclaw-node-operations/SKILL.md` when asked about node setup/troubleshooting.
<!-- /openclaw-dev -->
INSTRUCTIONS
)
    if $DRY_RUN; then
      dry_run "追加 openclaw-dev 引用到 $instructions_file"
    else
      echo "$instructions_content" >> "$instructions_file"
      ok "Codex instructions.md: 已添加 openclaw-dev 引用"
    fi
    INSTALLED=$((INSTALLED + 1))
  fi

  # Codex 项目级: AGENTS.MD
  if [ -n "$PROJECT_DIR" ]; then
    local agents_md="$PROJECT_DIR/AGENTS.MD"
    local project_marker="<!-- openclaw-dev -->"

    if [ -f "$agents_md" ] && grep -q "$project_marker" "$agents_md"; then
      warn "Codex AGENTS.MD: 已包含 openclaw-dev 引用"
      SKIPPED=$((SKIPPED + 1))
    else
      local agents_content
      agents_content=$(cat <<'AGENTSMD'

<!-- openclaw-dev -->
## OpenClaw Development Skills

This project uses OpenClaw. The following skill files provide comprehensive development guidance:

- **Knowledgebase**: Read `~/.codex/openclaw-dev-skills/openclaw-dev-knowledgebase/SKILL.md` for OpenClaw architecture, Plugin API, Agent config, and debugging.
- **Skill Development**: Read `~/.codex/openclaw-dev-skills/openclaw-skill-development/SKILL.md` for creating, validating, deploying skills.
- **Node Operations**: Read `~/.codex/openclaw-dev-skills/openclaw-node-operations/SKILL.md` for node setup, Gateway management, networking.

When working on OpenClaw-related tasks, consult these skills for accurate guidance.
<!-- /openclaw-dev -->
AGENTSMD
)
      if $DRY_RUN; then
        dry_run "追加 openclaw-dev 引用到 $agents_md"
      else
        echo "$agents_content" >> "$agents_md"
        ok "Codex AGENTS.MD: 已添加项目级 openclaw-dev 引用"
      fi
      INSTALLED=$((INSTALLED + 1))
    fi
  fi
}

install_gemini() {
  if [ -z "$PROJECT_DIR" ]; then
    err "Gemini 需要 --project <path> 参数 (项目级安装)"
    FAILED=$((FAILED + 1))
    return 1
  fi
  step "安装到 Gemini Antigravity → $PROJECT_DIR"
  local target_dir="$PROJECT_DIR/.agents/skills"
  mkdir -p "$target_dir"

  for skill in "${SKILL_DIRS[@]}"; do
    make_symlink "$SKILLS_DIR/$skill" "$target_dir/$skill" "Gemini/$skill"
  done
}

install_qwen() {
  if [ -z "$PROJECT_DIR" ]; then
    err "Qwen 需要 --project <path> 参数 (项目级安装)"
    FAILED=$((FAILED + 1))
    return 1
  fi
  step "安装到 Qwen Code → $PROJECT_DIR"
  local target_dir="$PROJECT_DIR/.qwen/skills"
  mkdir -p "$target_dir"

  for skill in "${SKILL_DIRS[@]}"; do
    make_symlink "$SKILLS_DIR/$skill" "$target_dir/$skill" "Qwen/$skill"
  done
}

# ── 平台检测 ──────────────────────────────────────────

detect_platforms() {
  local detected=()

  # Claude Code: 检查 ~/.claude 目录是否存在
  if [ -d "$HOME/.claude" ]; then
    detected+=("claude")
  fi

  # Codex CLI: 检查 codex 命令或 ~/.codex 目录
  if command -v codex &>/dev/null || [ -d "$HOME/.codex" ]; then
    detected+=("codex")
  fi

  # 项目级平台: 如果提供了 --project 则纳入所有平台
  if [ -n "$PROJECT_DIR" ]; then
    # 确保 claude 不重复
    local has_claude=false
    for p in "${detected[@]}"; do [ "$p" = "claude" ] && has_claude=true; done
    if ! $has_claude; then
      detected+=("claude")
    fi
    # 确保 codex 不重复
    local has_codex=false
    for p in "${detected[@]}"; do [ "$p" = "codex" ] && has_codex=true; done
    if ! $has_codex; then
      detected+=("codex")
    fi
    detected+=("gemini" "qwen")
  fi

  echo "${detected[*]:-}"
}

# ── 使用帮助 ──────────────────────────────────────────

usage() {
  cat <<EOF
${BOLD}openclaw-dev 多平台安装脚本${NC}

${BOLD}用法:${NC}
  ./install.sh [options]

${BOLD}选项:${NC}
  --project <path>        目标项目路径 (Gemini/Qwen 项目级安装必需)
  --platforms <list>      逗号分隔的平台列表: claude,codex,gemini,qwen
  --all                   安装到所有可用平台
  --dry-run               预览操作，不实际执行
  -h, --help              显示此帮助

${BOLD}示例:${NC}
  ./install.sh                                  # 自动检测全局平台
  ./install.sh --project ~/myproject            # 安装到项目 (Claude+Codex+Gemini+Qwen)
  ./install.sh --platforms claude,codex         # 只安装到 Claude + Codex
  ./install.sh --project ~/myproject --all      # 全部平台
  ./install.sh --dry-run --project ~/myproject  # 预览

${BOLD}平台:${NC}
  claude   Claude Code       全局 (~/.claude/plugins/) + 项目级 (CLAUDE.md)
  codex    Codex CLI          全局 (~/.codex/) + 项目级 (AGENTS.MD)
  gemini   Gemini Antigravity 项目级 (<project>/.agents/skills/)
  qwen     Qwen Code          项目级 (<project>/.qwen/skills/)
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
echo -e "${BOLD}📦 openclaw-dev 多平台安装${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if $DRY_RUN; then
  warn "DRY-RUN 模式 — 只预览操作，不实际执行"
  echo ""
fi

info "技能包路径: $SCRIPT_DIR"
[ -n "$PROJECT_DIR" ] && info "目标项目: $PROJECT_DIR"
echo ""

# 确定要安装的平台
if [ -n "$PLATFORMS" ]; then
  # 用户指定
  IFS=',' read -ra PLATFORM_LIST <<< "$PLATFORMS"
elif $ALL_PLATFORMS; then
  PLATFORM_LIST=(claude codex gemini qwen)
else
  # 自动检测
  IFS=' ' read -ra PLATFORM_LIST <<< "$(detect_platforms)"
  if [ ${#PLATFORM_LIST[@]} -eq 0 ]; then
    warn "未检测到已安装的 Agent 平台"
    echo ""
    info "请使用以下方式之一:"
    info "  ./install.sh --platforms claude,codex,gemini,qwen --project ~/myproject"
    info "  ./install.sh --all --project ~/myproject"
    exit 0
  fi
  info "检测到平台: ${PLATFORM_LIST[*]}"
fi
echo ""

# 逐个安装
for platform in "${PLATFORM_LIST[@]}"; do
  case "$platform" in
    claude)  install_claude ;;
    codex)   install_codex  ;;
    gemini)  install_gemini ;;
    qwen)    install_qwen   ;;
    *)       err "未知平台: $platform" ;;
  esac
  echo ""
done

# ── 汇总 ───────────────────────────────────────────────

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ $INSTALLED 项已安装${NC}  ${YELLOW}⏭️  $SKIPPED 项已跳过${NC}  ${RED}❌ $FAILED 项失败${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
  exit 1
fi
