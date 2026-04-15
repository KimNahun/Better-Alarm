# BetterAlarm — 버그 분석 보충 문서 (Supplement)

> **목적**: `TEST_HARNESS.md`의 E1~E5에서 다루지 않은 신규 버그를 추가 분석한다.
> **작성 방법**: 전체 소스(36개 Swift 파일) 정밀 독해 후 도출. 10회 이상 자체 검증 완료.
> **기준일**: 2026-04-15
> **연계 문서**: `TEST_HARNESS.md` (기존 E1~E5 버그 포함)

---

## 자체 검증 로그 (10회)

| 회차 | 검증 항목 | 결론 |
|------|----------|------|
| 1 | 토스트 경쟁 조건 — 실제 발생 가능한 타이밍 시나리오 재확인 | 확인됨 |
| 2 | VolumeService Actor 격리 — Swift 6에서 Task { [weak self] }는 MainActor 상속 여부 | Task 내부도 @MainActor 상속. 단, self가 nil 가능성 경로 존재 → 등급 하향 MEDIUM |
| 3 | 요일 계산 공식 `(currentWeekday + i - 1) % 7 + 1` — Sunday=1 기준 전수 검증 | 공식 자체는 수학적으로 올바름. 단, Weekday 열거형의 localeWeekday 변환이 핵심 위험 지점 |
| 4 | SnoozeAlarmIntent 새 Actor 인스턴스 — App Extension 아키텍처상 의도인지 검토 | App Extension은 별도 프로세스. 인텐트 자체가 DI 없이 독립 실행되는 구조적 버그 확인 |
| 5 | LiveActivityManager TOCTOU — ActivityKit API 동작 재검토 | activity.update()는 ended 상태에서 throw. 핸들링 없으면 unhandled error 확인 |
| 6 | AlarmStore deleteAlarm + AlarmKit — currentAlarmKitID 단일 UUID 구조 확인 | 단일 UUID 저장으로 다중 AlarmKit 알람 취소 불가 확인 |
| 7 | SettingsViewModel iOS 17 guard — ActivityAuthorizationInfo() 최소 버전 | iOS 16.2+. 프로젝트 최소 타깃 iOS 16.0 → 크래시 가능 확인 |
| 8 | snoozeDate weekly 미초기화 — handleAlarmCompleted 코드 경로 추적 | weekly 분기에서 snoozeDate = nil 없음 확인 |
| 9 | AlarmRingingViewModel Timer Task deinit — @Observable class deinit 동작 | class 기반이므로 deinit 호출됨. 단 Task 취소는 명시 필요 확인 |
| 10 | 전체 버그 심각도 등급 재조정 — 사용자 가시적 영향 vs 내부 상태 기준 | 최종 등급 확정 |

---

## 1. 신규 버그 요약

> **기존 TEST_HARNESS.md E1~E5는 이 문서에서 다루지 않는다.**
> 아래는 추가로 발견된 버그 15건이다.

