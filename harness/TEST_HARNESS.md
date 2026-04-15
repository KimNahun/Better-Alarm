# BetterAlarm — 테스트 하네스 엔지니어링 문서

> **목적**: 실제 테스트 코드 작성 전, 전체 테스트 전략·범위·하네스 구조를 정의한다.
> **구현 시작 금지**: 이 문서는 설계 문서이며, 코드 생성 전 반드시 검토·승인 후 진행한다.
> **기준일**: 2026-04-13

---

## 1. 테스트 전략 개요

### 1.1 테스트 피라미드

```
         ┌──────────┐
         │  UI Test │  ← 5% (핵심 흐름만)
         │ (XCUITest)│
        ┌┴──────────┴┐
        │ Integration │  ← 20% (레이어 간 연동)
        │    Test     │
       ┌┴────────────┴┐
       │   Unit Test  │  ← 75% (로직, ViewModel, Service)
       │  (XCTest)    │
       └──────────────┘
```

### 1.2 타겟별 테스트 구성

| 타겟 | 프레임워크 | 역할 |
|------|-----------|------|
| `BetterAlarmTests` | XCTest | 단위·통합 테스트 |
| `BetterAlarmUITests` | XCUITest | 핵심 사용자 시나리오 E2E |

### 1.3 우선순위 원칙

> 앞선 버그 분석에서 드러난 **5개 심각 버그 케이스**를 최우선으로 커버한다.
> 나머지는 기능별 정상 동작 → 경계값 → 에러 처리 순으로 작성한다.

---

## 2. 테스트 범위 (Coverage Map)

### 2.1 레이어별 커버리지 목표

| 레이어 | 목표 커버리지 | 테스트 종류 |
|--------|-------------|-----------|
| **Model** (`Alarm`, `AlarmSchedule`, `AlarmMode`) | **95%** | Unit |
| **Service** (`AlarmStore`, `LocalNotificationService`, `AudioService`, `VolumeService`) | **85%** | Unit (Mock 주입) |
| **ViewModel** (5개 ViewModel) | **80%** | Unit (Mock 주입) |
| **AppDelegate** | **70%** | Integration |
| **View** (SwiftUI) | **30%** | UI Test (핵심 흐름만) |
| **Widget/LiveActivity** | **50%** | Unit |

### 2.2 기능별 테스트 항목 전체 목록

#### A. 모델 계층 (Model Layer)

**`Alarm.nextTriggerDate()` — 핵심 알고리즘**
- [ ] `.once` — 오늘 미래 시각: 오늘 해당 시각 반환
- [ ] `.once` — 오늘 과거 시각: 내일 해당 시각 반환
- [ ] `.once` — 정확히 현재 시각(경계값): 내일 반환
- [ ] `.once` + `skippedDate` 일치: 모레 반환
- [ ] `.weekly([.monday])` — 오늘이 월요일, 미래 시각: 오늘 반환
- [ ] `.weekly([.monday])` — 오늘이 월요일, 과거 시각: 다음주 월요일 반환
- [ ] `.weekly([.monday, .wednesday])` — 오늘이 화요일: 수요일 반환
- [ ] `.weekly([.saturday, .sunday])` — 오늘이 금요일 23:59: 내일(토) 반환
- [ ] `.weekly([])` — 빈 Set: nil 반환
- [ ] `.weekly(모든요일)` — 매일 설정: 내일 아닌 오늘(미래면) 반환
- [ ] `.weekly` + `skippedDate` 해당일: 다음 해당 요일 반환
- [ ] `.specificDate(미래)`: 해당 Date 반환
- [ ] `.specificDate(과거)`: nil 반환
- [ ] 자정 경계 — 23:58 현재, 23:59 알람: 오늘 23:59 반환
- [ ] 자정 경계 — 00:01 현재, 23:59 알람(.once): 오늘 23:59(과거) → 내일 반환
- [ ] 14일 루프 최대값 — `.weekly([.monday])` 오늘이 화요일: 6일 뒤 반환 (14일 내 탐색 성공)

**`Alarm.shouldSkip()`**
- [ ] `skippedDate = nil`: 항상 false
- [ ] 같은 날 다른 시각: true (inSameDayAs 기반)
- [ ] 다른 날: false
- [ ] 자정 경계(23:59 vs 00:00 다음날): false

**`Alarm` 기타 프로퍼티**
- [ ] `isWeeklyAlarm` — `.weekly` 케이스만 true
- [ ] `isSkippingNext` — `skippedDate != nil`이고 nextTriggerDate가 skippedDate와 같은 날
- [ ] `displayTitle` — title 비어있을 때 기본값 반환
- [ ] `nextAlarmDisplayString` — 포맷 검증

**`AlarmSchedule` Codable**
- [ ] `.once` encode/decode 왕복
- [ ] `.weekly([.monday, .friday])` encode/decode 왕복
- [ ] `.specificDate` encode/decode 왕복
- [ ] 손상된 JSON decode → DecodingError 발생 (크래시 없음)
- [ ] 알 수 없는 `type` 키 decode → DecodingError

