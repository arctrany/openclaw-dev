#!/bin/bash
#
# OpenClaw Remote Deployment Script — Postiz Plugin
#
# 所有敏感信息均通过环境变量传入，不写死任何 IP 或 Token。
# 用法:
#   source .env.deploy && bash deploy-remote.sh
#
# 或直接指定变量:
#   REMOTE_HOST=100.92.217.43 REMOTE_USER=haowu bash deploy-remote.sh

set -euo pipefail

# ────────────────────────────────────────────────────────
# 配置来源: 读取环境变量，或使用合理的默认值
# ────────────────────────────────────────────────────────
REMOTE_USER="${REMOTE_USER:-haowu}"
REMOTE_HOST="${REMOTE_HOST:?必须设置 REMOTE_HOST 环境变量 (如: export REMOTE_HOST=100.92.217.43)}"
LOCAL_PLUGIN_DIR="$(cd "$(dirname "$0")/../plugin" && pwd)"
REMOTE_PLUGIN_DIR="~/.openclaw/extensions/postiz"

SSH_OPTS="-o ConnectTimeout=10 -o StrictHostKeyChecking=no"

echo "=== Deploying Postiz Plugin to Remote OpenClaw ==="
echo "  Remote: ${REMOTE_USER}@${REMOTE_HOST}"
echo "  Plugin: ${LOCAL_PLUGIN_DIR}"

# 1. Transfer Plugin 代码到远端
echo ""
echo ">> Copying plugin files..."
# shellcheck disable=SC2086
ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_PLUGIN_DIR}"
# shellcheck disable=SC2086
scp $SSH_OPTS -r "${LOCAL_PLUGIN_DIR}/"* "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PLUGIN_DIR}/"

# 2. 通过官方 CLI 安装并加入 plugins.allow 白名单
echo ""
echo ">> Linking plugin and allowlisting via openclaw CLI..."
# shellcheck disable=SC2086,SC2029
ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "
  cd ${REMOTE_PLUGIN_DIR}
  openclaw plugins install -l .
  # 将 postiz 加入 plugins.allow 白名单，消除启动告警
  openclaw config set plugins.allow '[\"postiz\"]' 2>/dev/null || \
    node -e \"
      const fs=require('fs'),os=require('os'),path=require('path');
      const f=path.join(os.homedir(),'.openclaw','openclaw.json');
      const c=JSON.parse(fs.readFileSync(f,'utf8'));
      if(!c.plugins) c.plugins={};
      const cur=c.plugins.allow||[];
      if(!cur.includes('postiz')) cur.push('postiz');
      c.plugins.allow=cur;
      fs.writeFileSync(f,JSON.stringify(c,null,2));
      console.log('[postiz] Added to plugins.allow whitelist');
    \"
"

# 3. 部署 SKILL.md 到各 Agent workspace
echo ""
echo ">> Distributing SKILL.md..."
# shellcheck disable=SC2086,SC2029
ssh $SSH_OPTS "${REMOTE_USER}@${REMOTE_HOST}" "
  mkdir -p ~/.openclaw/workspace-researcher/skills/postiz
  mkdir -p ~/.openclaw/workspace-adm/skills/postiz
  cp ${REMOTE_PLUGIN_DIR}/skills/postiz/SKILL.md ~/.openclaw/workspace-researcher/skills/postiz/
  cp ${REMOTE_PLUGIN_DIR}/skills/postiz/SKILL.md ~/.openclaw/workspace-adm/skills/postiz/
"

echo ""
echo "✅ Deployment successful!"
echo ""
echo "─────────────────────────────────────────────────────"
echo "POST-DEPLOYMENT: 请确保远端 ~/.openclaw/openclaw.env 包含："
echo "  POSTIZ_API_URL=<你的 Postiz 内网地址>/api"
echo "  POSTIZ_API_KEY=<从 Postiz Settings → Public API 获取>"
echo "─────────────────────────────────────────────────────"
echo "然后重启 Gateway: openclaw restart"
