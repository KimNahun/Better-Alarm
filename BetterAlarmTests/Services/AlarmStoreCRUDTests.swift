// ============================================================
// AlarmStoreCRUDTests.swift
// BetterAlarmTests · Services · Unit
//
// 테스트 대상  : AlarmStore CRUD + toggle
// 테스트 범주  : Unit (MockLocalNotificationService / MockAlarmKitService 주입)
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
        // 테스트 격리: 기존 UserDefaults 키 제거
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        sut = nil
        mockNotif = nil
        mockAlarmKit = nil
        try await super.tearDown()
    }

    // MARK: - createAlarm

    func test_createAlarm_addsToAlarmsList() async {
        // MARK: Given — 빈 store
        let initial = await sut.alarms
        XCTAssertTrue(initial.isEmpty)

        // MARK: When
        await sut.createAlarm(
            hour: 8, minute: 0, title: "아침",
            schedule: .once, alarmMode: .local, isSilentAlarm: false
        )

        // MARK: Then
        let alarms = await sut.alarms
        XCTAssertEqual(alarms.count, 1)
        XCTAssertEqual(alarms[0].hour, 8)
        XCTAssertEqual(alarms[0].title, "아침")
        XCTAssertTrue(alarms[0].isEnabled)
    }

    func test_createAlarm_localMode_callsScheduleOnce() async {
        // MARK: When
        await sut.createAlarm(
            hour: 8, minute: 0, title: "테스트",
            schedule: .once, alarmMode: .local, isSilentAlarm: false
        )

        // MARK: Then
        XCTAssertEqual(mockNotif.scheduleAlarmCallCount, 1,
                       "local 모드 알람 생성 시 scheduleAlarm이 1회 호출되어야 한다")
    }

    func test_createAlarm_eachHasUniqueID() async {
        // MARK: When
        await sut.createAlarm(hour: 8, minute: 0, title: "A",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await sut.createAlarm(hour: 9, minute: 0, title: "B",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)

        // MARK: Then
        let alarms = await sut.alarms
        XCTAssertEqual(alarms.count, 2)
        XCTAssertNotEqual(alarms[0].id, alarms[1].id, "각 알람은 고유 UUID를 가져야 한다")
    }

    func test_createAlarm_sortedByTime() async {
        // MARK: When — 역순 생성
        await sut.createAlarm(hour: 9, minute: 0, title: "B",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        await sut.createAlarm(hour: 7, minute: 0, title: "A",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)

        // MARK: Then — 시간 오름차순 정렬
        let alarms = await sut.alarms
        XCTAssertEqual(alarms[0].hour, 7, "이른 시각 알람이 먼저 정렬되어야 한다")
        XCTAssertEqual(alarms[1].hour, 9)
    }

    // MARK: - deleteAlarm

    func test_deleteAlarm_removesFromList() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "삭제됨",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.deleteAlarm(alarm)

        // MARK: Then
        let alarms = await sut.alarms
        XCTAssertTrue(alarms.isEmpty, "삭제 후 목록이 비어야 한다")
    }

    func test_deleteAlarm_callsCancelNotification() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "삭제됨",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.deleteAlarm(alarm)

        // MARK: Then
        XCTAssertFalse(mockNotif.cancelAlarmCalledWith.isEmpty,
                       "삭제 시 cancelAlarm이 호출되어야 한다")
        XCTAssertEqual(mockNotif.cancelAlarmCalledWith.last?.id, alarm.id)
    }

    func test_deleteAlarm_nonExistentID_doesNotCrash() async {
        // MARK: Given — 존재하지 않는 알람
        let phantom = AlarmFixtures.makeOnceAlarm()

        // MARK: When / Then (크래시 없음)
        await sut.deleteAlarm(phantom)
        let alarms = await sut.alarms
        XCTAssertTrue(alarms.isEmpty)
    }

    // MARK: - updateAlarm

    func test_updateAlarm_changesFields() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "원본",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.updateAlarm(
            alarm, hour: 9, minute: 30, title: "수정됨",
            schedule: .weekly([.monday]), soundName: "bell",
            alarmMode: .local, isSilentAlarm: false
        )

        // MARK: Then
        let updated = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.hour, 9)
        XCTAssertEqual(updated?.title, "수정됨")
        if case .weekly(let days) = updated?.schedule {
            XCTAssertEqual(days, [.monday])
        } else {
            XCTFail("weekly 스케줄로 변경되어야 한다")
        }
    }

    func test_updateAlarm_nonExistentID_isIgnored() async {
        // MARK: Given — 존재하지 않는 알람
        let phantom = AlarmFixtures.makeOnceAlarm()

        // MARK: When / Then (크래시 없음)
        await sut.updateAlarm(
            phantom, hour: 10, minute: 0, title: "유령",
            schedule: .once, soundName: "default",
            alarmMode: .local, isSilentAlarm: false
        )
        let alarms = await sut.alarms
        XCTAssertTrue(alarms.isEmpty, "존재하지 않는 알람 업데이트는 무시되어야 한다")
    }

    // MARK: - toggleAlarm

    func test_toggleAlarm_enabledToDisabled_cancelsSchedule() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "토글",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.toggleAlarm(alarm, enabled: false)

        // MARK: Then
        let updated = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertEqual(updated?.isEnabled, false)
        XCTAssertFalse(mockNotif.cancelAlarmCalledWith.isEmpty,
                       "비활성화 시 cancelAlarm이 호출되어야 한다")
    }

    func test_toggleAlarm_disabledToEnabled_reschedules() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "토글",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]
        await sut.toggleAlarm(alarm, enabled: false)
        mockNotif.reset()

        // MARK: When
        let disabledAlarm = await sut.alarms.first { $0.id == alarm.id }!
        await sut.toggleAlarm(disabledAlarm, enabled: true)

        // MARK: Then
        let updated = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertEqual(updated?.isEnabled, true)
        XCTAssertGreaterThan(mockNotif.scheduleAlarmCallCount, 0,
                             "활성화 시 scheduleAlarm이 호출되어야 한다")
    }

    func test_toggleAlarm_enableToTrue_clearsSkippedDate() async {
        // MARK: Given — skippedDate가 있는 알람
        await sut.createAlarm(hour: 8, minute: 0, title: "스킵",
                              schedule: .weekly([.monday]), alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]
        await sut.skipOnceAlarm(alarm)
        let skipped = await sut.alarms.first { $0.id == alarm.id }!
        XCTAssertNotNil(skipped.skippedDate)

        // MARK: When — 비활성화 후 재활성화
        await sut.toggleAlarm(skipped, enabled: false)
        let disabled = await sut.alarms.first { $0.id == alarm.id }!
        await sut.toggleAlarm(disabled, enabled: true)

        // MARK: Then — skippedDate 초기화
        let final = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNil(final?.skippedDate, "활성화 시 skippedDate가 초기화되어야 한다")
    }

    // MARK: - loadAlarms

    func test_loadAlarms_noSavedData_returnsEmpty() async {
        // MARK: Given — UserDefaults 없음
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")

        // MARK: When
        await sut.loadAlarms()

        // MARK: Then
        let alarms = await sut.alarms
        XCTAssertTrue(alarms.isEmpty, "저장된 데이터 없으면 빈 배열이어야 한다")
    }

    func test_loadAlarms_corruptedJSON_returnsEmpty() async {
        // MARK: Given — 손상된 JSON
        UserDefaults.standard.set(Data("corrupt".utf8), forKey: "savedAlarms_v2")
        defer { UserDefaults.standard.removeObject(forKey: "savedAlarms_v2") }

        // MARK: When
        await sut.loadAlarms()

        // MARK: Then
        let alarms = await sut.alarms
        XCTAssertTrue(alarms.isEmpty, "손상된 JSON이면 크래시 없이 빈 배열이어야 한다")
    }
}