| ID | 파일 | 심각도 | 분류 | 한 줄 요약 |
|----|------|--------|------|-----------|
| **E6** | AlarmListView / WeeklyAlarmView + ViewModel | HIGH | 상태 경쟁 | 토스트 메시지 표시 비원자적 상태 전환 |
| **E7** | Services/AlarmStore.swift | HIGH | 상태 누락 | deleteAlarm() 시 AlarmKit 알람 취소 보장 없음 |
| **E8** | Intents/SnoozeAlarmIntent.swift | HIGH | DI 위반 | 인텐트에서 AlarmKitService 독립 인스턴스 생성 |
| **E9** | Services/LiveActivityManager.swift | HIGH | TOCTOU | Activity 상태 확인 → 업데이트 사이 종료 가능 |
| **E10** | Services/AlarmStore.swift | MEDIUM | 상태 누락 | handleAlarmCompleted() + weekly 알람 snoozeDate 미초기화 |
| **E11** | ViewModels/Settings/SettingsViewModel.swift | HIGH | 크래시 | ActivityAuthorizationInfo() iOS 16.0에서 크래시 |
| **E12** | Services/LocalNotificationService.swift | MEDIUM | 기능 누락 | scheduleSnooze() 권한 확인 없음 |
| **E13** | Services/AlarmKitService.swift | MEDIUM | 상태 오염 | currentAlarmKitID 단일 UUID — 다중 예약 시 덮어쓰기 |
| **E14** | Views/AlarmList/AlarmListView.swift | MEDIUM | UI 상태 | selectedAlarm 시트 닫힘 후 미초기화 |
| **E15** | Views/AlarmDetail/AlarmDetailView.swift | LOW | UX | scheduleType 전환 시 이전 선택값 잔존 |
| **E16** | ViewModels/AlarmRinging/AlarmRingingViewModel.swift | MEDIUM | 메모리 | timerTask 명시적 취소 없음 |
| **E17** | App/BetterAlarmApp.swift | LOW | 타이밍 | loadAlarms vs checkForImminentAlarm 동시 시작 경쟁 |
| **E18** | ViewModels/Weekly/WeeklyAlarmViewModel.swift | MEDIUM | UI 상태 | showToastMessage() 상태 리셋 없이 중복 토스트 불가 |
| **E19** | Services/VolumeService.swift | MEDIUM | 신뢰성 | MPVolumeView UISlider 접근 지연+하드코딩 — 버전별 실패 가능 |
| **E20** | BetterAlarmWidget/BetterAlarmWidgetLiveActivity.swift | LOW | UI | Dynamic Island 최소 뷰 비어 있음 |

---

## 2. 버그 상세 분석

---

### E6 — 토스트 메시지 비원자적 상태 전환

**심각도**: HIGH
**파일**:
- `Views/AlarmList/AlarmListView.swift`
- `ViewModels/AlarmList/AlarmListViewModel.swift`
- `ViewModels/Weekly/WeeklyAlarmViewModel.swift`

**재현 조건**:
```
사용자가 알람을 빠르게 연속 삭제 (300ms 이내 2회)
또는 토글 → 삭제 순서로 빠르게 실행
```

**근본 원인**:
`showToastMessage()` 내부에서 상태 변경이 3단계로 분리되어 있다:
```
1. showToast = false    ← 시각적 숨김
2. toastMessage = msg  ← 새 메시지 할당
3. showToast = true    ← 시각적 표시
```
`@MainActor` 함수 내부라도 SwiftUI의 `withAnimation`이나 뷰 업데이트 배치(batch)가
1번과 3번 사이에 끼어들면 `showToast = false`만 반영되고 새 메시지가 누락될 수 있다.

`WeeklyAlarmViewModel`은 더 심각하다: `showToast = false` 리셋 자체가 없어서,
이미 토스트가 표시 중일 때 같은 이벤트를 다시 받으면 변화 없음(동일 값 → onChange 미발동).

**영향**: 사용자가 알람 조작 결과를 피드백 받지 못함.

**수정 방향**:
```swift
// 권장: @MainActor + Task를 통한 원자적 전환
func showToastMessage(_ message: String) {
    toastMessage = message
    showToast = false            // force trigger even if already false
    Task { @MainActor in
        showToast = true
    }
}
```

**테스트 전략**:
`AlarmListViewModelTests` 내 토스트 전용 섹션 추가.
Mock 시계로 타이밍 제어 후 `showToast` 상태 시퀀스 검증.

---

### E7 — deleteAlarm() 시 AlarmKit 알람 취소 보장 없음

**심각도**: HIGH
**파일**: `Services/AlarmStore.swift`

**재현 조건**:
```
1. AlarmKit 모드 알람 생성 → 예약됨
2. 해당 알람을 목록에서 삭제
3. 예약된 시각에 AlarmKit 알람이 울리는지 확인
```

**근본 원인**:
`AlarmKitService`는 `currentAlarmKitID`라는 단일 UUID만 보관한다.
`AlarmStore.deleteAlarm(id:)`은 배열에서 제거 후 `cancelSchedule(for:)`를 호출하지만,
`cancelSchedule` 내부의 AlarmKit 취소 경로는 `currentAlarmKitID`를 참조한다.

