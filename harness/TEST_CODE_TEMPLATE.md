# BetterAlarm — 테스트 코드 양식 (Template)

> **목적**: 방대한 테스트 코드를 일관된 품질로 작성하기 위한 완전한 양식.
> **이 파일을 복사해서 새 테스트 파일의 뼈대로 사용한다.**
> **규칙**: 양식에서 벗어나려면 주석으로 이유를 명시한다.
> **기준일**: 2026-04-15
> **연계 문서**: `TEST_HARNESS.md`, `BUG_ANALYSIS_SUPPLEMENT.md`

---

## 0. 전제 조건 체크리스트

테스트 파일 작성 전, 아래가 모두 준비되었는지 확인한다:

- [ ] `BetterAlarmTests` 타깃에 파일 추가됨
- [ ] `@testable import BetterAlarm` 확인
- [ ] SUT(테스트 대상)의 프로토콜 또는 직접 타입 접근 가능
- [ ] 필요한 Mock/Fake가 `Support/Mocks/` 또는 `Support/Fakes/`에 존재
- [ ] 테스트 고립 보장: 각 테스트가 공유 상태를 오염시키지 않음

---

## 1. 파일 명명 규칙

```
[테스트_대상][범주]Tests.swift

예:
  AlarmNextTriggerDateTests.swift     ← Alarm 모델, 특정 함수
  AlarmStoreCRUDTests.swift           ← AlarmStore, CRUD 범주
  AlarmDetailViewModelSaveTests.swift ← ViewModel, 저장 기능
  BugE6_ToastRaceConditionTests.swift ← 버그 회귀 테스트
```

**버그 회귀 테스트**는 반드시 `Bug[ID]_` 접두사를 붙인다.
ID는 `BUG_ANALYSIS_SUPPLEMENT.md`의 E 번호와 일치시킨다.

---

## 2. 파일 헤더 양식

모든 테스트 파일 최상단에 아래를 붙여넣고 값을 채운다:

```swift
// ============================================================
// [파일명].swift
// BetterAlarmTests
//
// 테스트 대상  : [SUT 클래스/구조체명]
// 테스트 범주  : [Unit | Integration | UI | BugRegression]
// 버그 연계    : [없음 | BUG_ANALYSIS_SUPPLEMENT.md E번호]
// 작성일       : YYYY-MM-DD
// ============================================================

import XCTest
@testable import BetterAlarm
// 필요한 경우 추가:
// import ActivityKit
// import UserNotifications
```

---

## 3. 테스트 클래스 선언 양식

### 3-A. 순수 모델 / 값 타입 테스트

```swift
final class AlarmNextTriggerDateTests: XCTestCase {

    // MARK: - SUT Factory
    // 고정 날짜와 알람 설정을 받아 SUT를 생성
    private func makeAlarm(
        hour: Int,
        minute: Int,
        schedule: AlarmSchedule,
        isEnabled: Bool = true,
        skippedDate: Date? = nil
    ) -> Alarm {
        var alarm = Alarm(
            id: UUID(),
            hour: hour,
            minute: minute,
            title: "Test",
            isEnabled: isEnabled,
            schedule: schedule,
            mode: .local,
            isSilentAlarm: false
        )
        alarm.skippedDate = skippedDate
        return alarm
    }
}
```

### 3-B. Actor 서비스 테스트 (`@MainActor` 없이)

```swift
final class AlarmStoreTests: XCTestCase {

    // MARK: - Properties
    private var sut: AlarmStore!
    private var mockNotif: MockLocalNotificationService!
    private var mockAlarmKit: MockAlarmKitService!

    // MARK: - Setup / Teardown
    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        mockAlarmKit = MockAlarmKitService()
        sut = AlarmStore(
            localNotificationService: mockNotif,
            alarmKitService: mockAlarmKit
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockNotif = nil
        mockAlarmKit = nil
        try await super.tearDown()
    }
}
```

### 3-C. @MainActor ViewModel 테스트

```swift
@MainActor
final class AlarmListViewModelTests: XCTestCase {

    // MARK: - Properties
    private var sut: AlarmListViewModel!
    private var mockStore: MockAlarmStore!

    // MARK: - Setup / Teardown
    override func setUp() async throws {
        try await super.setUp()
        mockStore = MockAlarmStore()
        sut = AlarmListViewModel(store: mockStore)
    }

    override func tearDown() async throws {
        sut = nil
        mockStore = nil
        try await super.tearDown()
    }
}
```

