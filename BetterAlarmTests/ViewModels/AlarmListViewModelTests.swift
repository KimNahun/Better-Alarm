// ============================================================
// AlarmListViewModelTests.swift
// BetterAlarmTests · ViewModels · Unit
//
// 테스트 대상  : AlarmListViewModel (로드, 토글, 삭제, 토스트)
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class AlarmListViewModelTests: XCTestCase {

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

    // MARK: - loadAlarms

    func test_loadAlarms_populatesAlarmsList() async {
        // MARK: Given — store에 알람 추가
        await store.createAlarm(hour: 8, minute: 0, title: "A",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await store.createAlarm(hour: 9, minute: 0, title: "B",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)

        // MARK: When
        await sut.loadAlarms()

        // MARK: Then
        XCTAssertEqual(sut.alarms.count, 2)
    }

    func test_loadAlarms_empty_showsEmptyList() async {
        await sut.loadAlarms()
        XCTAssertTrue(sut.alarms.isEmpty)
    }

    // MARK: - deleteAlarm

    func test_deleteAlarm_removesFromViewModel() async {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "삭제",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()
        let alarm = sut.alarms[0]

        // MARK: When
        await sut.deleteAlarm(alarm)

        // MARK: Then
        XCTAssertTrue(sut.alarms.isEmpty, "삭제 후 ViewModel 목록에서 제거되어야 한다")
    }

    func test_deleteAlarm_showsToast() async throws {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "삭제",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()
        let alarm = sut.alarms[0]

        // MARK: When
        await sut.deleteAlarm(alarm)

        // MARK: Then — Task 완료 대기
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showToast, "삭제 후 토스트가 표시되어야 한다")
        XCTAssertFalse(sut.toastMessage.isEmpty)
    }

    // MARK: - requestToggle

    func test_requestToggle_weeklyAlarmOff_setsPendingDisableAlarm() {
        // MARK: Given
        let alarm = AlarmFixtures.makeWeeklyAlarm()

        // MARK: When
        sut.requestToggle(alarm, enabled: false)

        // MARK: Then
        XCTAssertNotNil(sut.pendingDisableAlarm,
                        "주간 알람 끄기 요청 시 확인 다이얼로그용 pendingDisableAlarm이 설정되어야 한다")
    }

    func test_requestToggle_onceAlarmOff_doesNotSetPending() async throws {
        // MARK: Given
        let alarm = AlarmFixtures.makeOnceAlarm()

        // MARK: When
        sut.requestToggle(alarm, enabled: false)

        // MARK: Then — 1회 알람은 확인 없이 즉시 비활성화
        XCTAssertNil(sut.pendingDisableAlarm, "1회 알람은 pendingDisableAlarm을 설정하지 않아야 한다")
    }

    func test_cancelDisable_clearsPendingAlarm() {
        // MARK: Given
        let alarm = AlarmFixtures.makeWeeklyAlarm()
        sut.requestToggle(alarm, enabled: false)
        XCTAssertNotNil(sut.pendingDisableAlarm)

        // MARK: When
        sut.cancelDisable()

        // MARK: Then
        XCTAssertNil(sut.pendingDisableAlarm)
    }

    // MARK: - 토스트 E6 회귀

    func test_showToastMessage_calledTwiceRapidly_secondMessageDisplayed() async throws {
        // MARK: When — 연속 호출
        sut.showToastMessage("첫 번째")
        sut.showToastMessage("두 번째")

        // MARK: Then — Task 완료 대기
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showToast, "두 번째 호출 후에도 토스트가 표시되어야 한다")
        XCTAssertEqual(sut.toastMessage, "두 번째", "두 번째 메시지가 표시되어야 한다")
    }

    func test_showToastMessage_sameMessageTwice_toastRefreshes() async throws {
        // MARK: When
        sut.showToastMessage("동일 메시지")
        try await Task.sleep(for: .milliseconds(50))
        sut.showToastMessage("동일 메시지")

        // MARK: Then
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showToast, "동일 메시지 재호출에도 토스트가 표시되어야 한다")
    }

    func test_dismissToast_hidesAndClearsMessage() async throws {
        // MARK: Given
        sut.showToastMessage("토스트")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showToast)

        // MARK: When
        sut.dismissToast()

        // MARK: Then
        XCTAssertFalse(sut.showToast)
        XCTAssertTrue(sut.toastMessage.isEmpty)
    }

    // MARK: - nextAlarmDisplayString

    func test_nextAlarmDisplayString_noAlarms_returnsNil() async {
        await sut.loadAlarms()
        XCTAssertNil(sut.nextAlarmDisplayString)
    }
}