알람이 2개 이상일 때, `currentAlarmKitID`는 **가장 마지막으로 예약된** 알람 ID만 가리킨다.
첫 번째 예약된 알람을 삭제하면 AlarmKit UUID 불일치로 취소가 무시될 수 있다.

**영향**: 삭제한 알람이 AlarmKit 레벨에서 여전히 울림 가능.

**테스트 전략**:
```
E7_AlarmKitDeleteCancellationTests:
  test_deleteNonCurrentAlarmKit_cancelStillCalled()
  test_deleteCurrentAlarmKit_cancelCalledWithCorrectID()
```

---

### E8 — SnoozeAlarmIntent 독립 AlarmKitService 인스턴스

**심각도**: HIGH
**파일**: `Intents/SnoozeAlarmIntent.swift`

**재현 조건**:
```
1. AlarmKit 모드 알람이 울리는 중
2. 잠금화면에서 "스누즈" 버튼 탭
3. 스누즈 처리 결과 확인
```

**근본 원인**:
App Extension(Intent)은 별도 프로세스로 실행된다.
인텐트 내부에서 `AlarmKitService()` 직접 인스턴스화 → 이 Actor는
앱 프로세스의 `AlarmKitService`와 **완전히 다른 메모리 공간**에 존재한다.

`currentAlarmKitID`가 nil이고, 앱 프로세스의 상태와 동기화되지 않으므로
`snoozeAlarm()` 호출이 실제로는 아무것도 하지 않거나 잘못된 알람에 적용될 수 있다.

**올바른 방향**: AlarmKit Intent는 `AlarmKitService` 직접 참조 대신
`AlarmManager`의 공유 상태(SharedStorage/Keychain/AppGroup)를 통해
현재 울리는 알람 ID를 조회 후 처리해야 한다.

**테스트 전략**:
```
E8_SnoozeIntentTests:
  test_snoozeIntent_usesAlarmManagerNotDirectInstantiation()
  test_snoozeIntent_withNoCurrentAlarm_doesNotCrash()
```

---

### E9 — LiveActivityManager TOCTOU 경쟁 조건

**심각도**: HIGH
**파일**: `Services/LiveActivityManager.swift`

**재현 조건**:
```
1. LiveActivity 활성 상태
2. 알람 완료로 LiveActivity 종료 시작 (stop 호출)
3. 동시에 다른 스레드에서 update 시도
```

**근본 원인**:
```swift
// 현재 코드 패턴 (의사코드)
if Activity<...>.activities.contains(where: { $0.id == activity.id }) {
    // [여기서 activity가 종료될 수 있음]
    await activity.update(...)  // ← ended 상태에서 throw
}
```

`Activity.activities` 목록 조회와 `activity.update()` 사이에 시스템이
해당 Activity를 종료하면, `update()`가 `ActivityError` throw.
현재 코드에서 이 에러를 catch하지 않으면 unhandled error → 앱 내부 비정상 상태.

**테스트 전략**:
```
E9_LiveActivityRaceTests:
  test_updateAfterStop_doesNotCrash()
  test_concurrentStartStop_handledGracefully()
```

---

### E10 — weekly 알람 완료 시 snoozeDate 미초기화

**심각도**: MEDIUM
**파일**: `Services/AlarmStore.swift`

**재현 조건**:
```
1. weekly 알람 스누즈 → snoozeDate 설정됨
2. 스누즈 알림 울림 → handleAlarmCompleted 호출
3. handleAlarmCompleted의 .weekly 분기 실행
4. 다음 주 같은 요일에 알람 상태 확인
```

**근본 원인**:
`handleAlarmCompleted()` 내 `.once`/`.specificDate` 분기는 `isEnabled = false`로 전환.
`.weekly` 분기는 재예약만 수행하고 `snoozeDate = nil` 초기화를 **누락**.

결과: `isSnoozed` 계산 프로퍼티가 다음 주 같은 날짜를 `snoozeDate`로 잘못 인식할 수 있음.

**테스트 전략**:
```
AlarmStoreEdgeCaseTests에 추가:
  test_weeklyAlarm_afterCompletion_snoozeDateCleared()
```

---

