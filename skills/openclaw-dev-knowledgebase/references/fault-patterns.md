# OpenClaw 故障模式库 (活文档)

> **本文件是活文档。** Agent 每次诊断发现新模式后，应追加到对应分类下。
> 格式: 签名 → 根因 → 修复 → 预防。

---

## 网络层故障

### fetch failed 暴增
- **签名**: `TypeError: fetch failed` 单日 > 100 次
- **关联签名**: `ERR_ASSERTION: Reached illegal state! IPV4 address change`
- **根因**: 网络接口不稳定 —— WiFi 断连、VPN/Clash 客户端重启、外接硬盘断开导致 node 不可用
- **影响**: 所有出站 HTTP 请求失败，Agent 完全无法调用 LLM API
- **修复**: 
  1. `ifconfig | grep "inet "` 检查网络接口
  2. 检查 VPN/代理状态
  3. 如果 node 在外接硬盘: `which node` → 确认路径可用
- **预防**: node 安装到本机系统盘，不放外接硬盘
- **首次发现**: 2026-01-30 (5,330 次/天)

### DNS 被代理劫持
- **签名**: `resolves to private/internal/special-use IP address`
- **根因**: VPN/Clash 代理将公共域名 DNS 解析到本地代理 IP，OpenClaw 安全策略拒绝连接私有 IP
- **影响**: `web_fetch` 工具对所有公共 URL 失败
- **修复**:
  1. `dig google.com` → 如果返回 127.x 或 10.x → 代理劫持
  2. 临时关闭代理的 DNS 劫持功能
  3. 或将 OpenClaw 的 URL 安全策略设为允许代理 IP
- **预防**: 配置代理 bypass 列表包含 OpenClaw 常用域名
- **首次发现**: 2026-02-26 (38 次)

---

## 配置层故障

### JSON 语法错误
- **签名**: `invalid character` + 行号 + `config reload skipped`
- **根因**: 手动编辑 `openclaw.json` 引入语法错误 (多余逗号、非法引号、缺少括号)
- **影响**: 配置热加载跳过 → Agent 读不到 API key → 所有任务终止
- **修复**:
  1. `jq . ~/.openclaw/openclaw.json` → 看错误行号
  2. 修复语法错误
  3. 或从最近的 `.bak` 恢复: `ls -lt ~/.openclaw/openclaw.json.bak* | head -1`
- **预防**: 每次编辑前 `cp openclaw.json openclaw.json.bak-$(date +%Y%m%d-%H%M%S)`，编辑后 `jq . openclaw.json > /dev/null`
- **首次发现**: 2026-02-04 (706 次, line 193 逗号错误)
- **复发**: 2026-02-12 (5,347 次, line 763 引号错误)

### API Key 丢失
- **签名**: `No API key found for provider` + `Configure auth for this agent`
- **根因**: 通常是配置损坏的级联效应，也可能是 auth-profiles.json 被误删
- **影响**: 特定 Agent 无法调用 LLM
- **修复**:
  1. 先检查配置是否损坏: `jq . ~/.openclaw/openclaw.json`
  2. 检查 auth profile: `cat ~/.openclaw/agents/<id>/agent/auth-profiles.json`
  3. 重新配置: `openclaw agents add <id>`
- **首次发现**: 2026-02-04

---

## 进程层故障

### Gateway crash loop
- **签名**: 10 分钟内 3+ 次 `Gateway listening` / PID 变化
- **关联签名**: PID 间隔 < 60 秒, PID 溢出回绕 (如从 88570 跳到 3018)
- **根因**: 启动即崩溃，LaunchAgent KeepAlive 不断重启
  - 常见触发: node 二进制不可用 (外接硬盘)、端口被占用、配置严重损坏
- **影响**: 系统资源消耗、日志暴增、进程表爆炸
- **修复**:
  1. `launchctl unload ~/Library/LaunchAgents/openclaw-gateway*.plist` 先停止
  2. 检查 node 路径: `which node` → 不应在 `/Volumes/`
  3. 检查端口: `lsof -i :18789`
  4. 手动启动看错误: `openclaw gateway --port 18789`
- **预防**:
  - node 安装在系统盘
  - LaunchAgent 增加 `ThrottleInterval` ≥ 120
  - 配置 `bind: "loopback"` (不用 `0.0.0.0`)
- **首次发现**: 2026-02-02 (20+ 次重启, 10 秒级间隔)

---

## 工具层故障

### Browser 未 attach
- **签名**: `no tab is connected` / `attachOnly not running`
- **根因**: Agent 尝试使用浏览器工具，但用户没有在 Chrome 中激活 OpenClaw 扩展
- **影响**: browser 工具调用失败
- **修复**: 提示用户打开 Chrome → 点击 OpenClaw 扩展 → attach 标签页
- **预防**: Agent 在使用 browser 前先检查连接状态
- **首次发现**: 2026-02 (25 次)

### Workspace 沙箱写入被阻止
- **签名**: `sandbox` + 写入路径 + `denied`
- **根因**: workspace sandbox.mode 只允许根目录写入，不允许创建子目录
- **影响**: Agent 无法在 workspace 内创建新目录/文件
- **修复**: 检查 `openclaw.json` 中 agent 的 `sandbox.mode`，改为 `lenient` 或调整 `sandbox.allowPaths`
- **首次发现**: 2026-02-28

### Env override 被安全策略阻止
- **签名**: `[env-overrides] Blocked skill env overrides`
- **根因**: Skill 试图通过环境变量覆盖注入 API key (如 FISH_AUDIO_API_KEY)，被安全策略阻止
- **影响**: 依赖环境变量的 skill 无法正常工作
- **修复**: 在 `openclaw.json` 中配置 `skills.envOverrides.allow` 列表
- **首次发现**: 2026-02-27