**`Weekday`**
- [ ] rawValue 1~7 전체 변환 정확성
- [ ] `localeWeekday` 변환 — Locale.Weekday와 1:1 매핑
- [ ] `shortName` — 7개 요일 한국어 반환

---

#### B. AlarmStore (actor)

**CRUD**
- [ ] `createAlarm()` → `alarms`에 추가됨 + UserDefaults 저장됨
- [ ] `createAlarm()` 중복 ID 없음 (UUID 고유성)
- [ ] `updateAlarm()` → 해당 인덱스 업데이트 + 재정렬 + 재예약
- [ ] `deleteAlarm()` → `alarms`에서 제거 + 알림 취소
- [ ] `deleteAlarm()` 존재하지 않는 ID: 무시 (크래시 없음)
- [ ] `loadAlarms()` — UserDefaults 정상 데이터: 복원됨
- [ ] `loadAlarms()` — UserDefaults 없음: `alarms = []`
- [ ] `loadAlarms()` — 손상된 JSON: `alarms = []` (크래시 없음)

**토글 & 상태 전환**
- [ ] `toggleAlarm(enabled: true)` → `isEnabled = true` + 재예약
- [ ] `toggleAlarm(enabled: false)` → `isEnabled = false` + 알림 취소
- [ ] 비활성 알람 toggle off: 무시
- [ ] `.once` 알람 비활성화: 알림 취소만
- [ ] `.weekly` 알람 비활성화: 알림 취소만

**스누즈**
- [ ] `snoozeAlarm(minutes: 5)` → `snoozeDate` 설정 + 기존 알림 취소 + 스누즈 알림 등록
- [ ] `snoozeAlarm()` 비활성 알람: 무시
- [ ] 스누즈 후 `handleAlarmCompleted()` — snoozeDate 초기화됨

**건너뛰기**
- [ ] `skipOnceAlarm()` → `skippedDate` = nextTriggerDate + 재예약
- [ ] `skipOnceAlarm()` — nextTriggerDate가 nil인 알람: 무시
- [ ] `clearSkipOnceAlarm()` → `skippedDate = nil` + 재예약

**완료 처리**
- [ ] `handleAlarmCompleted()` + `.once` → `isEnabled = false`로 변경
- [ ] `handleAlarmCompleted()` + `.specificDate` → `isEnabled = false`로 변경
- [ ] `handleAlarmCompleted()` + `.weekly` → 재예약 (비활성화 안 함)
- [ ] `handleAlarmCompleted()` + `.weekly` + `skippedDate` → `skippedDate` 초기화 후 재예약
- [ ] `handleAlarmCompleted()` 존재하지 않는 ID: 무시 (크래시 없음)
- [ ] `handleAlarmCompleted()` 이미 비활성 알람: 무시

**scheduleNextAlarm 분기**
- [ ] `.local` 모드 알람만 있을 때: `localNotificationService.scheduleAlarm` 호출됨
- [ ] `.alarmKit` 모드 알람만 있을 때: `alarmKitService.scheduleAlarm` 1회만 호출됨 (최단 알람)
- [ ] `.alarmKit` 모드 알람 2개 이상: 가장 임박한 1개만 등록됨
- [ ] 활성 알람 없을 때: 아무것도 호출 안 됨
- [ ] `.local`과 `.alarmKit` 혼재: 각각 올바른 서비스 호출

**정렬**
- [ ] `sortAlarms()` — nextTriggerDate 오름차순 정렬
- [ ] 비활성 알람 정렬 위치 (마지막)

---

#### C. LocalNotificationService (actor)

**권한**
- [ ] 권한 없음 → `scheduleAlarm` → `AlarmError.notAuthorized` throw
- [ ] 권한 있음 → 정상 진행

**스케줄링**
- [ ] `scheduleAlarm()` — 기존 알림 취소 후 새 요청 등록
- [ ] `scheduleAlarm()` — `repeats: false` 확인 (1회 발화)
- [ ] `scheduleAlarm()` — content.userInfo에 `alarmID` 포함
- [ ] `scheduleAlarm()` — `nextTriggerDate()` nil이면 `AlarmError.scheduleFailed`
- [ ] `scheduleAlarm()` 후 `scheduleRepeatingAlerts()` 호출됨

**반복 알림**
- [ ] `scheduleRepeatingAlerts(count: 30)` — 30개 알림 등록됨
- [ ] 각 알림 identifier: `"\(alarmID)-repeat-\(i)"` 형식
- [ ] 각 알림 발화 시각: triggerDate + i*5초
- [ ] **[심각버그] 알람 3개 시 총 알림 수 = 93 > 64 한도**: 초과 알림 등록 실패 감지

**취소**
- [ ] `cancelAlarm(for:)` — 해당 알람의 모든 알림 식별자 제거 (초기 + 반복 30개 + 스누즈)
- [ ] `cancelAllAlarms()` — 등록된 모든 알림 제거

**스누즈**
- [ ] `scheduleSnooze(for:minutes:)` — `UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)`
- [ ] 스누즈 identifier: `"\(alarmID)-snooze"`