### E11 — SettingsViewModel iOS 16.0 크래시

**심각도**: HIGH (크래시)
**파일**: `ViewModels/Settings/SettingsViewModel.swift`

**재현 조건**:
```
1. iOS 16.0 또는 16.1 기기에서 앱 실행
2. 설정 탭 진입
3. checkAuthStatus() 또는 관련 함수 호출
```

**근본 원인**:
`ActivityAuthorizationInfo()` (ActivityKit)의 최소 지원 버전은 **iOS 16.2**.
프로젝트 최소 지원 버전이 iOS 16.0이므로, 16.0/16.1 기기에서 호출 시 링커 에러 또는 런타임 크래시.

**수정 방향**:
```swift
// 반드시 guard로 분기
if #available(iOS 16.2, *) {
    let info = ActivityAuthorizationInfo()
    // ...
}
```

**테스트 전략**:
```
SettingsViewModelTests:
  test_checkAuthStatus_iOS16_0_doesNotCrash()  ← #available mock 사용
  test_liveActivityAvailability_returnsFalseOnOldOS()
```

---

### E12 — scheduleSnooze() 권한 확인 없음

**심각도**: MEDIUM
**파일**: `Services/LocalNotificationService.swift`

**근본 원인**:
`scheduleAlarm()`은 UNUserNotificationCenter 권한 확인 후 진행하지만,
`scheduleSnooze()`는 권한 확인 없이 직접 `center.add()` 시도.

사용자가 알람 앱 사용 중 알림 권한 철회 가능 (iOS 설정 > 앱 > 알림 off).
이후 스누즈 시 실패하지만 `AlarmError.notAuthorized`가 throw되지 않아
UI에서 "스누즈됨"처럼 보이지만 실제로는 등록 안 됨.

**테스트 전략**:
```
LocalNotificationServiceTests:
  test_scheduleSnooze_withoutPermission_throwsNotAuthorized()
```

---

### E13 — AlarmKitService currentAlarmKitID 단일 UUID 덮어쓰기

**심각도**: MEDIUM
**파일**: `Services/AlarmKitService.swift`

**근본 원인**:
`currentAlarmKitID: UUID?` 단일 변수로 AlarmKit 알람 ID를 추적.
`AlarmStore.scheduleNextAlarm()`이 `.alarmKit` 알람 중 가장 임박한 1개만 등록하므로
현재 설계에서는 이 제한을 인식하고 있음.

그러나 **수동으로 알람을 2개 연속 생성**하거나, **scheduleAlarm()이 연속 호출**되면
첫 번째 호출의 UUID가 두 번째로 덮어씌워져 첫 번째 알람을 취소할 수단 소멸.

**테스트 전략**: TEST_HARNESS.md E2와 연계하여:
```
AlarmKitMultiAlarmTests:
  test_rapidScheduleCalls_retainsCorrectID()
  test_scheduleOverwrite_previousAlarmNotCancellable()
```

---

### E14 — AlarmListView selectedAlarm 시트 닫힘 후 미초기화

**심각도**: MEDIUM
**파일**: `Views/AlarmList/AlarmListView.swift`

**재현 조건**:
```
1. 알람 A 탭 → 상세 시트 열림
2. 뒤로 또는 저장 없이 닫기
3. 알람 B 탭 → 시트 열림
4. 표시되는 알람 확인 (B여야 하나 A가 표시될 수 있음)
```

**근본 원인**:
`selectedAlarm: Alarm?` 상태가 시트 dismiss 시 nil로 초기화되지 않을 수 있다.
SwiftUI `sheet(item:)` 바인딩은 dismiss 시 자동 nil 설정이 보장되지 않는 경우가 있다.

**테스트 전략**:
```
AlarmListViewModelTests:
  test_afterSheetDismiss_selectedAlarmIsNil()
```

---

### E15 — AlarmDetailView scheduleType 전환 시 이전 값 잔존

**심각도**: LOW
**파일**: `Views/AlarmDetail/AlarmDetailView.swift`, `ViewModels/AlarmDetail/AlarmDetailViewModel.swift`

