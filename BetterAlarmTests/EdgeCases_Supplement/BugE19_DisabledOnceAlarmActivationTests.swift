// ============================================================
// BugE19_DisabledOnceAlarmActivationTests.swift
// BetterAlarmTests · EdgeCases_Supplement · BugRegression
//
// 연계: feedback R9-1
// 현상: 꺼진 1회/특정날짜 알람을 탭해도 상세 화면으로 이동하거나 아무 반응이 없음.
// 수정: AlarmListView onTapGesture에서 isEnabled=false && .once/.specificDate 인 경우
//       requestToggle(alarm, enabled: true) 즉시 호출하도록 변경.
//       ViewModel 레이어에서는 requestToggle이 once/specificDate 알람에 대해
//       pendingDisableAlarm을 설정하지 않고 즉시 toggleAlarm을 실행해야 한다.
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class BugE19_DisabledOnceAlarmActivationTests: XCTestCase {

    private var store: AlarmStore!
    private var mockNotif: MockLocalNotificationService!
    private var sut: AlarmListViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        store = AlarmStore(localNotificationService: mockNotif)
        sut = AlarmListViewModel(store: store)
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        sut = nil
        store = nil
        mockNotif = nil
        try await super.tearDown()
    }

    // MARK: - E19 핵심 회귀: 꺼진 1회 알람 즉시 활성화

    /// E19 회귀: 꺼진 1회 알람에 requestToggle(enabled: true) 시 pendingDisableAlarm이 설정되지 않는다
    func test_bugE19_disabledOnceAlarm_requestToggleOn_noPendingDialog() async throws {
        // MARK: Given — 꺼진 1회 알람
        let alarm = AlarmFixtures.makeOnceAlarm(isEnabled: false)

        // MARK: When — 탭 동작: 즉시 활성화 요청
        sut.requestToggle(alarm, enabled: true)

        // MARK: Then — 확인 다이얼로그 없이 즉시 처리
        XCTAssertNil(sut.pendingDisableAlarm,
                     "E19: 꺼진 1회 알람 활성화 시 pendingDisableAlarm이 설정되면 안 된다")
    }

    /// E19 회귀: 꺼진 특정날짜 알람에 requestToggle(enabled: true) 시 pendingDisableAlarm이 설정되지 않는다
    func test_bugE19_disabledSpecificDateAlarm_requestToggleOn_noPendingDialog() {
        // MARK: Given — 꺼진 특정날짜 알람
        let futureDate = AlarmFixtures.minutesFromNow(60)
        let alarm = AlarmFixtures.makeSpecificDateAlarm(date: futureDate, isEnabled: false)

        // MARK: When
        sut.requestToggle(alarm, enabled: true)

        // MARK: Then
        XCTAssertNil(sut.pendingDisableAlarm,
                     "E19: 꺼진 특정날짜 알람 활성화 시 pendingDisableAlarm이 설정되면 안 된다")
    }

    /// E19 회귀: 꺼진 1회 알람 활성화 후 알람 목록에서 isEnabled = true 로 반영된다
    func test_bugE19_disabledOnceAlarm_requestToggleOn_alarmBecomesEnabled() async throws {
        // MARK: Given — store에 꺼진 1회 알람 저장
        await store.createAlarm(
            hour: 8, minute: 0, title: "꺼진 알람",
            schedule: .once, alarmMode: .local, isSilentAlarm: false
        )
        await store.loadAlarms()
        // 알람을 끔
        let alarm = await store.alarms.first!
        await store.toggleAlarm(alarm, enabled: false)
        await sut.loadAlarms()

        let disabledAlarm = sut.alarms.first!
        XCTAssertFalse(disabledAlarm.isEnabled, "전제: 알람이 꺼진 상태여야 한다")

        // MARK: When — 탭: 즉시 활성화
        sut.requestToggle(disabledAlarm, enabled: true)

        // Task 완료 대기
        try await Task.sleep(for: .milliseconds(100))
        await sut.loadAlarms()

        // MARK: Then
        let updatedAlarm = sut.alarms.first!
        XCTAssertTrue(updatedAlarm.isEnabled,
                      "E19: requestToggle(enabled: true) 후 알람이 활성화되어야 한다")
    }

    /// E19 회귀: 주간 알람 끄기는 여전히 pendingDisableAlarm 다이얼로그를 표시한다 (기존 동작 보호)
    func test_bugE19_weeklyAlarm_requestToggleOff_stillShowsDialog() {
        // MARK: Given
        let alarm = AlarmFixtures.makeWeeklyAlarm(isEnabled: true)

        // MARK: When
        sut.requestToggle(alarm, enabled: false)

        // MARK: Then — 주간 알람 끄기는 여전히 확인 필요
        XCTAssertNotNil(sut.pendingDisableAlarm,
                        "E19: 주간 알람 끄기는 pendingDisableAlarm 다이얼로그를 보여줘야 한다 (기존 동작 유지)")
    }

    /// E19 회귀: 활성화된 1회 알람 탭(켜진 → 끄기 시도)은 pendingDisableAlarm 없이 즉시 끈다
    func test_bugE19_enabledOnceAlarm_requestToggleOff_immediateDisable() {
        // MARK: Given — 켜진 1회 알람
        let alarm = AlarmFixtures.makeOnceAlarm(isEnabled: true)

        // MARK: When
        sut.requestToggle(alarm, enabled: false)

        // MARK: Then — 1회 알람 끄기도 확인 없이 즉시 처리
        XCTAssertNil(sut.pendingDisableAlarm,
                     "E19: 켜진 1회 알람 끄기도 pendingDisableAlarm 없이 즉시 처리해야 한다")
    }
}