### 3-D. 통합 테스트 (실제 Actor 체인)

```swift
final class AlarmLifecycleTests: XCTestCase {

    // MARK: - SUT Factory
    // 실제 서비스 체인 구성, Mock은 외부 의존성(UNCenter, AVPlayer 등)만 교체
    private func makeSUT() async -> (
        store: AlarmStore,
        notif: MockLocalNotificationService,
        audio: MockAudioService
    ) {
        let notif = MockLocalNotificationService()
        let audio = MockAudioService()
        let store = AlarmStore(
            localNotificationService: notif,
            alarmKitService: MockAlarmKitService()
        )
        return (store, notif, audio)
    }
}
```

---

## 4. 테스트 메서드 명명 규칙

```
test_[조건/상태]_[실행]_[기댓값]()

예:
  test_onceAlarm_nextTriggerDate_returnsTodayWhenFuture()
  test_createAlarm_callsScheduleOnce()
  test_deleteAlarm_withAlarmKitMode_cancelsCalled()
  test_handleAlarmCompleted_weeklyAlarm_clearsSnoozeDate()

버그 회귀:
  test_bugE6_rapidToastCalls_secondMessageDisplayed()
  test_bugE11_settingsViewModel_iOS16_doesNotCrash()
```

**금지 패턴**:
```
❌ testCreateAlarm()       ← 조건/기댓값 없음
❌ test_alarm1()           ← 의미없는 번호
❌ test_should_work()      ← 모호한 기댓값
```

---

## 5. Given / When / Then 구조

모든 테스트 메서드 내부는 아래 구조를 따른다:

```swift
func test_weeklyAlarm_withSkippedDate_skipsToNextOccurrence() {
    // MARK: Given
    let monday = makeDateComponents(year: 2026, month: 1, day: 5, hour: 9, minute: 0)
    let currentDate = Calendar.current.date(from: monday)!
    let nextMonday = Calendar.current.date(byAdding: .day, value: 7, to: currentDate)!
    let alarm = makeAlarm(
        hour: 8,
        minute: 0,
        schedule: .weekly([.monday]),
        skippedDate: nextMonday
    )

    // MARK: When
    let result = alarm.nextTriggerDate(from: currentDate)

    // MARK: Then
    let expected = Calendar.current.date(byAdding: .day, value: 14, to: currentDate)!
    XCTAssertEqual(
        result?.timeIntervalSince1970,
        expected.timeIntervalSince1970,
        accuracy: 60,
        "skippedDate와 같은 날을 건너뛰고 그 다음 주 월요일을 반환해야 한다"
    )
}
```

**규칙**:
- 각 섹션을 `// MARK: Given`, `// MARK: When`, `// MARK: Then`으로 구분
- `// MARK: Then`의 첫 번째 줄이 핵심 assertion
- 추가 assertion은 핵심 assertion 아래에 배치
- XCTAssert 메시지는 한국어로 기댓값을 서술

---

## 6. 비동기(async) 테스트 양식

### 6-A. async throws 기본 패턴

```swift
func test_createAlarm_addsToAlarmsArray() async throws {
    // MARK: Given
    let (store, _, _) = await makeSUT()

    // MARK: When
    try await store.createAlarm(
        hour: 8, minute: 0, title: "Morning",
        schedule: .once, mode: .local, isSilentAlarm: false
    )

    // MARK: Then
    let alarms = await store.alarms
    XCTAssertEqual(alarms.count, 1)
    XCTAssertEqual(alarms.first?.hour, 8)
}
```

### 6-B. Actor 격리 검증 패턴

```swift
func test_alarmStore_actorIsolation_noDataRace() async {
    // MARK: Given
    let (store, _, _) = await makeSUT()

    // MARK: When — 동시에 여러 작업 실행
    await withTaskGroup(of: Void.self) { group in
        for i in 0..<10 {
            group.addTask {
                try? await store.createAlarm(
                    hour: i, minute: 0, title: "Alarm \(i)",
                    schedule: .once, mode: .local, isSilentAlarm: false
                )
            }
        }
    }

    // MARK: Then — 레이스 없이 모두 추가됨
    let alarms = await store.alarms
    XCTAssertEqual(alarms.count, 10, "Actor 직렬화로 모든 알람이 추가되어야 한다")
}
```

### 6-C. XCTestExpectation (콜백/Notification 기반)