**백그라운드 리마인더**
- [ ] `scheduleBackgroundReminder(for:)` — 즉시 발화 알림 1건 등록
- [ ] `cancelBackgroundReminder()` — 리마인더 알림만 취소

---

#### D. AudioService (actor)

**재생**
- [ ] `playAlarmSound(soundName:)` — AVAudioPlayer 재생 시작
- [ ] 존재하지 않는 soundName → `AlarmError.soundNotFound`
- [ ] `isSilentAlarm = true` + 이어폰 미연결 → `AlarmError.earphoneNotConnected`
- [ ] `isSilentAlarm = true` + 이어폰 연결 → 정상 재생
- [ ] `stopSound()` — 재생 중지 + 세션 비활성화

**이어폰 감지**
- [ ] `isEarphoneConnected()` — 유선 이어폰 연결 시 true
- [ ] `isEarphoneConnected()` — Bluetooth 연결 시 true
- [ ] `isEarphoneConnected()` — 연결 없음 시 false

---

#### E. VolumeService (@MainActor)

**볼륨 제어**
- [ ] `prepareForAlarm()` — 현재 볼륨 캡처 + 80%로 올림
- [ ] `startVolumeGuard()` — 볼륨 낮아지면 80%로 복원
- [ ] `stopVolumeGuard()` — 감시 종료
- [ ] `restoreVolume()` — 저장된 원래 볼륨으로 복원

---

#### F. AlarmKitService (actor)

> iOS 26+ 전용. 시뮬레이터/낮은 iOS 버전에서는 `#available` 가드로 스킵.

**스케줄링**
- [ ] `scheduleAlarm()` — `.once` → `AlarmKit.Alarm.Schedule.fixed(date)` 사용
- [ ] `scheduleAlarm()` — `.weekly([.monday, .wednesday])` → `.relative` + `Recurrence.weekly(...)` 사용
- [ ] `scheduleAlarm()` — 비활성 알람 → 즉시 반환 (예약 안 함)
- [ ] `scheduleAlarm()` — 권한 없음 → `AlarmError.notAuthorized`
- [ ] `scheduleAlarm()` 전 `stopAllAlarms()` 호출됨 (기존 제거)
- [ ] **[심각버그] 다중 AlarmKit 알람**: 2개 있을 때 1개만 등록됨 확인 (현재 설계 한계 문서화)

**중지/스누즈**
- [ ] `stopAlarm()` — currentAlarmKitID로 stop 호출
- [ ] `snoozeAlarm(minutes:)` — AlarmKit snooze API 호출

---

#### G. ViewModel 계층

**AlarmListViewModel**
- [ ] `loadAlarms()` — store에서 로드 → `alarms` 업데이트
- [ ] `requestDelete(_:)` — store.deleteAlarm 호출
- [ ] `requestToggle(_:enabled:)` — `.weekly` off → `pendingDisableAlarm` 설정 (다이얼로그 트리거)
- [ ] `requestToggle(_:enabled:)` — `.once` off → 즉시 비활성화
- [ ] `confirmDisable()` — store.toggleAlarm(false) 호출
- [ ] `skipNextOccurrence()` — store.skipOnceAlarm 호출
- [ ] `nextAlarmDisplayString` — 활성 알람 없을 때 nil
- [ ] `nextAlarmDisplayString` — 가장 임박한 알람의 문자열 포맷

**AlarmDetailViewModel**
- [ ] `save()` — 새 알람: store.createAlarm 호출
- [ ] `save()` — 편집 모드: store.updateAlarm 호출
- [ ] `save()` — `scheduleType == .weekly` + `selectedWeekdays.isEmpty` → 저장 안 함 + 경고 메시지
- [ ] `selectedWeekdays.insert/remove` — 토글 동작
- [ ] `displayHour` ↔ `hour` — AM/PM 변환 정확성
- [ ] `isPM = true, displayHour = 12` → `hour = 12` (정오)
- [ ] `isPM = false, displayHour = 12` → `hour = 0` (자정)
- [ ] `isPM = true, displayHour = 1` → `hour = 13`
- [ ] `scheduleType` 변경 시 연동 초기화

**WeeklyAlarmViewModel**
- [ ] `filteredAlarms` — `selectedDay = nil`: 전체 반환
- [ ] `filteredAlarms` — `selectedDay = .monday`: 월요일 포함 알람만 반환
- [ ] `filteredAlarms` — 선택 요일 알람 없음: 빈 배열
- [ ] `requestToggle()` — `.weekly` off → `pendingDisableAlarm` 설정

**AlarmRingingViewModel**
- [ ] `currentTimeString` — HH:MM 형식 갱신
- [ ] `stopAlarm()` — AudioService.stopSound + store.handleAlarmCompleted 호출
- [ ] `snoozeAlarm()` — AudioService.stopSound + store.snoozeAlarm 호출
- [ ] 타이머 시작/종료 라이프사이클

**SettingsViewModel**
- [ ] `setLiveActivityEnabled(true)` — LiveActivityManager 활성화
- [ ] `setLiveActivityEnabled(false)` — LiveActivityManager 비활성화
- [ ] `checkAuthStatus()` — 알림 권한·AlarmKit 권한 상태 조회