---

## Onboarding 阶段故障

### Node.js 版本不兼容
- **签名**: `Unsupported Node.js version` / `engine "node" is incompatible`
- **根因**: 系统自带或 brew 安装的 Node.js 版本过老 (< 22)
- **影响**: 安装失败或 Gateway 无法启动
- **修复**: `node -v` 检查版本; 安装 Node 22+: `brew install node@22` 或 `nvm install 22`
- **预防**: `install.sh` 会自动安装 Node 22，手动安装时注意版本
- **首次发现**: 2026-02-28

### Port 18789 被占用
- **签名**: `EADDRINUSE: address already in use :::18789`
- **根因**: 旧 Gateway 进程未退出、其他应用占用、或多 profile 端口冲突
- **影响**: Gateway 无法启动，onboard 最后一步失败
- **修复**:
  1. `lsof -i :18789` 找到占用进程
  2. `kill <PID>` 或 `openclaw gateway stop`
  3. 或换端口: `openclaw gateway --port 19000`
- **预防**: onboard 前先 `lsof -i :18789` 确认端口空闲
- **首次发现**: 2026-02-28

### API Key 无效/过期
- **签名**: `401 Unauthorized` / `Invalid API key` / `No API key found for provider`
- **根因**: 粘贴 key 时多了空格/换行、key 被 revoke、或选错 provider
- **影响**: Gateway 运行但 Agent 无法回复消息
- **修复**:
  1. `openclaw models status` 检查 auth 状态
  2. 重新配置: `openclaw configure` → 重新输入 API key
  3. 在 provider 后台 (console.anthropic.com) 确认 key 有效
- **预防**: 粘贴后 `openclaw health` 立即验证
- **首次发现**: 2026-02-28

### Onboard 中途断开
- **签名**: 部分配置写入但 Gateway 未安装
- **根因**: 终端意外关闭、SSH 断连、Ctrl+C 中断
- **影响**: 配置文件不完整，Gateway 不启动
- **修复**: 重新运行 `openclaw onboard --install-daemon` (幂等，会跳过已完成步骤)
- **预防**: 使用 `tmux` 或 `screen` 在远程机器上运行 onboard
- **首次发现**: 2026-02-28

---

## SSH / 远程连接层故障

### Host key verification failed
- **签名**: `Host key verification failed` / `REMOTE HOST IDENTIFICATION HAS CHANGED`
- **根因**: 目标机器重装系统、IP 复用、或 Tailscale IP 变更后 `~/.ssh/known_hosts` 中的指纹不匹配
- **影响**: SSH 连接被客户端拒绝，所有远程操作 (deploy-skill, diagnose 等) 全部失败
- **修复**:
  1. `ssh-keygen -R <host-ip>` 精准删除旧指纹 (不要删整个 known_hosts)
  2. 重新连接并确认新指纹: `ssh -o StrictHostKeyChecking=ask user@host`
- **预防**: 重装系统后主动通知所有客户端更新指纹; 记录各节点公钥指纹到运维文档
- **首次发现**: 2026-02-28

### Too many authentication failures
- **签名**: `Too many authentication failures` / `Received disconnect from ... Too many authentication failures`
- **根因**: SSH agent 中加载了过多密钥 (3-5 个以上)，客户端逐个尝试直到服务器断开连接 (默认 `MaxAuthTries=6`)
- **影响**: 即使正确密钥存在也无法登录，常与 Host key 报错混杂导致排查方向被干扰
- **修复**:
  1. 客户端连接时强制指定单密钥: `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 user@host`
  2. 或在 `~/.ssh/config` 中配置:
     ```
     Host gateway-*
       IdentitiesOnly yes
       IdentityFile ~/.ssh/id_ed25519
     ```
  3. 清理 SSH agent 多余密钥: `ssh-add -D && ssh-add ~/.ssh/id_ed25519`
- **预防**: 所有 OpenClaw 脚本和文档中的 ssh 调用统一加 `IdentitiesOnly=yes`
- **首次发现**: 2026-02-28

### authorized_keys 权限错误
- **签名**: `Permission denied (publickey)` + 服务端 `/var/log/auth.log` 显示 `Authentication refused: bad ownership or modes`
- **根因**: `~/.ssh/authorized_keys` 文件权限不是 600，或 `~/.ssh` 目录权限不是 700，或所有者不正确
- **关联症状**: 网络层和握手层全部正常，只有认证失败 — 这是最常见的 SSH 根因
- **影响**: 公钥认证被 sshd 静默拒绝，客户端只看到 `Permission denied`
- **修复**:
  1. 修复权限:
     ```bash
     chmod 700 ~/.ssh
     chmod 600 ~/.ssh/authorized_keys
     chown -R $(whoami):staff ~/.ssh   # macOS
     ```
  2. 确认 authorized_keys 内容是完整单行公钥 (无换行、无多余空格)
  3. 本机回环验证: `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 $(whoami)@127.0.0.1`
- **预防**: 用 `ssh-copy-id` 而非手动复制; 写入后立即验证权限
- **首次发现**: 2026-02-28

---

## Rate Limit / 配额

### LLM API 限流
- **签名**: `429` / `rate.limit` / `Too Many Requests`
- **根因**: API 调用频率超过 provider 限制
- **影响**: Agent 响应延迟或失败
- **修复**: 降低并发、升级 API plan、配置 fallback model
- **首次发现**: 2026-02-24

---

> **追加新模式时，请遵循以上格式，包含: 签名、根因、影响、修复、预防、首次发现日期。**
