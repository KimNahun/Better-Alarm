# BetterAlarm

Swift 6 + SwiftUI + MVVM iOS 알람 앱. iOS 17.0+ (AlarmKit 기능은 iOS 26+).

## 아키텍처 규칙 (절대 변경 금지)

- **뷰**: SwiftUI, `@Observable` ViewModel 사용, SwiftUI import 금지 in ViewModel
- **ViewModel**: `@MainActor @Observable final class`, UIKit import 허용
- **Service**: `actor`, 프로토콜 기반 (DI + 테스트 목킹)
- **Model**: `struct Sendable`, Codable
- **디자인 시스템**: `PersonalColorDesignSystem` 패키지 — 반드시 사용. 아래 규칙 위반 시 즉시 수정.

  **색상 토큰** (하드코딩 `Color(red:)` / `UIColor(red:)` 사용 금지):
  ```swift
  // SwiftUI
  Color.pTextPrimary / .pTextSecondary / .pTextTertiary
  Color.pAccentPrimary / .pBackgroundTop / .pBackgroundBottom
  // UIKit
  UIColor.pTextPrimary / UIColor.pAccentPrimary
  // 테마 연동
  theme.colors.accentPrimary / theme.colors.backgroundTop
  ```

  **컴포넌트** (자체 구현 금지):
  ```swift
  GlassCard { content }          // 카드 컨테이너 (SwiftUI)
  HapticManager.impact()         // 기본 medium 햅틱
  HapticManager.impact(.light / .heavy)
  HapticManager.notification(.success / .error / .warning)
  HapticManager.selection()
  // 테마 적용
  .pTheme(themeManager.currentTheme)
  ```

  **토스트**: 자체 구현 금지 — `PersonalColorDesignSystem` 내 토스트 컴포넌트 사용

## 빌드

```bash
xcodebuild -project BetterAlarm.xcodeproj \
  -scheme BetterAlarm \
  -destination 'id=1CE14D49-DEB7-4BED-AFEE-AF349E430DB3' \
  build 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'
```

## 테스트

```bash
xcodebuild test \
  -project BetterAlarm.xcodeproj \
  -scheme BetterAlarm \
  -destination 'id=1CE14D49-DEB7-4BED-AFEE-AF349E430DB3' \
  2>&1 | tail -5
```

## 주요 파일 위치

| 역할 | 경로 |
|------|------|
| 앱 진입점 | `BetterAlarm/App/BetterAlarmApp.swift` |
| 알람 CRUD | `BetterAlarm/Services/AlarmStore.swift` |
| 알람 목록 VM | `BetterAlarm/ViewModels/AlarmList/AlarmListViewModel.swift` |
| 테스트 목 | `BetterAlarmTests/Support/Mocks/` |
| 테스트 픽스처 | `BetterAlarmTests/Support/Fixtures/AlarmFixtures.swift` |
| 버그 회귀 테스트 | `BetterAlarmTests/EdgeCases_Supplement/` |

## 하네스 파이프라인

신규 기능 개발은 `/harness [요청 내용]` 커맨드로만 실행.
**시스템 레벨로 강제됨**: `BetterAlarm/` 에 새 Swift 파일을 직접 Write하면 Hook이 차단함.
버그 수정·피드백 반영(기존 파일 Edit)은 하네스 불필요.

## 커밋 컨벤션

```
harness: [단계N] {설명}   ← 하네스 파이프라인 단계
feedback R{N}-{#}: {설명}  ← 사용자 피드백 반영
fix: {설명}                ← 버그 수정
chore: {설명}              ← 의존성·설정 변경
```

## 주의사항

- `BetterAlarmWidget/` 폴더는 별도 타깃 — 직접 수정 시 위젯 빌드 확인 필요
- `harness/output/` ↔ `BetterAlarm/` 동기화는 하네스 단계 5에서만 수행
- `UserDefaults` 키: `"savedAlarms_v2"` (테스트 후 반드시 `removeObject` 정리)
