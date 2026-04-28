#!/usr/bin/env node

/**
 * PreToolUse Hook: 민감사항 커밋 차단
 *
 * git add/commit 명령 실행 전에 민감 파일이 포함되어 있는지 검사.
 * Secrets.xcconfig, .env, .p12, .pem, credentials 등이 staged 되면 차단.
 */

const { execSync } = require('child_process');
const fs = require('fs');

const SENSITIVE_PATTERNS = [
  /secret/i,
  /credential/i,
  /\.env$/,
  /\.env\./,
  /\.p12$/,
  /\.pem$/,
  /apikey/i,
  /\.xcconfig$/,
];

// xcconfig 중 Secrets 관련만 차단 (일반 xcconfig는 허용)
const SECRETS_XCCONFIG = /secret/i;

function run() {
  let input = '';
  try {
    input = fs.readFileSync('/dev/stdin', 'utf8');
  } catch {
    process.exit(0);
  }

  let command = '';
  try {
    const data = JSON.parse(input);
    command = data.command || '';
  } catch {
    process.exit(0);
  }

  // git commit 또는 git add 명령이 아니면 스킵
  if (!command.includes('git commit') && !command.includes('git add')) {
    process.exit(0);
  }

  // staged 파일 목록 확인
  let stagedFiles = '';
  try {
    stagedFiles = execSync('git diff --cached --name-only 2>/dev/null', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();
  } catch {
    process.exit(0);
  }

  if (!stagedFiles) {
    process.exit(0);
  }

  const files = stagedFiles.split('\n');
  const blocked = [];

  for (const file of files) {
    const basename = file.split('/').pop().toLowerCase();

    // Secrets.xcconfig 계열
    if (basename.endsWith('.xcconfig') && SECRETS_XCCONFIG.test(basename)) {
      blocked.push(file);
      continue;
    }

    // 기타 민감 파일
    for (const pattern of SENSITIVE_PATTERNS) {
      if (pattern.test(basename) && !basename.endsWith('.xcconfig')) {
        blocked.push(file);
        break;
      }
    }
  }

  if (blocked.length > 0) {
    console.error(`BLOCKED: 민감 파일이 커밋에 포함되어 있습니다:\n${blocked.map(f => `  - ${f}`).join('\n')}\n\ngit reset HEAD ${blocked.join(' ')} 로 unstage 하세요.`);
    process.exit(1);
  }

  process.exit(0);
}

run();
