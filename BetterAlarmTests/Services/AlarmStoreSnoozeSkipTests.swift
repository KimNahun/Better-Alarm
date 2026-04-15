// ============================================================
// AlarmStoreSnoozeSkipTests.swift
// BetterAlarmTests · Services · Unit
//
// 테스트 대상  : AlarmStore snooze, skip, handleAlarmCompleted
// ============================================================

import XCTest
@testable import BetterAlarm

final class AlarmStoreSnoozeSkipTests: XCTestCase {

    private var sut: AlarmStore!
    private var mockNotif: MockLocalNotificationService!
    private var mockAlarmKit: MockAlarmKitService!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        mockAlarmKit = MockAlarmKitService()
        sut = AlarmStore(
            localNotificationService: mockNotif,
            alarmKitService: mockAlarmKit
        )
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        sut = nil
        mockNotif = nil
        mockAlarmKit = nil
        try await super.tearDown()
    }

    // MARK: - snoozeAlarm

    func test_snoozeAlarm_setsSnoozeDate() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "스누즈",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]
        let before = Date()

        // MARK: When
        await sut.snoozeAlarm(alarm, minutes: 5)

        // MARK: Then
        let snoozed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNotNil(snoozed?.snoozeDate, "스누즈 후 snoozeDate가 설정되어야 한다")
        let expected = before.addingTimeInterval(5 * 60)
        XCTAssertEqual(
            snoozed!.snoozeDate!.timeIntervalSince1970,
            expected.timeIntervalSince1970,
            accuracy: 2.0,
            "snoozeDate는 5분 후여야 한다"
        )
    }

    func test_snoozeAlarm_schedulesSnoozeNotification() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "스누즈",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.snoozeAlarm(alarm, minutes: 5)

        // MARK: Then
        XCTAssertEqual(mockNotif.scheduleSnoozeCalledWith.count, 1,
                       "스누즈 알림이 1회 등록되어야 한다")
        XCTAssertEqual(mockNotif.scheduleSnoozeCalledWith[0].minutes, 5)
    }

    func test_snoozeAlarm_cancelsExistingNotificationFirst() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "스누즈",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.snoozeAlarm(alarm, minutes: 5)

        // MARK: Then — cancelAlarm이 scheduleSnooze보다 먼저 호출됨
        XCTAssertFalse(mockNotif.cancelAlarmCalledWith.isEmpty,
                       "스누즈 전 기존 알림을 취소해야 한다")
    }

    // MARK: - skipOnceAlarm

    func test_skipOnceAlarm_setsSkippedDate() async {
        // MARK: Given — 미래 시각 알람
        await sut.createAlarm(hour: 23, minute: 59, title: "스킵",
                              schedule: .weekly([.monday, .tuesday, .wednesday,
                                                 .thursday, .friday, .saturday, .sunday]),
                              alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]
        XCTAssertNil(alarm.skippedDate)

        // MARK: When
        await sut.skipOnceAlarm(alarm)

        // MARK: Then
        let updated = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNotNil(updated?.skippedDate, "스킵 후 skippedDate가 설정되어야 한다")
    }

    func test_skipOnceAlarm_disabledAlarm_ignored() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "비활성",
                              schedule: .weekly([.monday]), alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]
        await sut.toggleAlarm(alarm, enabled: false)
        let disabled = await sut.alarms.first { $0.id == alarm.id }!

        // MARK: When
        await sut.skipOnceAlarm(disabled)

        // MARK: Then
        let result = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNil(result?.skippedDate, "비활성 알람은 스킵되지 않아야 한다")
    }

    func test_clearSkipOnceAlarm_removesSkippedDate() async {
        // MARK: Given — 스킵 상태 알람
        await sut.createAlarm(hour: 23, minute: 59, title: "스킵 해제",
                              schedule: .weekly([.monday, .tuesday, .wednesday,
                                                 .thursday, .friday, .saturday, .sunday]),
                              alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]
        await sut.skipOnceAlarm(alarm)
        let skipped = await sut.alarms.first { $0.id == alarm.id }!
        XCTAssertNotNil(skipped.skippedDate)

        // MARK: When
        await sut.clearSkipOnceAlarm(skipped)

        // MARK: Then
        let cleared = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNil(cleared?.skippedDate, "스킵 해제 후 skippedDate가 nil이어야 한다")
    }

    // MARK: - handleAlarmCompleted

    func test_handleAlarmCompleted_onceAlarm_disables() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "완료",
                              schedule: .once, alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.handleAlarmCompleted(alarm)

        // MARK: Then
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertEqual(completed?.isEnabled, false, "1회 알람 완료 후 비활성화되어야 한다")
    }

    func test_handleAlarmCompleted_specificDateAlarm_disables() async {
        // MARK: Given
        let futureDate = AlarmFixtures.minutesFromNow(60)
        await sut.createAlarm(hour: Calendar.current.component(.hour, from: futureDate),
                              minute: Calendar.current.component(.minute, from: futureDate),
                              title: "특정일",
                              schedule: .specificDate(futureDate),
                              alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.handleAlarmCompleted(alarm)

        // MARK: Then
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertEqual(completed?.isEnabled, false, "특정일 알람 완료 후 비활성화되어야 한다")
    }

    func test_handleAlarmCompleted_weeklyAlarm_staysEnabled() async {
        // MARK: Given
        await sut.createAlarm(hour: 8, minute: 0, title: "주간",
                              schedule: .weekly([.monday]), alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]

        // MARK: When
        await sut.handleAlarmCompleted(alarm)

        // MARK: Then
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertEqual(completed?.isEnabled, true, "주간 알람 완료 후에도 활성 상태여야 한다")
    }

    /// E10 회귀: weekly 알람 완료 시 snoozeDate가 초기화되어야 한다
    func test_handleAlarmCompleted_weeklyAlarm_clearsSnoozeDate() async {
        // MARK: Given — 스누즈된 주간 알람
        await sut.createAlarm(hour: 8, minute: 0, title: "주간 스누즈",
                              schedule: .weekly([.monday, .tuesday, .wednesday,
                                                 .thursday, .friday, .saturday, .sunday]),
                              alarmMode: .local, isSilentAlarm: false)
        let alarm = await sut.alarms[0]
        await sut.snoozeAlarm(alarm, minutes: 5)
        let snoozed = await sut.alarms.first { $0.id == alarm.id }!
        XCTAssertNotNil(snoozed.snoozeDate, "전제 조건: snoozeDate가 설정되어야 한다")

        // MARK: When
        await sut.handleAlarmCompleted(snoozed)

        // MARK: Then
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNil(completed?.snoozeDate,
                     "E10: 주간 알람 완료 후 snoozeDate가 초기화되어야 한다 (스누즈 상태 오염 방지)")
    }

    func test_handleAlarmCompleted_nonExistentID_doesNotCrash() async {
        // MARK: Given
        let phantom = AlarmFixtures.makeOnceAlarm()

        // MARK: When / Then (크래시 없음)
        await sut.handleAlarmCompleted(phantom)
    }
}
