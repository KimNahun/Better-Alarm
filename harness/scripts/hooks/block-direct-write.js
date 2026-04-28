#!/usr/bin/env node

/**
 * PreToolUse Hook: Write 차단
 *
 * 프로젝트 소스 폴더에 새 Swift 파일을 직접 생성하는 것을 차단.
 * /harness 파이프라인을 통해서만 새 파일 생성 가능.
 *
 * 환경변수:
 *   HARNESS_TARGET_DIR - 차단할 프로젝트 소스 폴더 경로 (예: /path/to/YourApp)
 *                        설정하지 않으면 이 훅은 비활성화됨 (모든 Write 허용)
 *
 * 차단 조건:
 *   1. HARNESS_TARGET_DIR가 설정되어 있고
 *   2. 파일 경로가 TARGET_DIR 하위이고
 *   3. .swift 확장자이고
 *   4. 테스트 폴더가 아니고
 *   5. harness/output/ 폴더가 아니고
 *   6. 해당 파일이 아직 존재하지 않는 경우 (새 파일 생성)
 */

const fs = require('fs');
const path = require('path');

function run() {
  const targetDir = process.env.HARNESS_TARGET_DIR;

  // 환경변수 미설정 시 훅 비활성화
  if (!targetDir) {
    process.exit(0);
  }

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

  if (!filePath) {
    process.exit(0);
  }

  const isInTarget = filePath.includes(targetDir + '/') || filePath.includes(targetDir + path.sep);
  const isSwift = filePath.endsWith('.swift');
  const isTest = filePath.includes('Tests/') || filePath.includes('Tests' + path.sep);
  const isHarness = filePath.includes('harness/') || filePath.includes('harness' + path.sep);
  const fileExists = fs.existsSync(filePath);

  if (isInTarget && isSwift && !isTest && !isHarness && !fileExists) {
    console.error(`BLOCKED: ${path.basename(filePath)} - 프로젝트 폴더에 새 Swift 파일을 직접 생성할 수 없습니다. /harness 커맨드로 파이프라인을 실행하세요.`);
    process.exit(1);
  }

  process.exit(0);
}

run();