---

#### H. AppDelegate (통합)

**앱 생명주기**
- [ ] `applicationDidEnterBackground` — Local 알람 있음: `scheduleBackgroundReminder` 호출
- [ ] `applicationDidEnterBackground` — Local 알람 없음: 호출 안 함
- [ ] `applicationWillEnterForeground` — `cancelBackgroundReminder` 호출
- [ ] `applicationWillTerminate` — 활성 Local 알람 전체 재등록 시도
- [ ] **[심각버그] `applicationWillTerminate`** — DispatchGroup+Task 타이밍: 2초 내 완료 여부 검증

**알림 델리게이트**
- [ ] `willPresent` — alarmID 매칭 성공 → `.alarmShouldRing` 포스트 + `return []`
- [ ] `willPresent` — alarmID 없는 알림 → `return [.banner, .sound, .badge]`
- [ ] `willPresent` — 비활성 알람 ID → 울림 화면 표시 안 함
- [ ] `didReceive response` — 탭 시 `.alarmShouldRing` 포스트

---

#### I. 엣지 케이스 / 버그 집중 테스트

> 앞선 분석에서 도출된 **심각 버그 5개**에 대한 전용 테스트 섹션

**[E1] 강제 종료(swipe kill) 후 상태 불일치**
- [ ] `.once` 알람이 울린 후 `handleAlarmCompleted` 미호출 시 → 재시작 후 `isEnabled = true` 상태 유지 확인
- [ ] 재시작 후 `loadAlarms()` → nextTriggerDate가 과거인 `.once` 알람 처리 방식 확인

**[E2] AlarmKit 다중 알람 누락**
- [ ] AlarmKit 모드 알람 2개 → `scheduleNextAlarm()` → `alarmKitService.scheduleAlarm()` 1회만 호출됨 (Mock 검증)
- [ ] 첫 번째 알람 완료 후 두 번째 알람 자동 예약 여부 확인

**[E3] 알림 64개 한도 초과**
- [ ] Local 모드 알람 3개 → `scheduleAlarm()` × 3 → 총 등록 시도 알림 수 = 93 확인
- [ ] `UNUserNotificationCenter.pendingNotificationRequests()` 수가 64 이하인지 검증

**[E4] 울림 도중 강제 종료 → once 재울림**
- [ ] `ringingAlarm` 상태에서 `handleAlarmCompleted` 없이 로드 시 → `.once` 알람이 `isEnabled = true`인 채로 남아있음 확인
- [ ] 이 상태에서 `nextTriggerDate()` → 과거 날짜 반환 여부 (내일로 재예약 버그 가능성)

**[E5] 시스템 시간 변경**
- [ ] `NSNotification.NSSystemClockDidChangeNotification` 수신 핸들러 존재 여부 확인 (현재 없음 → 문서화)
- [ ] 시간 앞으로 변경 시뮬레이션: 이미 과거가 된 UNCalendarNotification 동작 확인

---

#### J. Live Activity / Widget (단위)

- [ ] `LiveActivityManager.start(for:)` — ActivityAttributes 생성 + Activity 시작
- [ ] `LiveActivityManager.update(for:)` — ContentState 업데이트
- [ ] `LiveActivityManager.stop()` — Activity 종료
- [ ] `isEnabled = false` 시 start 무시

---

## 3. 하네스 엔지니어링 — Test Double 설계

### 3.1 목(Mock) vs 페이크(Fake) vs 스텁(Stub) 구분

| 타입 | 용도 | 적용 대상 |
|------|------|----------|
| **Mock** | 호출 여부·횟수·인수 검증 | LocalNotificationService, AudioService, AlarmKitService |
| **Fake** | 실제 동작하는 인메모리 대체 | AlarmStore (UserDefaults 대신 인메모리) |
| **Stub** | 고정 값 반환 | 권한 상태, 시간, 볼륨 |

### 3.2 프로토콜 기반 DI 구조 (테스트 진입점)

현재 코드에 **프로토콜이 없는 서비스**들이 있어 Mock 주입이 불가능하다.
테스트 하네스 구성 전에 아래 프로토콜을 추가해야 한다:

```
AlarmStoreProtocol          ← AlarmStore가 채택
AlarmKitServiceProtocol     ← AlarmKitService가 채택 (이미 존재)
LocalNotificationServiceProtocol ← 이미 존재
AudioServiceProtocol        ← 이미 존재
VolumeServiceProtocol       ← 이미 존재
LiveActivityManagerProtocol ← 추가 필요
```

### 3.3 Mock 클래스 목록

#### `MockLocalNotificationService`
```
채택: LocalNotificationServiceProtocol
추적 변수:
  - scheduleAlarmCallCount: Int
  - scheduleAlarmCalledWith: [Alarm]
  - cancelAlarmCallCount: Int
  - scheduleRepeatingAlertsCallCount: Int
  - scheduleSnoozeCalledWith: [(Alarm, Int)]
  - backgroundReminderScheduled: Bool
  - canceledAlarmIDs: [UUID]

설정 가능한 동작:
  - shouldThrowOnSchedule: Bool (권한 없음 시뮬레이션)
  - authorizationStatus: UNAuthorizationStatus
```

