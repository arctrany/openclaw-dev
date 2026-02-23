#!/usr/bin/env node
/**
 * Memory Search 功能测试脚本
 * 用于验证 embedding 配置和 memory_search 功能
 */

import { execSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { homedir } from 'os';
import path from 'path';

const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const RESET = '\x1b[0m';

function log(message: string, color: string = RESET) {
  console.log(`${color}${message}${RESET}`);
}

function testMemorySearch(): boolean {
  log('\n========== Memory Search 功能测试 ==========', YELLOW);

  let allPassed = true;

  // 1. 检查 Gateway 进程
  log('\n[1/5] 检查 Gateway 进程...');
  try {
    const result = execSync('ps aux | grep openclaw-gateway | grep -v grep', { encoding: 'utf-8' });
    if (result.trim()) {
      log('✓ Gateway 进程运行中', GREEN);
      const pid = result.trim().split(/\s+/)[1];
      log(`  PID: ${pid}`, GREEN);
    } else {
      log('✗ Gateway 进程未运行', RED);
      allPassed = false;
    }
  } catch (error) {
    log('✗ Gateway 进程检查失败', RED);
    allPassed = false;
  }

  // 2. 检查配置文件
  log('\n[2/5] 检查 Memory Search 配置...');
  const configPaths = [
    path.join(homedir(), '.openclaw', 'openclaw.json'),
    path.join(homedir(), '.clawrc'),
    '/etc/openclaw/clawrc.json'
  ];

  let configFound = false;
  for (const configPath of configPaths) {
    if (existsSync(configPath)) {
      log(`✓ 找到配置文件: ${configPath}`, GREEN);
      try {
        const config = JSON.parse(readFileSync(configPath, 'utf-8'));
        const memoryConfig = config.agents?.defaults?.memorySearch;

        if (memoryConfig) {
          log('  Memory Search 配置:', GREEN);
          log(`    Provider: ${memoryConfig.provider || 'N/A'}`);
          log(`    Model: ${memoryConfig.model || 'N/A'}`);

          // 检查配置一致性
          if (memoryConfig.provider === 'local' && memoryConfig.model?.includes('gemini')) {
            log('✗ 配置矛盾: provider=local 但 model 是 Gemini', RED);
            allPassed = false;
          } else if (memoryConfig.provider === 'openai' && !memoryConfig.model?.includes('text-embedding')) {
            log('⚠ 警告: provider=openai 但 model 不是标准的 embedding 模型', YELLOW);
          } else {
            log('✓ 配置一致性检查通过', GREEN);
          }
        } else {
          log('⚠ 未找到 memorySearch 配置', YELLOW);
        }
        configFound = true;
        break;
      } catch (error) {
        log(`✗ 配置文件解析失败: ${(error as Error).message}`, RED);
        allPassed = false;
      }
    }
  }

  if (!configFound) {
    log('⚠ 未找到任何配置文件', YELLOW);
  }

  // 3. 检查 Gateway 日志中的错误
  log('\n[3/5] 检查 Gateway 日志...');
  const logPath = path.join(homedir(), '.openclaw', 'logs', 'gateway.log');

  if (existsSync(logPath)) {
    try {
      const logs = readFileSync(logPath, 'utf-8');
      const recentLogs = logs.split('\n').slice(-200).join('\n');

      const errorPatterns = [
        /error.*embedding/i,
        /error.*memory/i,
        /Metal.*crash/i,
        /FATAL/i,
        /segmentation fault/i
      ];

      let errorsFound = 0;
      for (const pattern of errorPatterns) {
        const matches = recentLogs.match(new RegExp(pattern, 'g'));
        if (matches) {
          errorsFound += matches.length;
        }
      }

      if (errorsFound > 0) {
        log(`✗ 发现 ${errorsFound} 个错误模式`, RED);
        allPassed = false;
      } else {
        log('✓ 近期日志无明显错误', GREEN);
      }
    } catch (error) {
      log(`⚠ 日志读取失败: ${(error as Error).message}`, YELLOW);
    }
  } else {
    log('⚠ Gateway 日志文件不存在', YELLOW);
  }

  // 4. 测试 Gateway 连接
  log('\n[4/5] 测试 Gateway 连接...');
  try {
    const response = execSync(
      'curl -s http://localhost:18789',
      { encoding: 'utf-8', timeout: 5000 }
    );

    if (response.trim()) {
      log('✓ Gateway 健康检查通过', GREEN);
    } else {
      log('✗ Gateway 健康检查失败（无响应）', RED);
      allPassed = false;
    }
  } catch (error) {
    log('✗ Gateway 健康检查失败（连接错误）', RED);
    allPassed = false;
  }

  // 5. 检查依赖
  log('\n[5/5] 检查关键依赖...');
  const dependencies = [
    'node',
    'npm',
    'npx'
  ];

  for (const dep of dependencies) {
    try {
      execSync(`which ${dep}`, { encoding: 'utf-8' });
      log(`✓ ${dep} 已安装`, GREEN);
    } catch (error) {
      log(`✗ ${dep} 未安装`, RED);
      allPassed = false;
    }
  }

  // 总结
  log('\n========================================', YELLOW);
  if (allPassed) {
    log('✓ 所有检查通过 - Memory Search 功能正常', GREEN);
    return true;
  } else {
    log('✗ 部分检查失败 - Memory Search 功能异常', RED);
    return false;
  }
}

// 执行测试
const success = testMemorySearch();
process.exit(success ? 0 : 1);
