// ============================================================
// AlarmDetailViewModelTests.swift
// BetterAlarmTests · ViewModels · Unit
//
// 테스트 대상  : AlarmDetailViewModel (AM/PM 변환, save, scheduleType)
// ============================================================

import XCTest
@testable import BetterAlarm

@MainActor
final class AlarmDetailViewModelTests: XCTestCase {

    private var store: AlarmStore!
    private var mockNotif: MockLocalNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        store = AlarmStore(localNotificationService: mockNotif)
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        store = nil
        mockNotif = nil
        try await super.tearDown()
    }

    private func makeSUT(editingAlarm: Alarm? = nil) -> AlarmDetailViewModel {
        AlarmDetailViewModel(store: store, editingAlarm: editingAlarm)
    }

    // MARK: - AM/PM ↔ hour 변환

    func test_hour_noon_isPM_true_displayHour12() {
        let sut = makeSUT()
        sut.isPM = true
        sut.displayHour = 12

        XCTAssertEqual(sut.hour, 12, "오후 12시 = 12 (정오)")
    }

    func test_hour_midnight_isPM_false_displayHour12() {
        let sut = makeSUT()
        sut.isPM = false
        sut.displayHour = 12

        XCTAssertEqual(sut.hour, 0, "오전 12시 = 0 (자정)")
    }

    func test_hour_1pm_isPM_true_displayHour1() {
        let sut = makeSUT()
        sut.isPM = true
        sut.displayHour = 1

        XCTAssertEqual(sut.hour, 13, "오후 1시 = 13")
    }

    func test_hour_11am_isPM_false_displayHour11() {
        let sut = makeSUT()
        sut.isPM = false
        sut.displayHour = 11

        XCTAssertEqual(sut.hour, 11, "오전 11시 = 11")
    }

    func test_hour_11pm_isPM_true_displayHour11() {
        let sut = makeSUT()
        sut.isPM = true
        sut.displayHour = 11

        XCTAssertEqual(sut.hour, 23, "오후 11시 = 23")
    }

    func test_hour_existingAlarm_noon_initialState() {
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 12, minute: 30)
        let sut = makeSUT(editingAlarm: alarm)

        XCTAssertTrue(sut.isPM, "12시는 오후여야 한다")
        XCTAssertEqual(sut.displayHour, 12)
        XCTAssertEqual(sut.minute, 30)
    }

    func test_hour_existingAlarm_midnight_initialState() {
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 0, minute: 0)
        let sut = makeSUT(editingAlarm: alarm)

        XCTAssertFalse(sut.isPM, "0시는 오전이어야 한다")
        XCTAssertEqual(sut.displayHour, 12, "0시의 displayHour는 12여야 한다")
    }

    func test_hour_existingAlarm_7am_initialState() {
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 7, minute: 30)
        let sut = makeSUT(editingAlarm: alarm)

        XCTAssertFalse(sut.isPM)
        XCTAssertEqual(sut.displayHour, 7)
    }

    // MARK: - save() 새 알람

    func test_save_newOnceAlarm_callsCreateOnStore() async {
        let sut = makeSUT()
        sut.isPM = false
        sut.displayHour = 8
        sut.minute = 0
        sut.title = "새 알람"
        sut.scheduleType = .once

        await sut.save()

        let alarms = await store.alarms
        XCTAssertEqual(alarms.count, 1, "save 후 알람이 1개 추가되어야 한다")
        XCTAssertEqual(alarms[0].title, "새 알람")
    }

    func test_save_editingAlarm_updatesExisting() async {
        // MARK: Given — 기존 알람 생성
        await store.createAlarm(hour: 8, minute: 0, title: "원본",
                                schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let existing = await store.alarms[0]

        let sut = makeSUT(editingAlarm: existing)
        sut.title = "수정됨"
        sut.isPM = true
        sut.displayHour = 9  // 21:00

        await sut.save()

        // MARK: Then
        let alarms = await store.alarms
        XCTAssertEqual(alarms.count, 1, "업데이트는 새 알람을 추가하지 않아야 한다")
        XCTAssertEqual(alarms[0].title, "수정됨")
        XCTAssertEqual(alarms[0].hour, 21)
    }

    func test_save_weeklyWithEmptyWeekdays_doesNotSave() async {
        let sut = makeSUT()
        sut.scheduleType = .weekly
        sut.selectedWeekdays = []

        await sut.save()

        let alarms = await store.alarms
        XCTAssertTrue(alarms.isEmpty, "요일 미선택 주간 알람은 저장되지 않아야 한다")
    }

    // MARK: - scheduleType 기반 스케줄 분기

    func test_scheduleType_once_savesOnceSchedule() async {
        let sut = makeSUT()
        sut.scheduleType = .once

        await sut.save()

        let alarms = await store.alarms
        if case .once = alarms.first?.schedule {
            // 통과
        } else {
            XCTFail(".once 스케줄로 저장되어야 한다")
        }
    }

    func test_scheduleType_weekly_savesWeeklySchedule() async {
        let sut = makeSUT()
        sut.scheduleType = .weekly
        sut.selectedWeekdays = [.monday, .friday]

        await sut.save()

        let alarms = await store.alarms
        if case .weekly(let days) = alarms.first?.schedule {
            XCTAssertEqual(days, [.monday, .friday])
        } else {
            XCTFail(".weekly 스케줄로 저장되어야 한다")
        }
    }

    // MARK: - isEditing

    func test_isEditing_withExistingAlarm_returnsTrue() {
        let alarm = AlarmFixtures.makeOnceAlarm()
        let sut = makeSUT(editingAlarm: alarm)
        XCTAssertTrue(sut.isEditing)
    }

    func test_isEditing_newAlarm_returnsFalse() {
        let sut = makeSUT()
        XCTAssertFalse(sut.isEditing)
    }
}