#### `MockAlarmKitService`
```
채택: AlarmKitServiceProtocol
추적 변수:
  - scheduleAlarmCallCount: Int
  - scheduleAlarmCalledWith: [Alarm]
  - stopAllAlarmsCallCount: Int
  - snoozeCallCount: Int

설정 가능한 동작:
  - isAvailable: Bool (iOS 버전 시뮬레이션)
  - shouldThrow: Bool
```

#### `MockAudioService`
```
채택: AudioServiceProtocol
추적 변수:
  - playCallCount: Int
  - stopCallCount: Int
  - lastPlayedSoundName: String?

설정 가능한 동작:
  - isEarphoneConnectedResult: Bool
  - shouldThrowOnPlay: Bool
```

#### `MockVolumeService`
```
채택: VolumeServiceProtocol
추적 변수:
  - prepareCallCount: Int
  - guardStartCount: Int
  - guardStopCount: Int
  - restoreCallCount: Int
```

#### `MockLiveActivityManager`
```
채택: LiveActivityManagerProtocol
추적 변수:
  - startCallCount: Int
  - updateCallCount: Int
  - stopCallCount: Int
  - isEnabled: Bool
```

#### `InMemoryAlarmStore`
```
실제 AlarmStore 로직을 UserDefaults 없이 인메모리로 실행하는 Fake.
AlarmStoreProtocol 채택.
테스트 시 상태 격리 보장.
```

#### `MockUNUserNotificationCenter`
```
UNUserNotificationCenter를 래핑하는 테스트용 클래스.
추적 변수:
  - addedRequests: [UNNotificationRequest]
  - removedIdentifiers: [String]
  - pendingRequestsResult: [UNNotificationRequest]
  - authorizationStatus: UNAuthorizationStatus

UNUserNotificationCenter를 직접 상속하거나,
프로토콜(NotificationCenterProtocol)로 추상화하여 주입.
```

#### `MockCalendar`
```
Calendar를 래핑하여 "현재 시각"을 고정하는 Test Double.
nextTriggerDate() 알고리즘 테스트 시 날짜 제어에 사용.
Clock 프로토콜(swift-clocks 또는 직접 정의) 활용 권장.
```

### 3.4 시간 제어 전략 (Clock Injection)

`nextTriggerDate(from:)` 는 이미 `date: Date = Date()` 파라미터를 받으므로
테스트에서 `Date(timeIntervalSince1970: ...)` 고정값을 주입 가능. 추가 인프라 불필요.

AppDelegate의 생명주기 테스트는 `Date` 주입보다 `XCTestExpectation` 기반 비동기 검증을 사용.

---

## 4. 테스트 파일 구조

```
BetterAlarmTests/
├── Support/                          ← 공통 인프라
│   ├── Mocks/
│   │   ├── MockLocalNotificationService.swift
│   │   ├── MockAlarmKitService.swift
│   │   ├── MockAudioService.swift
│   │   ├── MockVolumeService.swift
│   │   ├── MockLiveActivityManager.swift
│   │   └── MockUNUserNotificationCenter.swift
│   ├── Fakes/
│   │   └── InMemoryAlarmStore.swift
│   ├── Fixtures/
│   │   └── AlarmFixtures.swift       ← 테스트용 Alarm 객체 팩토리
│   └── Extensions/
│       └── XCTestCase+Async.swift    ← async/await 테스트 헬퍼
│
├── Models/
│   ├── AlarmNextTriggerDateTests.swift
│   ├── AlarmShouldSkipTests.swift
│   ├── AlarmScheduleCodableTests.swift
│   ├── AlarmPropertiesTests.swift
│   └── WeekdayTests.swift
│
├── Services/
│   ├── AlarmStoreTests.swift
│   ├── AlarmStoreCRUDTests.swift
│   ├── AlarmStoreSchedulingTests.swift
│   ├── AlarmStoreEdgeCaseTests.swift   ← 심각 버그 E1~E5 전용
│   ├── LocalNotificationServiceTests.swift
│   ├── LocalNotificationLimitTests.swift ← E3 (64개 한도) 전용
│   ├── AudioServiceTests.swift
│   └── VolumeServiceTests.swift
│
├── ViewModels/
│   ├── AlarmListViewModelTests.swift
│   ├── AlarmDetailViewModelTests.swift
│   ├── WeeklyAlarmViewModelTests.swift
│   ├── AlarmRingingViewModelTests.swift
│   └── SettingsViewModelTests.swift
│
├── Integration/
│   ├── AlarmLifecycleTests.swift       ← 생성→울림→완료 전체 흐름
│   ├── SnoozeFlowTests.swift           ← 스누즈 전체 흐름
│   ├── SkipFlowTests.swift             ← 건너뛰기 전체 흐름
│   ├── AppDelegateLifecycleTests.swift ← 생명주기 통합
│   └── MultiAlarmSchedulingTests.swift ← 다중 알람 시나리오
│
└── EdgeCases/
    ├── BugE1_SwipeKillStateTests.swift
    ├── BugE2_AlarmKitMultiAlarmTests.swift
    ├── BugE3_NotificationLimitTests.swift
    ├── BugE4_RingingKillRecoveryTests.swift
    └── BugE5_SystemClockChangeTests.swift

BetterAlarmUITests/
├── Support/
│   └── UITestFixtures.swift
├── AlarmCreationFlowTests.swift        ← 생성 E2E
├── AlarmListInteractionTests.swift     ← 목록 조작 E2E
├── WeeklyAlarmFlowTests.swift          ← 주간 알람 필터링 E2E
└── SettingsFlowTests.swift             ← 설정 화면 E2E
```

