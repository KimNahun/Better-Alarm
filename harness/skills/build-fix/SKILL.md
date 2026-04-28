---
name: build-fix
description: Xcode 빌드 에러를 진단하고 수정하는 워크플로우
origin: harness
---

# Build Fix Workflow

## When to Use

- xcodebuild 빌드 실패 시
- Swift 컴파일 에러 해결 시
- SPM 의존성 문제 해결 시

## When NOT to Use

- 런타임 에러 (빌드는 성공하지만 크래시)
- UI 레이아웃 문제
- 로직 버그

## How It Works

### 진단 -> 수정 -> 검증

```
1. 빌드 실행 & 에러 수집
   xcodebuild build 2>&1 | grep "error:" | head -20

2. 에러 분류
   - 타입 에러 (type mismatch, missing conformance)
   - 동시성 에러 (Sendable, actor isolation)
   - import 에러 (missing module)
   - SPM 에러 (dependency resolution)

3. 우선순위 정렬
   import/SPM > 타입 > 동시성 > 기타

4. 1개씩 수정 -> 재빌드 -> 확인

5. 전체 빌드 성공 확인
```

### 빌드 명령어

PROJECT_CONTEXT.md에서 `BUILD_COMMAND`를 읽어 사용.
없으면 기본값:

```bash
xcodebuild -project [Project].xcodeproj \
  -scheme [Scheme] \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'
```

### 일반적인 Swift 6 빌드 에러 패턴

| 에러 | 원인 | 수정 |
|------|------|------|
| `non-sendable type` | actor 경계 넘는 non-Sendable | Sendable 준수 추가 |
| `call to main actor-isolated` | @MainActor 함수를 non-isolated에서 호출 | await 추가 또는 @MainActor 전파 |
| `mutable capture of 'inout' parameter` | 클로저에서 inout 캡처 | 로컬 변수로 복사 |
| `cannot find type` | missing import | import 추가 |

## Examples

```
/build-fix
/build-fix SPM 의존성 해결이 안 돼요
```