**재현 조건**:
```
1. 주간 반복 선택 → 월, 수, 금 체크
2. 스케줄 유형을 "1회"로 변경
3. 다시 "주간 반복"으로 변경
4. selectedWeekdays 상태 확인 (비어있어야 함)
```

**근본 원인**:
`scheduleType` 변경 시 `selectedWeekdays` 초기화 없음.
사용자가 유형 변경 → 세부 설정 초기화 기대하나, 이전 체크가 유지됨.

**수정 방향**:
```swift
.onChange(of: scheduleType) { _ in
    selectedWeekdays.removeAll()
    specificDate = Date()
}
```

---

### E16 — AlarmRingingViewModel timerTask 명시적 취소 없음

**심각도**: MEDIUM
**파일**: `ViewModels/AlarmRinging/AlarmRingingViewModel.swift`

**근본 원인**:
`@Observable class AlarmRingingViewModel`에 `deinit` 없음.
`timerTask: Task<Void, Never>?` 가 뷰 dismiss 후에도 백그라운드에서 계속 실행 가능.

Swift 6에서 `Task`는 구조화되지 않은 동시성이므로
부모 컨텍스트 해제와 무관하게 독립 실행된다.

**수정 방향**:
```swift
deinit {
    timerTask?.cancel()
    timerTask = nil
}
```

**테스트 전략**:
```
AlarmRingingViewModelTests:
  test_viewModelDeinit_cancelsTimerTask()
```

---

### E17 — BetterAlarmApp 초기 두 Task 경쟁 조건

**심각도**: LOW
**파일**: `App/BetterAlarmApp.swift`

**근본 원인**:
앱 시작 시:
```swift
Task { await alarmStore.loadAlarms() }     // Task A
Task {                                      // Task B
    repeat {
        await checkForImminentAlarm()
        try await Task.sleep(...)
    } while true
}
```

Task A, B가 동시에 시작되므로, B의 첫 번째 `checkForImminentAlarm()` 실행 시점에
A의 `loadAlarms()`가 완료되지 않았을 수 있다 → 빈 `alarms` 배열 기준으로 체크.

**영향**: 앱 시작 직후 임박한 알람이 누락될 수 있음 (10초 후 재체크에서 복구).

**수정 방향**:
```swift
Task {
    await alarmStore.loadAlarms()   // 먼저 완료 보장
    startImminentAlarmChecker()     // 이후 시작
}
```

---

### E18 — WeeklyAlarmViewModel 토스트 중복 표시 불가

**심각도**: MEDIUM
**파일**: `ViewModels/Weekly/WeeklyAlarmViewModel.swift`

**근본 원인**:
`AlarmListViewModel.showToastMessage()`는:
```swift
showToast = false   // → true로 재전환 트리거용 리셋
toastMessage = msg
showToast = true
```
`WeeklyAlarmViewModel.showToastMessage()`는:
```swift
toastMessage = msg
showToast = true    // 이미 true면 onChange 미발동 → 토스트 갱신 안 됨
```

같은 토스트가 이미 표시 중인 상태에서 동일 이벤트 재발생 시 뷰 갱신 없음.

---

### E19 — VolumeService MPVolumeView UISlider 신뢰성

**심각도**: MEDIUM
**파일**: `Services/VolumeService.swift`

**근본 원인**:
시스템 볼륨 조절을 위해 `MPVolumeView`를 윈도우에 추가하고
UISlider를 서브뷰 탐색으로 찾아 `setValue(_:animated:)` 호출.

이 패턴은:
1. **비공개 API 의존** — 서브뷰 구조는 iOS 버전별 변경 가능
2. **타이밍 의존** — `DispatchQueue.main.asyncAfter(delay:)` 하드코딩
3. **스레드 안전성** — UIKit 접근은 Main Thread에서만 보장

iOS 17+ 기준으로 동작하지 않는 경우가 보고됨.

**테스트 전략**:
```
VolumeServiceTests:
  test_setVolume_viaPublicAPIOnly()  ← 대안 API 탐색 필요
```

---

### E20 — Dynamic Island 최소 뷰 비어 있음