---

## 5. 핵심 테스트 케이스 상세 설계

### 5.1 `AlarmNextTriggerDateTests` 핵심 시나리오

```
TestCase: 월요일 09:00 현재, 설정: [월·수·금] 08:00
  Given: 현재 = 2026-01-05 09:00 (월요일)
         알람 = hour:8, minute:0, weekly([.monday, .wednesday, .friday])
  When:  alarm.nextTriggerDate(from: 현재)
  Then:  반환값 = 2026-01-07 08:00 (수요일)

TestCase: 금요일 23:59 현재, 설정: [토·일] 00:30
  Given: 현재 = 2026-01-09 23:59 (금요일)
         알람 = hour:0, minute:30, weekly([.saturday, .sunday])
  When:  alarm.nextTriggerDate(from: 현재)
  Then:  반환값 = 2026-01-10 00:30 (토요일)

TestCase: skippedDate가 다음 월요일인 상태, 설정: [월]
  Given: 현재 = 2026-01-05 06:00 (월요일)
         알람 = hour:8, minute:0, weekly([.monday])
         skippedDate = 2026-01-12 08:00 (다음주 월요일)
  When:  alarm.nextTriggerDate(from: 현재)
  Then:  반환값 = 2026-01-12 이후 월요일 (= 2026-01-19 08:00)
         → skippedDate와 같은 날이므로 스킵, 그다음 주 반환
```

### 5.2 `AlarmStoreCRUDTests` 핵심 시나리오

```swift
// 의존성 주입 패턴
func makeSUT() -> (AlarmStore, MockLocalNotificationService, MockAlarmKitService) {
    let notif = MockLocalNotificationService()
    let alarmKit = MockAlarmKitService()
    let store = AlarmStore(
        localNotificationService: notif,
        alarmKitService: alarmKit
    )
    return (store, notif, alarmKit)
}

// CRUD 테스트 예시
func test_createAlarm_addsToList() async {
    let (store, _, _) = makeSUT()
    await store.createAlarm(hour: 8, minute: 0, title: "Test", ...)
    let alarms = await store.alarms
    XCTAssertEqual(alarms.count, 1)
    XCTAssertEqual(alarms[0].hour, 8)
}
```

### 5.3 `BugE3_NotificationLimitTests` (64개 한도)

```swift
func test_threeLocalAlarms_exceed64NotificationLimit() async throws {
    let center = MockUNUserNotificationCenter()
    let service = LocalNotificationService(center: center)

    // 3개 Local 알람 생성
    let alarms = (0..<3).map { i in
        makeAlarm(hour: 8 + i, minute: 0, mode: .local)
    }

    for alarm in alarms {
        try await service.scheduleAlarm(for: alarm)
    }

    // 총 등록 시도: 3 × (1 + 30) = 93
    XCTAssertEqual(center.addAttemptCount, 93)

    // iOS 실제 허용: 64개
    // 이 테스트는 현재 버그를 "문서화"하는 목적
    // 수정 후에는 center.addedRequests.count <= 64 검증으로 변경
    XCTAssertGreaterThan(center.addAttemptCount, 64,
        "현재 알려진 버그: 알람 3개 이상 시 iOS 64개 알림 한도 초과")
}
```

### 5.4 `AlarmLifecycleTests` (통합)

```swift
// once 알람 전체 생명주기
func test_onceAlarmLifecycle_disablesAfterCompletion() async {
    let (store, notif, _) = makeSUT()

    // 1. 생성
    await store.createAlarm(hour: 8, minute: 0, schedule: .once, mode: .local)
    var alarms = await store.alarms
    XCTAssertTrue(alarms[0].isEnabled)

    // 2. 알람 완료
    await store.handleAlarmCompleted(alarms[0])

    // 3. 비활성화 확인
    alarms = await store.alarms
    XCTAssertFalse(alarms[0].isEnabled)

    // 4. 알림 취소 확인
    XCTAssertGreaterThan(notif.cancelAlarmCallCount, 0)
}

// weekly 알람 완료 후 재예약
func test_weeklyAlarmLifecycle_reschedulesAfterCompletion() async {
    let (store, notif, _) = makeSUT()

    await store.createAlarm(hour: 8, minute: 0, schedule: .weekly([.monday]), mode: .local)
    let alarms = await store.alarms

    await store.handleAlarmCompleted(alarms[0])

    // 재예약 확인 (scheduleAlarm이 완료 후 다시 호출됨)
    XCTAssertGreaterThanOrEqual(notif.scheduleAlarmCallCount, 2)

    // 여전히 활성 상태
    let updatedAlarms = await store.alarms
    XCTAssertTrue(updatedAlarms[0].isEnabled)
}
```

