#!/usr/bin/env node

const { spawn } = require('child_process');
const path = require('path');

const installScript = path.join(__dirname, '..', 'install.sh');

const child = spawn('bash', [installScript, ...process.argv.slice(2)], {
  stdio: 'inherit'
});

child.on('exit', (code) => {
  process.exit(code || 0);
});
