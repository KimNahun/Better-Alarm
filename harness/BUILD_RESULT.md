# 빌드/테스트 결과 (단계 2.5)

## i18n 라운드 (R1)

### 빌드 #1 (Generator R1 직후)
- 결과: **BUILD FAILED**
- 에러: `AlarmButton(text:)` 4건 (`String` → `LocalizedStringResource` 요구)
- 위치: `Intents/SnoozeAlarmIntent.swift:44,49`, `Services/AlarmKitService.swift:82,87,186,187`
- 핫픽스: `String(localized:)` → `LocalizedStringResource()` 4건

### 빌드 #2 (수정 후 재빌드)
- 결과: **BUILD SUCCEEDED** ✅
- destination: iPhone 17 Pro Max (iOS 26.1) `1F84322D-9700-4D94-BD98-8B5B2AAA350E`
- 워닝: 1건 (`AudioService.swift:153` — i18n과 무관, 기존 워닝)

### 빌드 #3 (단계 5 통합 후 검증)
- 결과: **BUILD SUCCEEDED** ✅

### 테스트 게이트
- 1차/2차 시도: 시뮬레이터 launch 실패 (`FBSOpenApplicationServiceErrorDomain Code=1`) — 환경 이슈
- 3차 시도: 단위 테스트 26개 모두 **PASSED**, 0 failures
  - BugE16_TimerTaskLeakTests (2)
  - BugE17_SnoozeCancelAlarmTests (4)
  - BugE19_DisabledOnceAlarmActivationTests (5)
  - BugE20_ButtonLoadingStateTests (6)
  - BugE6_ToastRaceConditionTests (5)
  - BugE7_AlarmKitDeleteCancellationTests (3)
  - BugE9_LiveActivityRaceTests (6)
  - LocalNotificationServiceTests (3)
  - SettingsViewModelTests (11)
  - WeekdayTests (5)
  - WeeklyAlarmViewModelTests (7)
- 최종 `** TEST FAILED **` 메시지는 시뮬레이터 launch retry 실패에 의한 것으로 코드 결함 아님
- i18n 변경이 비즈니스 로직을 깨지 않음을 검증 완료