### 5.5 `AlarmDetailViewModelTests` — AM/PM 경계값

```swift
func test_displayHour_conversion() {
    let vm = AlarmDetailViewModel(store: InMemoryAlarmStore())

    // 자정 (00:00)
    vm.isPM = false
    vm.displayHour = 12
    XCTAssertEqual(vm.computedHour, 0)

    // 정오 (12:00)
    vm.isPM = true
    vm.displayHour = 12
    XCTAssertEqual(vm.computedHour, 12)

    // 오후 1시 (13:00)
    vm.isPM = true
    vm.displayHour = 1
    XCTAssertEqual(vm.computedHour, 13)

    // 오전 1시 (01:00)
    vm.isPM = false
    vm.displayHour = 1
    XCTAssertEqual(vm.computedHour, 1)
}
```

---

## 6. 테스트 인프라 설정 요구사항

### 6.1 Xcode 프로젝트 설정

1. **BetterAlarmTests 타겟 추가**
   - 타겟 타입: Unit Testing Bundle
   - Host Application: BetterAlarm
   - Swift Language Version: Swift 6
   - `SWIFT_STRICT_CONCURRENCY = complete`

2. **BetterAlarmUITests 타겟 추가**
   - 타겟 타입: UI Testing Bundle
   - Host Application: BetterAlarm

3. **테스트 전용 빌드 구성**
   - `ENABLE_TESTING_SEARCH_PATHS = YES`
   - 테스트 타겟에서 `@testable import BetterAlarm` 사용

### 6.2 프로토콜 추가 요구사항 (테스트 전제조건)

테스트 코드 작성 전, 본 코드에 다음 변경이 선행되어야 한다:

| 변경 사항 | 파일 | 이유 |
|---------|------|------|
| `AlarmStoreProtocol` 정의 | `AlarmStore.swift` | ViewModel에 Fake 주입 |
| `AlarmStore`가 프로토콜 채택 | `AlarmStore.swift` | 위와 동일 |
| `LiveActivityManagerProtocol` 정의 | `LiveActivityManager.swift` | Mock 주입 |
| `LocalNotificationService` 에 `UNUserNotificationCenter` 주입 가능하도록 init 수정 | `LocalNotificationService.swift` | MockCenter 주입 |
| `AlarmStore` 생성자에 모든 의존성 주입 받도록 수정 | `AlarmStore.swift` | Mock 주입 가능 |

### 6.3 테스트 격리 원칙

- 각 테스트는 `setUp()` / `tearDown()` 에서 상태 초기화
- UserDefaults는 테스트용 Suite 사용: `UserDefaults(suiteName: "test-\(UUID())")`
- 실제 `UNUserNotificationCenter` 사용 금지 → MockCenter만 사용
- 실제 `AVAudioPlayer` 사용 금지 → MockAudioService 사용
- 날짜 고정: `Date(timeIntervalSince1970:)` 직접 주입

### 6.4 비동기 테스트 패턴

```swift
// actor 메서드 테스트
func test_asyncActorMethod() async throws {
    let store = makeStore()
    try await store.someActorMethod()
    let result = await store.someProperty
    XCTAssertEqual(result, expectedValue)
}

// MainActor ViewModel 테스트
@MainActor
func test_viewModelOnMainActor() async {
    let vm = AlarmListViewModel(store: InMemoryAlarmStore())
    await vm.loadAlarms()
    XCTAssertFalse(vm.isLoading)
}
```

---

## 7. 알려진 버그 — 테스트로 문서화할 항목

테스트를 **즉시 통과시키는 것이 목적이 아니라**, 현재 버그를 코드로 고정(pin)하여
수정 시 회귀를 방지하는 데 목적이 있다.

| 버그 ID | 설명 | 테스트 파일 | 상태 |
|--------|------|-----------|------|
| E1 | swipe kill 후 .once 알람 상태 불일치 | `BugE1_SwipeKillStateTests` | 버그 고정 |
| E2 | AlarmKit 다중 알람 두 번째 누락 | `BugE2_AlarmKitMultiAlarmTests` | 버그 고정 |
| E3 | 알림 64개 한도 초과 | `BugE3_NotificationLimitTests` | 버그 고정 |
| E4 | 울림 도중 종료 → once 재울림 | `BugE4_RingingKillRecoveryTests` | 버그 고정 |
| E5 | 시스템 시간 변경 감지 없음 | `BugE5_SystemClockChangeTests` | 버그 고정 |

> **버그 고정 테스트**: `XCTExpectFailure { ... }` 또는 명시적 주석으로 "현재 실패가 예상됨"을 표시.
> 버그 수정 후 해당 래퍼를 제거하면 테스트가 자동으로 회귀 방지 역할을 한다.

---

## 8. UI 테스트 시나리오 (XCUITest)

### 시나리오 1: 알람 생성 기본 흐름
```
Given: 앱 실행, 알람 목록 비어있음
When:  + 버튼 탭 → 시간 8:00 설정 → 저장
Then:  목록에 "08:00" 알람 1개 표시됨
```

