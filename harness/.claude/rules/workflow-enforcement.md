---
paths:
  - "**/*.swift"
---
# Workflow Enforcement Rules

이 규칙들은 모든 작업에 자동 적용된다. 슬래시 커맨드 없이도 항상 강제된다.

---

## 1. 신규 기능 → 테스트 코드 필수

새로운 Swift 파일(View 제외)을 생성하거나, 기존 파일에 새 public/internal 함수를 추가하면
**반드시 대응하는 테스트를 함께 작성**한다.

- ViewModel → `Tests/ViewModels/[Feature]ViewModelTests.swift`
- Service → `Tests/Services/[Feature]ServiceTests.swift`
- Model → `Tests/Models/[Model]Tests.swift`
- Swift Testing (`import Testing`, `@Test`, `#expect`) 사용
- Mock은 Protocol 기반 DI로 주입

**테스트 없이 신규 기능을 완료 처리하지 마라.**

---

## 2. 신규 기능 → 로그 필수

새로운 기능을 구현하면 **주요 동작 지점에 로그를 남긴다.**

PROJECT_CONTEXT.md에 로거가 정의되어 있으면 그것을 사용하고,
없으면 `os.Logger`를 사용한다:

```swift
import os

extension Logger {
    static let featureName = Logger(subsystem: Bundle.main.bundleIdentifier ?? "", category: "FeatureName")
}

// 사용
Logger.featureName.info("알람 생성됨: \(alarm.id)")
Logger.featureName.error("알람 저장 실패: \(error)")
```

**로그를 남길 지점:**
- 기능의 시작/완료 (예: `loadItems() 시작`, `loadItems() 완료 - 3건`)
- 에러 발생 시 (예: `저장 실패: \(error)`)
- 중요 상태 변경 (예: `알람 모드 변경: local → alarmKit`)
- 사용자 액션 (예: `삭제 버튼 탭: \(item.id)`)

---

## 3. 기능 완료 / 버그 수정 / 작업 지시 → 커밋 필수

다음 작업을 완료하면 **반드시 git commit을 실행**한다:

| 작업 유형 | 커밋 메시지 형식 |
|-----------|-----------------|
| 신규 기능 완료 | `feat: [기능 설명]` |
| 버그 수정 | `fix: [수정 내용]` |
| 작업 지시 반영 | `chore: [작업 내용]` |
| 테스트 추가 | `test: [테스트 대상]` |
| 리팩토링 | `refactor: [변경 내용]` |

**커밋 타이밍:**
- 하나의 논리적 작업 단위가 끝날 때마다 커밋
- 여러 파일을 수정해도 하나의 작업이면 1커밋
- 커밋 전에 빌드가 통과하는지 확인 (규칙 6)

**커밋 전 민감사항 검사 (필수):**
git add 후, commit 전에 **반드시** 아래를 확인한다:
1. `Secrets.xcconfig` 또는 시크릿 파일이 staged 되지 않았는지
2. 소스 코드에 API 키, 토큰, 비밀번호가 하드코딩되지 않았는지
3. `.env`, `*.p12`, `*.pem`, `credentials` 파일이 포함되지 않았는지
위반 발견 시 즉시 unstage하고 사용자에게 경고한다.

---

## 4. 빌드/테스트 시 시뮬레이터 고정

xcodebuild 실행 시 **PROJECT_CONTEXT.md에 등록된 디바이스 ID 또는 이름을 사용**한다.
매번 새 시뮬레이터를 생성하지 마라.

```bash
# 올바른 예 — 고정된 디바이스 사용
xcodebuild -destination 'id=PROJECT_CONTEXT에_등록된_ID'
xcodebuild -destination 'platform=iOS Simulator,name=iPhone 16'

# 금지 — 새 시뮬레이터 생성
xcrun simctl create "Test-Device-$(uuidgen)" ...
```

**PROJECT_CONTEXT.md에 디바이스가 지정되어 있지 않으면**:
`platform=iOS Simulator,name=iPhone 16` 을 기본값으로 사용한다.

---

## 5. 디자인 시스템 강제

PROJECT_CONTEXT.md에 디자인 시스템이 정의되어 있으면 **반드시 사용**한다.

**위반 즉시 수정 대상:**
```swift
// 금지 — 하드코딩 색상
Color(red: 0.2, green: 0.3, blue: 0.8)
UIColor(red: 0.7, green: 0.5, blue: 1.0, alpha: 1.0)
Color.blue  // semantic이 아닌 리터럴 색상

// 금지 — 하드코딩 폰트
.font(.system(size: 17))
UIFont.systemFont(ofSize: 17)

// 금지 — 디자인 시스템 컴포넌트 자체 구현
struct MyCustomCard: View { ... }  // 패키지에 GlassCard가 있는데 자체 구현
```

디자인 시스템이 없으면 SwiftUI semantic color/font를 사용한다:
`.primary`, `.secondary`, `Color(.systemBackground)`, `.font(.body)` 등

---

## 6. 빌드 오류 검사 — 모든 작업 후 필수

Swift 파일을 생성하거나 수정한 후에는 **반드시 빌드를 실행하여 통과를 확인**한다.

```bash
# PROJECT_CONTEXT.md의 BUILD_COMMAND 사용
# 없으면 기본값:
xcodebuild -project [Project].xcodeproj \
  -scheme [Scheme] \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'
```

- **BUILD SUCCEEDED** → 다음 작업으로 진행
- **BUILD FAILED** → 에러를 수정하고 재빌드. 빌드 실패 상태로 커밋하지 마라.

**적용 시점:**
- 새 파일 생성 후
- 기존 파일 수정 후
- 피드백 반영 후
- 커밋 직전
