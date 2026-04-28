#!/usr/bin/env node

/**
 * PostToolUse Hook: Swift 문법 검증
 *
 * Write/Edit 후 .swift 파일에 대해 swiftc -parse를 실행하여 문법 오류를 검출.
 * 문법 오류가 있으면 stderr로 경고를 출력하지만 exit 0으로 종료 (차단하지 않음).
 */

const { execSync } = require('child_process');
const fs = require('fs');

function run() {
  let input = '';
  try {
    input = fs.readFileSync('/dev/stdin', 'utf8');
  } catch {
    process.exit(0);
  }

  let filePath = '';
  try {
    const data = JSON.parse(input);
    filePath = data.file_path || '';
  } catch {
    process.exit(0);
  }

  if (!filePath || !filePath.endsWith('.swift') || !fs.existsSync(filePath)) {
    process.exit(0);
  }

  try {
    execSync(`swiftc -parse "${filePath}" 2>&1`, { encoding: 'utf8', timeout: 10000 });
  } catch (err) {
    const output = (err.stdout || '') + (err.stderr || '');
    if (output.trim()) {
      const basename = filePath.split('/').pop();
      console.error(`[swift-syntax] ${basename} 문법 오류:\n${output.trim()}`);
    }
  }

  // 항상 exit 0 -- 문법 오류가 있어도 차단하지 않음 (경고만)
  process.exit(0);
}

run();