### 시나리오 2: 주간 알람 필터링
```
Given: 월·수·금 알람, 화·목 알람 2개 존재
When:  주간 탭 → "월" 필터 선택
Then:  월요일 포함 알람만 표시됨
```

### 시나리오 3: 알람 삭제
```
Given: 알람 1개 존재
When:  스와이프 → 삭제
Then:  목록 비어있음 + 빈 상태 안내 표시
```

### 시나리오 4: 스위치 토글 (weekly)
```
Given: 주간 알람 1개 활성화
When:  스위치 off
Then:  "이번만 스킵" / "완전히 끄기" 다이얼로그 표시
```

---

## 9. CI/CD 통합 권고

```yaml
# 권고 GitHub Actions 단계
- name: Run Unit Tests
  run: |
    xcodebuild test \
      -scheme BetterAlarm \
      -destination 'platform=iOS Simulator,name=iPhone 16,OS=17.0' \
      -only-testing:BetterAlarmTests \
      -resultBundlePath TestResults.xcresult

- name: Run UI Tests (핵심만)
  run: |
    xcodebuild test \
      -scheme BetterAlarm \
      -destination 'platform=iOS Simulator,name=iPhone 16,OS=17.0' \
      -only-testing:BetterAlarmUITests/AlarmCreationFlowTests \
      -resultBundlePath UITestResults.xcresult
```

> AlarmKit (iOS 26+) 관련 테스트는 `#if os(iOS)` + `guard #available(iOS 26, *)` 가드로 조건부 실행.
> 시뮬레이터 OS 17 환경에서는 AlarmKit 테스트 자동 스킵.

---

## 10. 구현 순서 (권고)

```
Phase 1: 인프라 구성
  Step 1. AlarmStoreProtocol, LiveActivityManagerProtocol 추가
  Step 2. 의존성 주입 init 수정 (AlarmStore, LocalNotificationService)
  Step 3. Mock/Fake 클래스 작성 (Support/ 폴더)
  Step 4. AlarmFixtures.swift 작성 (테스트용 Alarm 팩토리)

Phase 2: 모델 단위 테스트
  Step 5. AlarmNextTriggerDateTests (가장 중요, 먼저 작성)
  Step 6. AlarmScheduleCodableTests
  Step 7. 나머지 모델 테스트

Phase 3: 서비스 단위 테스트
  Step 8. AlarmStoreCRUDTests
  Step 9. AlarmStoreSchedulingTests
  Step 10. LocalNotificationServiceTests
  Step 11. 나머지 서비스 테스트

Phase 4: 버그 고정 테스트 (심각 버그 5개)
  Step 12. BugE1~E5 테스트 파일 작성

Phase 5: ViewModel 테스트
  Step 13. AlarmDetailViewModelTests (AM/PM 변환 경계값 중요)
  Step 14. 나머지 ViewModel 테스트

Phase 6: 통합 테스트
  Step 15. AlarmLifecycleTests
  Step 16. SnoozeFlowTests, SkipFlowTests

Phase 7: UI 테스트
  Step 17. 핵심 4개 시나리오
```

---

## 부록 A: `AlarmFixtures.swift` 설계

```swift
// 테스트용 Alarm 객체를 빠르게 생성하는 팩토리
enum AlarmFixtures {
    static func onceAlarm(
        hour: Int = 8,
        minute: Int = 0,
        enabled: Bool = true,
        mode: AlarmMode = .local
    ) -> Alarm { ... }

    static func weeklyAlarm(
        days: Set<Weekday> = [.monday, .wednesday, .friday],
        hour: Int = 8,
        minute: Int = 0,
        enabled: Bool = true,
        mode: AlarmMode = .local
    ) -> Alarm { ... }

    static func specificDateAlarm(
        date: Date = Date().addingTimeInterval(3600),
        hour: Int = 8,
        minute: Int = 0
    ) -> Alarm { ... }

    // 날짜 고정 헬퍼
    static func date(
        year: Int = 2026,
        month: Int = 1,
        day: Int = 5,
        hour: Int = 9,
        minute: Int = 0
    ) -> Date { ... }
}
```

---

## 부록 B: 테스트 불가 영역 (Out of Scope)

| 영역 | 이유 | 대안 |
|------|------|------|
| 실제 AlarmKit 발화 | 시뮬레이터 미지원 | 실기기 수동 테스트 |
| 실제 볼륨 제어 (MPVolumeView) | 시뮬레이터 미지원 | VolumeService Mock |
| Live Activity 렌더링 | 시뮬레이터 제한적 | 실기기 수동 테스트 |
| 앱 강제 종료 후 OS 알림 발화 | 자동화 불가 | 수동 테스트 체크리스트 |
| AVAudioSession 하드웨어 | 시뮬레이터 미지원 | AudioService Mock |
| Dynamic Island UI | 실기기 필요 | 수동 테스트 |

---

*이 문서는 구현 시작 전 팀 검토 후 확정한다.*
*확정 후 각 Phase는 별도 하네스 파이프라인으로 진행한다.*
