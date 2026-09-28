#!/usr/bin/env node

/**
 * Universal npx / npm CLI installer launcher for ai-alerm
 * Auto-detects OS and routes to install.ps1 on Windows or install.sh on POSIX (macOS/Linux)
 */

const { spawn } = require('child_process');
const path = require('path');

const isWin = process.platform === 'win32';
const args = process.argv.slice(2);

let runner;
let runnerArgs;

if (isWin) {
  const installPs1 = path.join(__dirname, '..', 'install.ps1');
  runner = 'powershell';
  runnerArgs = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', installPs1, ...args];
} else {
  const installSh = path.join(__dirname, '..', 'install.sh');
  runner = 'bash';
  runnerArgs = [installSh, ...args];
}

const child = spawn(runner, runnerArgs, {
  stdio: 'inherit'
});

child.on('error', (err) => {
  console.error(`Failed to execute installer via ${runner}:`, err.message);
  process.exit(1);
});

child.on('exit', (code) => {
  process.exit(code || 0);
});