```swift
func test_alarmShouldRing_notification_posted() async {
    // MARK: Given
    let expectation = expectation(forNotification: .alarmShouldRing, object: nil)
    let (store, _, _) = await makeSUT()

    // MARK: When
    let alarm = AlarmFixtures.makeOnceAlarm()
    await store.triggerAlarmForTesting(alarm)

    // MARK: Then
    await fulfillment(of: [expectation], timeout: 1.0)
}
```

### 6-D. 타임아웃이 있는 비동기 상태 대기

```swift
func test_toastMessage_appearsAfterDelete() async throws {
    // MARK: Given
    let vm = AlarmListViewModel(store: mockStore)
    let alarm = AlarmFixtures.makeOnceAlarm()
    await mockStore.inject(alarms: [alarm])
    await vm.loadAlarms()

    // MARK: When
    await vm.requestDelete(alarm)

    // MARK: Then — 비동기 상태 변경을 짧은 await으로 대기
    try await Task.sleep(for: .milliseconds(100))
    XCTAssertTrue(vm.showToast, "삭제 후 토스트가 표시되어야 한다")
    XCTAssertFalse(vm.toastMessage.isEmpty, "토스트 메시지가 비어있지 않아야 한다")
}
```

---

## 7. Mock 클래스 양식

`Support/Mocks/` 폴더에 배치. 각 Mock은 아래 구조를 따른다.

### 7-A. Actor 기반 서비스 Mock

```swift
// Support/Mocks/MockLocalNotificationService.swift

import XCTest
@testable import BetterAlarm

final class MockLocalNotificationService: LocalNotificationServiceProtocol {

    // MARK: - 호출 기록 (Spy)
    private(set) var scheduleAlarmCallCount = 0
    private(set) var scheduleAlarmCalledWith: [Alarm] = []
    private(set) var cancelAlarmCalledWith: [UUID] = []
    private(set) var scheduleSnoozeCalledWith: [(alarm: Alarm, minutes: Int)] = []
    private(set) var scheduleRepeatingAlertsCallCount = 0
    private(set) var backgroundReminderScheduled = false
    private(set) var backgroundReminderCancelled = false

    // MARK: - 동작 설정 (Stub)
    var shouldThrowOnSchedule = false
    var authorizationStatus: UNAuthorizationStatus = .authorized

    // MARK: - 프로토콜 구현
    func requestAuthorization() async throws -> Bool {
        return authorizationStatus == .authorized
    }

    func scheduleAlarm(for alarm: Alarm) async throws {
        scheduleAlarmCallCount += 1
        scheduleAlarmCalledWith.append(alarm)
        if shouldThrowOnSchedule {
            throw AlarmError.notAuthorized
        }
    }

    func cancelAlarm(for id: UUID) async {
        cancelAlarmCalledWith.append(id)
    }

    func scheduleSnooze(for alarm: Alarm, minutes: Int) async throws {
        scheduleSnoozeCalledWith.append((alarm, minutes))
        if shouldThrowOnSchedule {
            throw AlarmError.notAuthorized
        }
    }

    func scheduleRepeatingAlerts(for alarm: Alarm) async {
        scheduleRepeatingAlertsCallCount += 1
    }

    func scheduleBackgroundReminder(for alarm: Alarm) async {
        backgroundReminderScheduled = true
    }

    func cancelBackgroundReminder() async {
        backgroundReminderCancelled = true
    }

    func cancelAllAlarms() async {
        // no-op
    }

    // MARK: - 테스트 헬퍼
    func reset() {
        scheduleAlarmCallCount = 0
        scheduleAlarmCalledWith = []
        cancelAlarmCalledWith = []
        scheduleSnoozeCalledWith = []
        scheduleRepeatingAlertsCallCount = 0
        backgroundReminderScheduled = false
        backgroundReminderCancelled = false
    }
}
```

### 7-B. @MainActor 서비스 Mock

```swift
// Support/Mocks/MockVolumeService.swift

import XCTest
@testable import BetterAlarm

@MainActor
final class MockVolumeService: VolumeServiceProtocol {

    private(set) var prepareCallCount = 0
    private(set) var guardStartCount = 0
    private(set) var guardStopCount = 0
    private(set) var restoreCallCount = 0
    var savedVolume: Float = 0.5

    func prepareForAlarm() {
        prepareCallCount += 1
    }

    func startVolumeGuard() {
        guardStartCount += 1
    }

    func stopVolumeGuard() {
        guardStopCount += 1
    }

    func restoreVolume() {
        restoreCallCount += 1
    }
}
```

