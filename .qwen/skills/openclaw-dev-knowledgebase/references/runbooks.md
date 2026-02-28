# 运维手册 (Operational Runbooks)

实际操作环境的运维参考文档。

---

## 远程 Gateway 登录 (Tailscale + SSH)

### 前提

- 账号已分配（示例：`<your-username>`）
- Tailscale 客户端已安装并加入同一 Tailnet
- 本地有 SSH 客户端

### 标准登录流程

```bash
# 1. 确认 Tailscale 在线
tailscale status

# 2. 查找目标机器 IP（IP 可能变化，每次确认）
tailscale status | grep <gateway-host>  # 或向管理员确认当前 IP
GATEWAY_IP="100.x.x.x"                  # 替换为实际 IP

# 3. SSH 登录 (推荐加 IdentitiesOnly)
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 <your-username>@$GATEWAY_IP

# 4. 检查 OpenClaw 状态
openclaw status
openclaw doctor

# 5. 执行任务
openclaw update
openclaw models list

# 6. 退出
exit
```

### 文件传输

```bash
# 上传
scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  ./local_file <your-username>@$GATEWAY_IP:~/

# 下载
scp -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 \
  <your-username>@$GATEWAY_IP:~/remote_file ./
```

### 安全红线

- ✅ 只通过 Tailscale 地址访问
- ❌ 禁止公网 IP 开放 SSH
- ❌ 不修改 VPN / DNS / 路由 / 防火墙
- ❌ 不修改 `/etc/ssh/sshd_config`
- ❌ 不共享账号、密码、私钥
- 操作完成后及时 `exit`

### 常见问题

| 问题 | 排查 |
|------|------|
| 连接超时 | 确认本地 Tailscale 在线 + 同一 Tailnet + SSH 服务运行 |
| 权限不足 | 把完整报错发管理员申请授权 |
| `openclaw` 找不到 | 先 `openclaw doctor`；仍失败联系管理员检查安装与 PATH |

### 每次登录顺序

1. 连上 Tailscale
2. `ssh` 登录
3. `openclaw doctor`
4. 执行任务
5. `exit` 退出

> 💡 建议配置 SSH 密钥登录 + `IdentitiesOnly=yes`，减少密码输入和安全风险

---

## Gateway 远程运维

### 重启 Gateway

```bash
# 本地
pkill -TERM openclaw-gateway
# launchd 会自动重启；如未重启：
openclaw gateway run &

# 远程 (SSH 进去后)
pkill -9 -f openclaw-gateway || true
nohup openclaw gateway run --bind loopback --port 18789 --force > /tmp/openclaw-gateway.log 2>&1 &
```

### 健康检查

```bash
openclaw doctor
openclaw channels status --probe
openclaw status --deep
ss -ltnp | rg 18789        # Linux
lsof -i :18789              # macOS
tail -n 120 /tmp/openclaw-gateway.log
```

### 更新 OpenClaw

```bash
# 远程
sudo npm i -g openclaw@latest
openclaw --version

# 重启 Gateway 使更新生效
pkill -TERM openclaw-gateway
```

### 批量部署 Skills 到远程

```bash
# rsync 整个 skills 目录 (排除 memory)
rsync -avz --exclude 'memory/' --exclude 'MEMORY.md' \
  -e "ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519" \
  skills/ <your-username>@$GATEWAY_IP:~/.openclaw/workspace/skills/

# 然后 SSH 进去发 /new 给 agent，或重启 gateway
```

---

## macOS 应用运维

### 查看 Gateway 日志

```bash
./scripts/clawlog.sh
# 或
log show --predicate 'subsystem == "ai.openclaw"' --last 1h
```

### 重启 macOS 应用

```bash
./scripts/restart-mac.sh
# 或手动
killall "OpenClaw" && open -a "OpenClaw"
```

### 权限检查

macOS 需要以下权限：
- 辅助功能 (Accessibility) — 用于 browser control
- 屏幕录制 — 用于 peekaboo / screenshot
- 麦克风 — 用于 Voice Wake / Talk Mode
- 完全磁盘访问 — 用于 Apple Notes / iMessage 技能
