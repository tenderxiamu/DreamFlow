#!/usr/bin/env node
/**
 * 绕开 WorkBuddy 宿主进程的 Windows 命名管道限制，独立拉起 flutter 工具链。
 *
 * 背景：宿主进程（WorkBuddy.exe 多实例）耗尽了自身可用的命名管道名额，
 * 导致会话内 `PortableGit\git.EXE` / `where.EXE` / `cmd.exe` 全部 spawn 失败
 * （ProcessException: OS error 231）。但独立 node.exe 进程不受影响——
 * 本脚本由 node 直接 spawn，自成父进程树，绕开宿主的管道配额。
 *
 * 用法：
 *   node tool/run_flutter.js analyze
 *   node tool/run_flutter.js test
 *   node tool/run_flutter.js doctor
 *   node tool/run_flutter.js <任意 flutter 子命令...>
 */

'use strict';

const { spawnSync } = require('node:child_process');
const path = require('node:path');
const fs = require('node:fs');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const FLUTTER_ROOT = 'C:\\Users\\29718\\fvm\\versions\\3.19.0';
const DART_EXE = path.join(FLUTTER_ROOT, 'bin', 'cache', 'dart-sdk', 'bin', 'dart.exe');
const FLUTTER_TOOLS = path.join(FLUTTER_ROOT, 'bin', 'cache', 'flutter_tools.snapshot');
const FLUTTER_DART_SDK = path.join(FLUTTER_ROOT, 'bin', 'cache', 'dart-sdk');

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('用法: node tool/run_flutter.js <flutter 子命令...>');
  console.error('  例: node tool/run_flutter.js analyze');
  process.exit(2);
}

for (const [label, p] of [['dart.exe', DART_EXE], ['flutter_tools.snapshot', FLUTTER_TOOLS]]) {
  if (!fs.existsSync(p)) {
    console.error(`找不到 ${label}: ${p}`);
    process.exit(2);
  }
}

// 让 flutter 内部拿得到 dart / git，不依赖宿主注入的 PATH
const env = {
  ...process.env,
  FLUTTER_ROOT,
  DART_SDK: FLUTTER_DART_SDK,
  PATH: [
    path.join(FLUTTER_DART_SDK, 'bin'),
    path.join(FLUTTER_ROOT, 'bin'),
    process.env.PATH || '',
  ].join(';'),
  // 关掉遥测与首次运行检查，减少派生进程
  FLUTTER_SUPPRESS_ANALYTICS: 'true',
  CI: 'true',
};

// analyze/test 加 --no-pub，跳过 pub 的联网与子进程开销
if ((args[0] === 'analyze' || args[0] === 'test') && !args.includes('--no-pub')) {
  args.push('--no-pub');
}

console.log(`[run_flutter] cwd  = ${PROJECT_ROOT}`);
console.log(`[run_flutter] exec = dart flutter_tools.snapshot ${args.join(' ')}`);
console.log('[run_flutter] ' + '-'.repeat(60));

const r = spawnSync(DART_EXE, [FLUTTER_TOOLS, ...args], {
  cwd: PROJECT_ROOT,
  env,
  stdio: 'inherit',
  shell: false,
  windowsHide: true,
});

if (r.error) {
  console.error(`[run_flutter] spawn 失败: ${r.error.message}`);
  if (r.error.code === 'ENOENT') {
    console.error('[run_flutter] 提示：flutter.bat 路径不可达。');
  }
  process.exit(3);
}

console.log('[run_flutter] ' + '-'.repeat(60));
console.log(`[run_flutter] exit code = ${r.status}`);
process.exit(r.status === null ? 4 : r.status);
