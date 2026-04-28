#!/usr/bin/env node

/**
 * Stop Hook: 커밋 전 빌드 검증
 *
 * 변경된 .swift 파일이 있으면 빌드를 실행하여 통과 확인 후 커밋한다.
 * 빌드 실패 시 커밋하지 않고 경고만 출력한다.
 *
 * 환경변수:
 *   HARNESS_PROJECT_ROOT - xcodeproj가 있는 프로젝트 루트
 *   HARNESS_BUILD_COMMAND - 빌드 명령어 (없으면 스킵)
 *   HARNESS_SIMULATOR - 시뮬레이터 (기본: 'platform=iOS Simulator,name=iPhone 16')
 */

const { execSync } = require('child_process');
const path = require('path');

function run() {
  const projectRoot = process.env.HARNESS_PROJECT_ROOT || process.cwd();

  // 변경사항 확인
  let diff = '';
  try {
    diff = execSync('git diff --name-only HEAD 2>/dev/null', {
      cwd: projectRoot,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();
  } catch {
    process.exit(0);
  }

  // Swift 파일 변경이 없으면 바로 커밋
  const hasSwiftChanges = diff.split('\n').some(f => f.endsWith('.swift'));
  if (!hasSwiftChanges) {
    doCommit(projectRoot, diff);
    process.exit(0);
  }

  // 빌드 명령어 확인
  const buildCommand = process.env.HARNESS_BUILD_COMMAND;
  if (!buildCommand) {
    // 빌드 명령어 미설정 시 빌드 스킵, 커밋만 진행
    doCommit(projectRoot, diff);
    process.exit(0);
  }

  // 빌드 실행
  try {
    const result = execSync(buildCommand, {
      cwd: projectRoot,
      encoding: 'utf8',
      timeout: 120000,
      stdio: ['pipe', 'pipe', 'pipe']
    });

    if (result.includes('BUILD FAILED')) {
      console.error('[pre-commit-build] BUILD FAILED - 커밋을 건너뜁니다.');
      console.error(result.split('\n').filter(l => l.includes('error:')).slice(0, 5).join('\n'));
      process.exit(0); // exit 0 — 차단하지 않되 커밋도 안 함
    }
  } catch (err) {
    const output = (err.stdout || '') + (err.stderr || '');
    if (output.includes('BUILD FAILED')) {
      console.error('[pre-commit-build] BUILD FAILED - 커밋을 건너뜁니다.');
      process.exit(0);
    }
  }

  // 빌드 성공 → 커밋
  doCommit(projectRoot, diff);
  process.exit(0);
}

function doCommit(cwd, diff) {
  try {
    const files = diff
      .split('\n')
      .map(f => path.basename(f))
      .filter(Boolean)
      .slice(0, 3)
      .join(' ');

    const message = `fix: ${files || '변경사항 자동 커밋'}`;
    execSync('git add -A', { cwd, stdio: 'pipe' });
    execSync(`git commit -m "${message}"`, { cwd, stdio: 'pipe' });
  } catch {
    // 커밋 실패 시 무시
  }
}

run();
