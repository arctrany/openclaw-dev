# OpenClaw QA Testing Framework

**Version**: 1.0.0 (Production Grade)
**Author**: Claude Sonnet 4.5
**Purpose**: 通用化生产级 OpenClaw Agent 测试框架

---

## 🎯 特性

- ✅ **通用化设计**: 支持任何 OpenClaw agent 测试
- ✅ **生产级质量**: 优化的超时、完整的错误处理
- ✅ **全场景覆盖**: 14+ 测试场景，无遗漏
- ✅ **自动化报告**: Markdown 格式，易于阅读
- ✅ **持续监控**: 支持 cron 定时执行
- ✅ **多模态测试**: 文本、图片、语音全覆盖

---

## 📦 测试覆盖范围

### 1️⃣ 系统基础健康检查
- Gateway 进程状态
- RPC 连通性
- Session 目录完整性
- 死锁检测
- 磁盘空间监控

### 2️⃣ 模型配置验证
- 主模型配置正确性
- Fallback 模型链
- OAuth 认证状态
- 模型可用性

### 3️⃣ Memory 完整性测试 🔥
- Session 文件格式验证
- 备份机制测试
- 跨会话记忆持久化
- Session 大小监控
- 并发访问一致性

### 4️⃣ Skills 全覆盖测试
- 65+ Skills 可用性检测
- 关键 Skills 功能测试
- Skills 调用链验证

### 5️⃣ 多模态能力测试
- **图片生成**: DALL-E + Gemini 图片模型
- **语音合成**: TTS (多语言)
- **语音识别**: Whisper
- **文本处理**: 中英文响应

### 6️⃣ 工具调用测试
- Bash 工具
- Read/Write/Edit 工具
- 文件系统操作

### 7️⃣ 性能和稳定性
- 响应时间监控
- 并发请求测试
- 错误恢复能力
- 长时间运行稳定性

---

## 🚀 使用方法

### 快速开始

```bash
# 测试指定 agent
./scripts/run-qa-tests.sh --agent annie

# 测试所有 agents
./scripts/run-qa-tests.sh --all

# 持续监控模式
./scripts/run-qa-tests.sh --agent annie --continuous

# 生成报告
./scripts/run-qa-tests.sh --agent annie --report-only
```

### 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `--agent <name>` | 指定要测试的 agent | `--agent annie` |
| `--all` | 测试所有已配置的 agents | `--all` |
| `--continuous` | 持续监控模式（每10分钟） | `--continuous` |
| `--report-only` | 只生成报告，不执行测试 | `--report-only` |
| `--quick` | 快速测试（跳过慢速测试） | `--quick` |
| `--full` | 完整测试（包括压力测试） | `--full` |

---

## 📊 测试报告

测试完成后自动生成报告：
- **位置**: `./reports/qa-report-{agent}-{timestamp}.md`
- **格式**: Markdown
- **内容**: 执行摘要、详细结果、问题清单、修复建议

---

## 🔧 配置文件

### `config/qa-config.json`

```json
{
  "timeout": {
    "fast": 10,
    "normal": 30,
    "slow": 60
  },
  "thresholds": {
    "max_session_size_mb": 5,
    "max_error_rate": 5,
    "min_success_rate": 95,
    "max_lock_age_seconds": 30
  },
  "test_scenarios": {
    "system_health": true,
    "model_config": true,
    "memory_integrity": true,
    "skills_coverage": true,
    "multimodal": true,
    "performance": true
  }
}
```

---

## 🏗️ 项目结构

```
qa/
├── README.md                  # 本文档
├── scripts/
│   ├── run-qa-tests.sh       # 主测试脚本（通用化）
│   ├── memory-tests.sh       # Memory 专项测试
│   ├── multimodal-tests.sh   # 多模态专项测试
│   └── performance-tests.sh  # 性能压力测试
├── reports/                   # 测试报告目录
├── config/
│   ├── qa-config.json        # 全局配置
│   └── agents/               # 各 agent 专属配置
│       ├── annie.json
│       └── main.json
└── lib/
    ├── test-utils.sh         # 测试工具函数库
    └── report-generator.sh   # 报告生成器
```

---

## 📝 集成到 CI/CD

### GitHub Actions

```yaml
name: QA Tests
on: [push, pull_request]
jobs:
  qa:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run QA Tests
        run: ./plugins/qa/scripts/run-qa-tests.sh --agent annie --full
```

### Cron 定时测试

```bash
# 每10分钟运行一次健康检查
*/10 * * * * /Volumes/EXT/projects/openclaw-dev/plugins/qa/scripts/run-qa-tests.sh --agent annie --quick

# 每天凌晨运行完整测试
0 0 * * * /Volumes/EXT/projects/openclaw-dev/plugins/qa/scripts/run-qa-tests.sh --all --full
```

---

## 🐛 问题排查

### 测试失败

1. 查看详细日志: `./reports/qa-report-{agent}-{timestamp}.md`
2. 检查系统健康: `openclaw gateway status`
3. 验证配置: `openclaw agent --agent {name} -m "test" --json`

### 常见问题

**Q: 测试超时**
A: 调整 `config/qa-config.json` 中的 timeout 值

**Q: Memory 测试失败**
A: 检查 Session 目录权限和备份目录是否存在

**Q: Skills 测试失败**
A: 运行 `openclaw skills list` 检查 Skills 安装状态

---

## 🤝 贡献

欢迎提交 Issue 和 PR！

---

## 📄 许可证

MIT License
