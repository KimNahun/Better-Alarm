// ============================================================
// WeeklyAlarmViewModelTests.swift
// BetterAlarmTests · ViewModels · Unit
//
// 테스트 대상  : WeeklyAlarmViewModel (필터링, 토스트 E18)
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class WeeklyAlarmViewModelTests: XCTestCase {

    private var store: AlarmStore!
    private var mockNotif: MockLocalNotificationService!
    private var sut: WeeklyAlarmViewModel!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        store = AlarmStore(localNotificationService: mockNotif)
        sut = WeeklyAlarmViewModel(store: store)
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        sut = nil
        store = nil
        mockNotif = nil
        try await super.tearDown()
    }

    // MARK: - filteredAlarms

    func test_filteredAlarms_noSelectedDay_returnsAll() async {
        // MARK: Given
        await store.createAlarm(hour: 7, minute: 0, title: "월수금",
                                schedule: .weekly([.monday, .wednesday, .friday]),
                                alarmMode: .local, isSilentAlarm: false)
        await store.createAlarm(hour: 8, minute: 0, title: "화목",
                                schedule: .weekly([.tuesday, .thursday]),
                                alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()

        // MARK: When
        sut.selectedDay = nil

        // MARK: Then
        XCTAssertEqual(sut.filteredAlarms.count, 2, "요일 미선택 시 전체 반환")
    }

    func test_filteredAlarms_selectedMonday_returnsOnlyMonday() async {
        // MARK: Given
        await store.createAlarm(hour: 7, minute: 0, title: "월수금",
                                schedule: .weekly([.monday, .wednesday, .friday]),
                                alarmMode: .local, isSilentAlarm: false)
        await store.createAlarm(hour: 8, minute: 0, title: "화목",
                                schedule: .weekly([.tuesday, .thursday]),
                                alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()

        // MARK: When
        sut.selectedDay = .monday

        // MARK: Then
        XCTAssertEqual(sut.filteredAlarms.count, 1)
        XCTAssertEqual(sut.filteredAlarms[0].title, "월수금")
    }

    func test_filteredAlarms_selectedDayWithNoAlarms_returnsEmpty() async {
        // MARK: Given
        await store.createAlarm(hour: 7, minute: 0, title: "월요일만",
                                schedule: .weekly([.monday]),
                                alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()

        // MARK: When
        sut.selectedDay = .sunday

        // MARK: Then
        XCTAssertTrue(sut.filteredAlarms.isEmpty, "선택 요일에 알람 없으면 빈 배열")
    }

    func test_filteredAlarms_onceAlarm_notIncluded() async {
        // MARK: Given — 1회 알람은 주간 목록에 미포함
        await store.createAlarm(hour: 8, minute: 0, title: "1회",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()

        // MARK: Then
        XCTAssertTrue(sut.filteredAlarms.isEmpty, "1회 알람은 주간 알람 목록에 포함되지 않아야 한다")
    }

    // MARK: - 토스트 E18 회귀

    func test_showToast_afterToggle_displayed() async throws {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "주간",
                                schedule: .weekly([.monday, .tuesday, .wednesday,
                                                    .thursday, .friday, .saturday, .sunday]),
                                alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()
        let alarm = sut.weeklyAlarms[0]

        // MARK: When
        await sut.toggleAlarm(alarm, enabled: false)

        // MARK: Then
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showToast, "토글 후 토스트가 표시되어야 한다")
    }

    func test_showToast_calledTwice_secondMessageShown() async throws {
        // MARK: Given — 두 번 연속 작업

        // 알람 2개 생성
        await store.createAlarm(hour: 7, minute: 0, title: "A",
                                schedule: .weekly([.monday, .tuesday, .wednesday,
                                                    .thursday, .friday, .saturday, .sunday]),
                                alarmMode: .local, isSilentAlarm: false)
        await store.createAlarm(hour: 8, minute: 0, title: "B",
                                schedule: .weekly([.monday, .tuesday, .wednesday,
                                                    .thursday, .friday, .saturday, .sunday]),
                                alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()

        let alarmA = sut.weeklyAlarms[0]
        let alarmB = sut.weeklyAlarms[1]

        // MARK: When — 연속 토글
        await sut.toggleAlarm(alarmA, enabled: false)
        await sut.toggleAlarm(alarmB, enabled: false)

        // MARK: Then
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertTrue(sut.showToast, "E18: 두 번째 토스트도 표시되어야 한다")
    }

    func test_dismissToast_hidesToast() async throws {
        // MARK: Given
        await store.createAlarm(hour: 8, minute: 0, title: "주간",
                                schedule: .weekly([.monday, .tuesday, .wednesday,
                                                    .thursday, .friday, .saturday, .sunday]),
                                alarmMode: .local, isSilentAlarm: false)
        await sut.loadAlarms()
        let alarm = sut.weeklyAlarms[0]
        await sut.deleteAlarm(alarm)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(sut.showToast)

        // MARK: When
        sut.dismissToast()

        // MARK: Then
        XCTAssertFalse(sut.showToast)
        XCTAssertTrue(sut.toastMessage.isEmpty)
    }
}