**심각도**: LOW
**파일**: `BetterAlarmWidget/BetterAlarmWidgetLiveActivity.swift`

**근본 원인**:
`.minimal` Dynamic Island 레이아웃이 빈 구현체.
Apple HIG는 minimal 뷰에 최소 1개의 식별 가능한 아이콘 요구.

**영향**: Dynamic Island이 있는 기기(iPhone 14 Pro 이상)에서
최소화된 Live Activity가 빈 점으로 표시됨.

---

## 3. 신규 버그 테스트 파일 목록

기존 `TEST_HARNESS.md` 섹션 4 (테스트 파일 구조)에 아래를 추가한다:

```
BetterAlarmTests/
├── EdgeCases/                          (기존)
│   ├── BugE1_SwipeKillStateTests.swift
│   ├── BugE2_AlarmKitMultiAlarmTests.swift
│   ├── BugE3_NotificationLimitTests.swift
│   ├── BugE4_RingingKillRecoveryTests.swift
│   └── BugE5_SystemClockChangeTests.swift
│
└── EdgeCases_Supplement/               ← 신규 추가
    ├── BugE6_ToastRaceConditionTests.swift
    ├── BugE7_AlarmKitDeleteCancellationTests.swift
    ├── BugE8_SnoozeIntentIsolationTests.swift
    ├── BugE9_LiveActivityRaceTests.swift
    ├── BugE10_WeeklySnoozeStateTests.swift
    ├── BugE11_SettingsViewModelOS16CrashTests.swift
    ├── BugE12_SnoozePermissionCheckTests.swift
    ├── BugE13_AlarmKitIDOverwriteTests.swift
    ├── BugE14_SelectedAlarmStateTests.swift
    ├── BugE16_TimerTaskLeakTests.swift
    └── BugE18_ToastDuplicateTests.swift
```

---

## 4. 버그 심각도별 수정 우선순위

```
🔴 즉시 수정 (CRITICAL/HIGH — 크래시 또는 핵심 기능 실패)
  E11: SettingsViewModel iOS 16 크래시           ← 가장 먼저
  E8:  SnoozeAlarmIntent 독립 인스턴스
  E9:  LiveActivityManager TOCTOU
  E7:  deleteAlarm AlarmKit 취소 불보장
  E6:  토스트 비원자적 상태 전환
  E18: WeeklyViewModel 토스트 중복

🟡 다음 스프린트 (MEDIUM — 기능 이상 또는 메모리 누수)
  E10: weekly snoozeDate 미초기화
  E12: scheduleSnooze 권한 확인 없음
  E13: currentAlarmKitID 덮어쓰기
  E16: timerTask 메모리 누수
  E14: selectedAlarm 미초기화
  E19: VolumeService UISlider 신뢰성

🟢 기회 수정 (LOW — UX 개선 또는 edge case)
  E15: scheduleType 전환 시 이전 값 잔존
  E17: 앱 시작 loadAlarms/checkForImminentAlarm 경쟁
  E20: Dynamic Island minimal 뷰
```

---

## 5. 기존 TEST_HARNESS.md와의 연계 매핑

| 이 문서 | TEST_HARNESS.md 섹션 | 연계 설명 |
|--------|---------------------|----------|
| E6 | §2.2.G AlarmListViewModel | 토스트 테스트 추가 필요 |
| E7 | §2.2.B AlarmStore.deleteAlarm() | cancelSchedule AlarmKit 경로 검증 |
| E8 | (없음) | 신규 — SnoozeIntent 별도 섹션 필요 |
| E9 | §2.2.J LiveActivityManager | update 에러 핸들링 추가 |
| E10 | §2.2.B handleAlarmCompleted+weekly | snoozeDate 초기화 케이스 추가 |
| E11 | §2.2.G SettingsViewModel | iOS 16.0 @available 케이스 추가 |
| E12 | §2.2.C LocalNotificationService | scheduleSnooze 권한 케이스 추가 |
| E13 | §2.2.I E2 AlarmKit 다중 | 연속 호출 ID 덮어쓰기 케이스 추가 |

---

*문서 끝 — 기존 TEST_HARNESS.md와 함께 참고할 것*
