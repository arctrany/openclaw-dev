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

## Rate Limit / 配额

### LLM API 限流
- **签名**: `429` / `rate.limit` / `Too Many Requests`
- **根因**: API 调用频率超过 provider 限制
- **影响**: Agent 响应延迟或失败
- **修复**: 降低并发、升级 API plan、配置 fallback model
- **首次发现**: 2026-02-24

---

> **追加新模式时，请遵循以上格式，包含: 签名、根因、影响、修复、预防、首次发现日期。**
