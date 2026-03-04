---
name: diagnose
description: "Systematic OpenClaw runtime diagnosis — analyze logs, identify fault patterns, output report, and accumulate new findings. Supports remote Gateways."
argument-hint: "[gateway-name|ALL]"
user-invocable: true
---

# /diagnose — OpenClaw 系统性诊断

## Gateway 选择

读取 `.claude/openclaw-dev.local.md` 中的 `gateways:` 配置。

1. **有参数** (`/diagnose home-mac`) → 直接指定目标 gateway
2. **参数为 ALL** (`/diagnose ALL`) → 并行诊断所有可达 gateway
3. **无 gateways 配置或只有 1 个** → 直接诊断本地（现有行为）
4. **多个 gateway，无参数** → Preflight 探测可达性，展示选择菜单

### Preflight 探测

对每个非本地 gateway 并行执行:
```bash
ssh -o ConnectTimeout=5 -o BatchMode=yes \
    ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22} \
    ${ssh_user}@${host} "echo ok" 2>/dev/null
```

### 选择菜单

使用 AskUserQuestion:
```
1. local       127.0.0.1:18789        ● 可达
2. home-mac    192.168.1.100:18789    ● 可达
3. cloud-hk    10.0.0.5:18789         ○ 不可达
4. ALL（并行诊断所有可达 gateway，汇总报告）
```

## 单 Gateway 诊断（展开视图）

读取 `openclaw-node-operations` skill 的 `references/diagnose-runbook.md`，按步骤执行完整诊断流程。

对远程 gateway，将 runbook 中的 `$HOST` 参数设为 `ssh_user@host`，使用 SSH 连接参数:
```bash
SSH_OPTS="-o IdentitiesOnly=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=2"
SSH_OPTS="$SSH_OPTS -o ControlMaster=auto -o ControlPath=/tmp/openclaw-ssh-%r@%h:%p -o ControlPersist=300"
SSH_OPTS="$SSH_OPTS ${ssh_key:+-i $ssh_key} -p ${ssh_port:-22}"
HOST="${ssh_user}@${host}"
CMD="ssh $SSH_OPTS $HOST"
```

对本地 gateway，`CMD=""` (直接执行，和现有行为一致)。

完整步骤和报告模板见 `references/diagnose-runbook.md`。

## ALL 模式（折叠汇总）

对所有可达 gateway 并行执行诊断。不使用 tmux——后台并行 + 收集结果:

```bash
for gw_name in "${GATEWAYS[@]}"; do
  (
    # 根据 gateway 配置构造 CMD
    # 执行 openclaw doctor + health + 基础日志分析
    ssh $SSH_OPTS ${ssh_user}@${host} \
      "openclaw doctor 2>&1; openclaw health 2>&1; openclaw status --deep 2>&1"
  ) > "/tmp/openclaw-diag-$gw_name" 2>&1 &
done
wait
```

汇总报告格式:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Fleet 诊断报告  <日期时间>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Gateway      Result  Score   Agents  Issues
───────────  ──────  ──────  ──────  ──────
local        [OK]    95/100  3       0
home-mac     [OK]    88/100  1       2 warnings
cloud-hk     [FAIL]  -       -       SSH timeout (10s)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
总计: 2/3 可达  |  平均健康分: 91.5
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