### 7-C. Fake (인메모리 대체 구현)

```swift
// Support/Fakes/InMemoryAlarmStore.swift
// UserDefaults 없이 동작하는 AlarmStore 대체
// AlarmStoreProtocol 채택

import XCTest
@testable import BetterAlarm

actor InMemoryAlarmStore: AlarmStoreProtocol {

    // MARK: - 내부 상태
    private(set) var alarms: [Alarm] = []

    // MARK: - 테스트 제어용 주입 메서드
    func inject(alarms: [Alarm]) {
        self.alarms = alarms
    }

    // MARK: - 프로토콜 구현 (실제 로직)
    func loadAlarms() {
        // 인메모리이므로 no-op (이미 inject로 설정됨)
    }

    func createAlarm(hour: Int, minute: Int, title: String,
                     schedule: AlarmSchedule, mode: AlarmMode,
                     isSilentAlarm: Bool) throws {
        let alarm = Alarm(
            id: UUID(), hour: hour, minute: minute,
            title: title, isEnabled: true,
            schedule: schedule, mode: mode,
            isSilentAlarm: isSilentAlarm
        )
        alarms.append(alarm)
    }

    func updateAlarm(_ alarm: Alarm) throws {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else {
            throw AlarmError.alarmNotFound
        }
        alarms[idx] = alarm
    }

    func deleteAlarm(id: UUID) {
        alarms.removeAll { $0.id == id }
    }

    func toggleAlarm(_ alarm: Alarm, enabled: Bool) throws {
        guard let idx = alarms.firstIndex(where: { $0.id == alarm.id }) else { return }
        alarms[idx].isEnabled = enabled
    }
}
```

---

## 8. 픽스처(Fixture) 팩토리 양식

`Support/Fixtures/AlarmFixtures.swift` — 테스트용 Alarm 객체 생성 팩토리

```swift
// Support/Fixtures/AlarmFixtures.swift

import Foundation
@testable import BetterAlarm

enum AlarmFixtures {

    // MARK: - 기본 알람

    static func makeOnceAlarm(
        hour: Int = 8,
        minute: Int = 0,
        title: String = "테스트 알람",
        isEnabled: Bool = true,
        mode: AlarmMode = .local
    ) -> Alarm {
        Alarm(
            id: UUID(),
            hour: hour, minute: minute,
            title: title, isEnabled: isEnabled,
            schedule: .once, mode: mode,
            isSilentAlarm: false
        )
    }

    static func makeWeeklyAlarm(
        weekdays: Set<Weekday> = [.monday, .wednesday, .friday],
        hour: Int = 7,
        minute: Int = 30,
        isEnabled: Bool = true
    ) -> Alarm {
        Alarm(
            id: UUID(),
            hour: hour, minute: minute,
            title: "주간 알람", isEnabled: isEnabled,
            schedule: .weekly(weekdays), mode: .local,
            isSilentAlarm: false
        )
    }

    static func makeSpecificDateAlarm(
        date: Date,
        isEnabled: Bool = true
    ) -> Alarm {
        Alarm(
            id: UUID(),
            hour: Calendar.current.component(.hour, from: date),
            minute: Calendar.current.component(.minute, from: date),
            title: "특정일 알람", isEnabled: isEnabled,
            schedule: .specificDate(date), mode: .local,
            isSilentAlarm: false
        )
    }

    static func makeSilentAlarm() -> Alarm {
        Alarm(
            id: UUID(),
            hour: 6, minute: 0,
            title: "무음 알람", isEnabled: true,
            schedule: .once, mode: .local,
            isSilentAlarm: true
        )
    }

    // MARK: - 날짜 헬퍼

    /// 지정한 요일 + 시각에 해당하는 가장 가까운 Date 반환
    static func nextDate(weekday: Weekday, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.weekday = weekday.rawValue
        return Calendar.current.nextDate(
            after: Date(),
            matching: components,
            matchingPolicy: .nextTime
        )!
    }

    /// 고정 날짜 생성 (테스트 결정론성 보장)
    static func fixedDate(
        year: Int = 2026, month: Int = 1, day: Int = 5,
        hour: Int = 9, minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
```

---

## 9. 테스트 종류별 완전한 파일 템플릿

