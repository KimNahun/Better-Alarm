// ============================================================
// BugE20_ButtonLoadingStateTests.swift
// BetterAlarmTests · EdgeCases_Supplement · BugRegression
//
// 연계: feedback R9-3
// 현상: 알람 토글/삭제 버튼 탭 후 처리가 완료될 때까지 시각적 피드백(로딩)이 없어
//       사용자가 버튼을 여러 번 탭하거나 반응 없다고 오인함.
// 수정: AlarmListView에서 버튼 처리 중 로딩 스피너 + 즉각 햅틱 피드백 추가.
//       ViewModel 레이어에서는 isLoading 플래그가 loadAlarms 전 구간에 정확히 true이고
//       완료 후 반드시 false로 복원되는 계약을 보장해야 한다.
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class BugE20_ButtonLoadingStateTests: XCTestCase {

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

    // MARK: - E20 핵심 회귀: isLoading 상태 계약

    /// E20 회귀: 초기 상태에서 isLoading은 false다
    func test_bugE20_initialState_isLoadingFalse() {
        XCTAssertFalse(sut.isLoading,
                       "E20: ViewModel 초기 상태에서 isLoading은 false여야 한다")
    }

    /// E20 회귀: loadAlarms 완료 후 isLoading이 false로 복원된다
    func test_bugE20_loadAlarms_completesWithIsLoadingFalse() async {
        // MARK: When
        await sut.loadAlarms()

        // MARK: Then
        XCTAssertFalse(sut.isLoading,
                       "E20: loadAlarms 완료 후 isLoading이 반드시 false여야 한다")
    }

    /// E20 회귀: 알람이 있는 경우에도 loadAlarms 완료 후 isLoading = false
    func test_bugE20_loadAlarms_withAlarms_isLoadingFalse() async {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "A",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await store.createAlarm(hour: 9, minute: 0, title: "B",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)

        // MARK: When
        await sut.loadAlarms()

        // MARK: Then
        XCTAssertFalse(sut.isLoading,
                       "E20: 알람 로드 완료 후 isLoading이 false여야 한다")
        XCTAssertEqual(sut.alarms.count, 2)
    }

    /// E20 회귀: deleteAlarm 후 isLoading = false (deleteAlarm 내부 refreshState 후 정상 복원)
    func test_bugE20_deleteAlarm_doesNotLeaveLoadingStuck() async {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "삭제",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()
        let alarm = sut.alarms.first!

        // MARK: When
        await sut.deleteAlarm(alarm)

        // MARK: Then
        XCTAssertFalse(sut.isLoading,
                       "E20: deleteAlarm 완료 후 isLoading이 false여야 한다")
        XCTAssertTrue(sut.alarms.isEmpty)
    }

    /// E20 회귀: toggleAlarm 후 isLoading = false
    func test_bugE20_toggleAlarm_doesNotLeaveLoadingStuck() async {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "토글",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()
        let alarm = sut.alarms.first!

        // MARK: When
        await sut.toggleAlarm(alarm, enabled: false)

        // MARK: Then
        XCTAssertFalse(sut.isLoading,
                       "E20: toggleAlarm 완료 후 isLoading이 false여야 한다")
    }

    /// E20 회귀: loadAlarms 연속 2회 호출 후에도 isLoading = false (상태 누적 없음)
    func test_bugE20_loadAlarmsTwice_isLoadingFalse() async {
        // MARK: When
        await sut.loadAlarms()
        await sut.loadAlarms()

        // MARK: Then
        XCTAssertFalse(sut.isLoading,
                       "E20: loadAlarms 연속 호출 후에도 isLoading이 false여야 한다")
    }
}