### 9-A. 모델 단위 테스트 (복사·사용)

```swift
// ============================================================
// Alarm[기능명]Tests.swift
// BetterAlarmTests · Unit
// ============================================================

import XCTest
@testable import BetterAlarm

final class AlarmNextTriggerDateTests: XCTestCase {

    // MARK: - .once 스케줄

    func test_onceAlarm_futureTime_returnsToday() {
        // MARK: Given
        let now = AlarmFixtures.fixedDate(hour: 9, minute: 0)   // 오늘 09:00
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 10, minute: 0) // 10:00

        // MARK: When
        let result = alarm.nextTriggerDate(from: now)

        // MARK: Then
        let expected = AlarmFixtures.fixedDate(hour: 10, minute: 0)
        XCTAssertEqual(result, expected, "오늘 미래 시각이면 오늘 해당 시각을 반환해야 한다")
    }

    func test_onceAlarm_pastTime_returnsTomorrow() {
        // MARK: Given
        let now = AlarmFixtures.fixedDate(hour: 10, minute: 0)  // 오늘 10:00
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 8, minute: 0) // 08:00 (과거)

        // MARK: When
        let result = alarm.nextTriggerDate(from: now)

        // MARK: Then
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1,
            to: AlarmFixtures.fixedDate(hour: 8, minute: 0)
        )!
        XCTAssertEqual(result, tomorrow, "오늘 과거 시각이면 내일 해당 시각을 반환해야 한다")
    }

    func test_onceAlarm_disabled_returnsNil() {
        // MARK: Given
        let alarm = AlarmFixtures.makeOnceAlarm(isEnabled: false)

        // MARK: When
        let result = alarm.nextTriggerDate(from: Date())

        // MARK: Then
        XCTAssertNil(result, "비활성 알람은 nil을 반환해야 한다")
    }

    // MARK: - .weekly 스케줄

    func test_weeklyAlarm_todayIsMatchingDay_futureTime_returnsToday() {
        // MARK: Given — 2026-01-05 (월요일) 09:00
        let monday9am = AlarmFixtures.fixedDate(year: 2026, month: 1, day: 5, hour: 9)
        let alarm = AlarmFixtures.makeWeeklyAlarm(weekdays: [.monday], hour: 10, minute: 0)

        // MARK: When
        let result = alarm.nextTriggerDate(from: monday9am)

        // MARK: Then
        let expected = AlarmFixtures.fixedDate(year: 2026, month: 1, day: 5, hour: 10)
        XCTAssertEqual(result, expected, "오늘이 해당 요일이고 미래 시각이면 오늘을 반환해야 한다")
    }

    func test_weeklyAlarm_emptyWeekdays_returnsNil() {
        // MARK: Given
        let alarm = AlarmFixtures.makeWeeklyAlarm(weekdays: [])

        // MARK: When
        let result = alarm.nextTriggerDate(from: Date())

        // MARK: Then
        XCTAssertNil(result, "요일 미선택 주간 알람은 nil을 반환해야 한다")
    }
}
```

---

### 9-B. Actor 서비스 단위 테스트 (복사·사용)

```swift
// ============================================================
// AlarmStoreCRUDTests.swift
// BetterAlarmTests · Unit (Actor)
// ============================================================

import XCTest
@testable import BetterAlarm

final class AlarmStoreCRUDTests: XCTestCase {

    // MARK: - Properties
    private var sut: AlarmStore!
    private var mockNotif: MockLocalNotificationService!
    private var mockAlarmKit: MockAlarmKitService!

    // MARK: - Setup / Teardown
    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        mockAlarmKit = MockAlarmKitService()
        sut = AlarmStore(
            localNotificationService: mockNotif,
            alarmKitService: mockAlarmKit
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockNotif = nil
        mockAlarmKit = nil
        try await super.tearDown()
    }

    // MARK: - createAlarm

    func test_createAlarm_addsAlarmToList() async throws {
        // MARK: Given (초기 비어있음)
        let initialCount = await sut.alarms.count
        XCTAssertEqual(initialCount, 0)

        // MARK: When
        try await sut.createAlarm(
            hour: 8, minute: 0, title: "테스트",
            schedule: .once, mode: .local, isSilentAlarm: false
        )

        // MARK: Then
        let alarms = await sut.alarms
        XCTAssertEqual(alarms.count, 1)
        XCTAssertEqual(alarms[0].hour, 8)
        XCTAssertEqual(alarms[0].isEnabled, true)
    }

    func test_createAlarm_callsScheduleOnce() async throws {
        // MARK: Given
        mockNotif.shouldThrowOnSchedule = false

        // MARK: When
        try await sut.createAlarm(
            hour: 8, minute: 0, title: "테스트",
            schedule: .once, mode: .local, isSilentAlarm: false
        )

        // MARK: Then
        XCTAssertEqual(
            mockNotif.scheduleAlarmCallCount, 1,
            "알람 생성 시 알림 예약이 정확히 1회 호출되어야 한다"
        )
    }

    // MARK: - deleteAlarm

    func test_deleteAlarm_removesFromList() async throws {
        // MARK: Given
        try await sut.createAlarm(
            hour: 8, minute: 0, title: "삭제될 알람",
            schedule: .once, mode: .local, isSilentAlarm: false
        )
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.deleteAlarm(id: alarm.id)

        // MARK: Then
        let alarms = await sut.alarms
        XCTAssertTrue(alarms.isEmpty, "삭제 후 목록이 비어야 한다")
    }

    func test_deleteAlarm_nonExistentID_doesNotCrash() async {
        // MARK: Given
        let nonExistentID = UUID()

        // MARK: When / Then (크래시 없음)
        await sut.deleteAlarm(id: nonExistentID)
        let alarms = await sut.alarms
        XCTAssertTrue(alarms.isEmpty)
    }

    // MARK: - loadAlarms

    func test_loadAlarms_withCorruptedData_returnsEmptyArray() async {
        // MARK: Given — UserDefaults에 손상된 JSON 주입
        let corruptData = "not-valid-json".data(using: .utf8)!
        UserDefaults.standard.set(corruptData, forKey: "saved_alarms")
        defer { UserDefaults.standard.removeObject(forKey: "saved_alarms") }

        // MARK: When
        await sut.loadAlarms()

        // MARK: Then
        let alarms = await sut.alarms
        XCTAssertTrue(alarms.isEmpty, "손상된 JSON 로드 시 빈 배열로 복구되어야 한다")
    }
}
```

---

### 9-C. @MainActor ViewModel 단위 테스트 (복사·사용)

```swift
// ============================================================
// AlarmDetailViewModelSaveTests.swift
// BetterAlarmTests · Unit (@MainActor ViewModel)
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class AlarmDetailViewModelSaveTests: XCTestCase {

    // MARK: - Properties
    private var sut: AlarmDetailViewModel!
    private var mockStore: MockAlarmStore!

    // MARK: - Setup / Teardown
    override func setUp() async throws {
        try await super.setUp()
        mockStore = MockAlarmStore()
        sut = AlarmDetailViewModel(store: mockStore, existingAlarm: nil)
    }

    override func tearDown() async throws {
        sut = nil
        mockStore = nil
        try await super.tearDown()
    }

    // MARK: - save() 신규 알람

    func test_save_newAlarm_callsCreateAlarm() async throws {
        // MARK: Given
        sut.hour = 8
        sut.minute = 0
        sut.title = "아침 알람"
        sut.scheduleType = .once

        // MARK: When
        await sut.save()

        // MARK: Then
        XCTAssertEqual(mockStore.createCallCount, 1, "저장 시 createAlarm이 1회 호출되어야 한다")
        XCTAssertEqual(mockStore.updateCallCount, 0, "신규 알람에서 update는 호출되지 않아야 한다")
    }

    func test_save_weeklyAlarm_emptyWeekdays_doesNotSave() async {
        // MARK: Given
        sut.scheduleType = .weekly
        sut.selectedWeekdays = []   // 빈 Set

        // MARK: When
        await sut.save()

        // MARK: Then
        XCTAssertEqual(mockStore.createCallCount, 0, "요일 미선택 주간 알람은 저장되지 않아야 한다")
        XCTAssertFalse(sut.errorMessage.isEmpty, "오류 메시지가 표시되어야 한다")
    }

    // MARK: - displayHour / AM·PM 변환

    func test_hour_noon_isPM_displayHour12() {
        // MARK: Given / When
        sut.hour = 12  // 정오

        // MARK: Then
        XCTAssertTrue(sut.isPM)
        XCTAssertEqual(sut.displayHour, 12)
    }

    func test_hour_midnight_isAM_displayHour12() {
        // MARK: Given / When
        sut.hour = 0  // 자정

        // MARK: Then
        XCTAssertFalse(sut.isPM)
        XCTAssertEqual(sut.displayHour, 12)
    }

    func test_hour_13pm_displayHour1() {
        // MARK: Given / When
        sut.hour = 13  // 오후 1시

        // MARK: Then
        XCTAssertTrue(sut.isPM)
        XCTAssertEqual(sut.displayHour, 1)
    }
}
```

---

### 9-D. 버그 회귀 테스트 (복사·사용)

```swift
// ============================================================
// BugE6_ToastRaceConditionTests.swift
// BetterAlarmTests · BugRegression
// 연계: BUG_ANALYSIS_SUPPLEMENT.md E6
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class BugE6_ToastRaceConditionTests: XCTestCase {

    private var sut: AlarmListViewModel!
    private var mockStore: MockAlarmStore!

    override func setUp() async throws {
        try await super.setUp()
        mockStore = MockAlarmStore()
        sut = AlarmListViewModel(store: mockStore)
    }

    override func tearDown() async throws {
        sut = nil
        mockStore = nil
        try await super.tearDown()
    }

    /// 회귀 테스트: 빠른 연속 삭제 시 두 번째 토스트 메시지도 표시되어야 한다
    func test_bugE6_rapidConsecutiveToasts_secondMessageShown() async throws {
        // MARK: Given
        let alarm1 = AlarmFixtures.makeOnceAlarm(title: "알람1")
        let alarm2 = AlarmFixtures.makeOnceAlarm(title: "알람2")
        await mockStore.inject(alarms: [alarm1, alarm2])
        await sut.loadAlarms()

        // MARK: When — 300ms 이내 연속 삭제
        await sut.requestDelete(alarm1)
        try await Task.sleep(for: .milliseconds(50))
        await sut.requestDelete(alarm2)

        // MARK: Then — 두 번째 토스트 메시지 표시 확인
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertTrue(sut.showToast, "두 번째 삭제 후에도 토스트가 표시되어야 한다")
        XCTAssertFalse(sut.toastMessage.isEmpty)
    }

    /// 회귀 테스트: 동일 메시지 연속 호출 시에도 토스트가 갱신되어야 한다
    func test_bugE6_sameMessageTwice_toastStillRefreshes() async throws {
        // MARK: Given
        let alarm = AlarmFixtures.makeOnceAlarm()
        await mockStore.inject(alarms: [alarm])
        await sut.loadAlarms()

        // MARK: When
        await sut.requestDelete(alarm)
        let firstMessage = sut.toastMessage

        // 동일 메시지로 다시 트리거 (WeeklyViewModel 버그 재현)
        await sut.showToastMessage(firstMessage)

        // MARK: Then
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showToast, "동일 메시지도 토스트가 다시 표시되어야 한다")
    }
}
```

---

### 9-E. 통합 테스트 (복사·사용)

```swift
// ============================================================
// AlarmLifecycleTests.swift
// BetterAlarmTests · Integration
// ============================================================

import XCTest
@testable import BetterAlarm

final class AlarmLifecycleTests: XCTestCase {

    // MARK: - SUT Factory
    private func makeSUT() -> (
        store: AlarmStore,
        notif: MockLocalNotificationService,
        alarmKit: MockAlarmKitService
    ) {
        let notif = MockLocalNotificationService()
        let alarmKit = MockAlarmKitService()
        let store = AlarmStore(
            localNotificationService: notif,
            alarmKitService: alarmKit
        )
        return (store, notif, alarmKit)
    }

    // MARK: - 1회성 알람 전체 생명주기

    func test_onceAlarmLifecycle_createdRingsThenDisables() async throws {
        // MARK: Given
        let (store, notif, _) = makeSUT()

        // MARK: When — 생성
        try await store.createAlarm(
            hour: 8, minute: 0, title: "1회 알람",
            schedule: .once, mode: .local, isSilentAlarm: false
        )
        let alarm = await store.alarms[0]
        XCTAssertTrue(alarm.isEnabled)
        XCTAssertEqual(notif.scheduleAlarmCallCount, 1)

        // MARK: When — 완료 처리
        await store.handleAlarmCompleted(alarmID: alarm.id)

        // MARK: Then — 비활성화됨
        let updatedAlarms = await store.alarms
        let updatedAlarm = try XCTUnwrap(updatedAlarms.first { $0.id == alarm.id })
        XCTAssertFalse(updatedAlarm.isEnabled, "1회 알람 완료 후 비활성화되어야 한다")
    }

    // MARK: - 스누즈 흐름

    func test_snoozeFlow_schedulesSnoozeNotification() async throws {
        // MARK: Given
        let (store, notif, _) = makeSUT()
        try await store.createAlarm(
            hour: 8, minute: 0, title: "스누즈 알람",
            schedule: .weekly([.monday]), mode: .local, isSilentAlarm: false
        )
        let alarm = await store.alarms[0]

        // MARK: When
        try await store.snoozeAlarm(alarm, minutes: 5)

        // MARK: Then
        XCTAssertEqual(notif.scheduleSnoozeCalledWith.count, 1)
        XCTAssertEqual(notif.scheduleSnoozeCalledWith[0].minutes, 5)

        let snoozedAlarm = try XCTUnwrap(await store.alarms.first { $0.id == alarm.id })
        XCTAssertNotNil(snoozedAlarm.snoozeDate, "스누즈 후 snoozeDate가 설정되어야 한다")
    }
}
```

---

## 10. 공통 XCT 어서션 가이드

| 상황 | 권장 어서션 | 비고 |
|------|-----------|------|
| 같음 (정수/문자열) | `XCTAssertEqual(a, b, "설명")` | |
| 같음 (날짜, 오차 허용) | `XCTAssertEqual(a.timeIntervalSince1970, b.timeIntervalSince1970, accuracy: 60)` | 초 단위 오차 |
| nil 여부 | `XCTAssertNil(x)` / `XCTAssertNotNil(x)` | |
| nil 아님 + 값 추출 | `let v = try XCTUnwrap(optional)` | |
| 참/거짓 | `XCTAssertTrue(cond)` / `XCTAssertFalse(cond)` | |
| 에러 throw | `XCTAssertThrowsError(try ...) { error in XCTAssertEqual(error, ...) }` | |
| 에러 미throw | `XCTAssertNoThrow(try ...)` | |
| 컬렉션 비어있음 | `XCTAssertTrue(arr.isEmpty)` | `XCTAssertEqual(arr.count, 0)` 보다 명확 |
| 컬렉션 개수 | `XCTAssertEqual(arr.count, n)` | |
| 크래시 없음 | 테스트 메서드 자체가 완료되면 통과 | 별도 assertion 불필요 |

---

## 11. 금지 패턴

```swift
// ❌ Thread.sleep — 결정론적이지 않음
Thread.sleep(forTimeInterval: 1.0)

// ✅ Task.sleep 사용
try await Task.sleep(for: .milliseconds(100))

// ❌ 테스트 간 공유 상태 (UserDefaults, 전역 변수)
UserDefaults.standard.set(...)  // 테스트 후 반드시 cleanup 필요

// ✅ 명시적 cleanup
addTeardownBlock {
    UserDefaults.standard.removeObject(forKey: "key")
}

// ❌ 프로덕션 코드에 테스트 분기
if ProcessInfo.processInfo.arguments.contains("TESTING") { ... }

// ✅ 프로토콜 추상화 + DI로 해결

// ❌ 불필요하게 큰 테스트 (여러 시나리오 한 메서드에)
func test_everything() async { ... }

// ✅ 시나리오 1개 = 메서드 1개
```

---

## 12. 코드 커버리지 측정 설정

Xcode > Scheme > Test > Options에서:
- **Gather coverage for**: `BetterAlarm` 타깃 선택
- **Coverage threshold**:
  - Model: 95%
  - Services: 85%
  - ViewModels: 80%

CI(`xcodebuild` 커맨드):
```bash
xcodebuild test \
  -scheme BetterAlarm \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -enableCodeCoverage YES \
  | xcpretty
```

---

## 13. 테스트 작성 순서 권장

새 기능 또는 버그 수정 시 아래 순서로 작성한다:

```
1. AlarmFixtures에 필요한 픽스처 추가 (없는 경우)
2. 해당 Mock/Fake가 없으면 Support/Mocks에 추가
3. Model 테스트 → Service 테스트 → ViewModel 테스트 → Integration 테스트
4. 버그 수정이면 BugE[번호]_ 파일에 회귀 테스트 추가
5. 모든 신규 테스트가 통과한 후 PR 생성
```

---

*이 양식에서 벗어나는 경우 반드시 해당 테스트 메서드 위에 `// NOTE: 양식 예외 이유 —` 주석을 달 것.*
