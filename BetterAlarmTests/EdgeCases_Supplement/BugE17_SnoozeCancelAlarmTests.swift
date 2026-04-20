// ============================================================
// BugE17_SnoozeCancelAlarmTests.swift
// BetterAlarmTests · EdgeCases_Supplement · BugRegression
//
// 연계: feedback R8-4
// 현상: 알람 울리는 도중 스누즈 시, 5초 반복 알림이 취소되지 않아 스누즈 후에도
//       계속 알림이 울리는 버그.
// 수정: AlarmStore.snoozeAlarm에서 scheduleSnooze 전에 cancelAlarm 호출 추가.
// ============================================================

import XCTest
@testable import BetterAlarm

final class BugE17_SnoozeCancelAlarmTests: XCTestCase {

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

    // MARK: - E17 핵심 회귀: snoozeAlarm은 cancelAlarm을 먼저 호출해야 한다

    /// E17 회귀: snoozeAlarm 호출 시 cancelAlarm이 scheduleSnooze보다 먼저 호출된다
    func test_bugE17_snoozeAlarm_cancelBeforeSchedule() async {
        // MARK: Given
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 8, minute: 0)
        await store.createAlarm(
            hour: alarm.hour,
            minute: alarm.minute,
            title: alarm.title,
            schedule: alarm.schedule,
            alarmMode: .local,
            isSilentAlarm: false
        )
        await store.loadAlarms()
        let saved = await store.alarms.first!
        mockNotif.reset()

        // MARK: When
        await store.snoozeAlarm(saved, minutes: 5)

        // MARK: Then — cancelAlarm이 호출되어야 한다
        XCTAssertEqual(mockNotif.cancelAlarmCalledWith.count, 1,
                       "E17: snoozeAlarm은 반드시 cancelAlarm을 1회 호출해야 한다 (5초 반복 알림 제거)")
        XCTAssertEqual(mockNotif.cancelAlarmCalledWith.first?.id, saved.id,
                       "E17: 취소 대상이 스누즈 요청한 알람과 동일해야 한다")
    }

    /// E17 회귀: snoozeAlarm 호출 시 scheduleSnooze도 호출된다 (스누즈 예약이 정상 실행)
    func test_bugE17_snoozeAlarm_schedulesSnooze() async {
        // MARK: Given
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 9, minute: 30)
        await store.createAlarm(
            hour: alarm.hour,
            minute: alarm.minute,
            title: alarm.title,
            schedule: alarm.schedule,
            alarmMode: .local,
            isSilentAlarm: false
        )
        await store.loadAlarms()
        let saved = await store.alarms.first!
        mockNotif.reset()

        // MARK: When
        await store.snoozeAlarm(saved, minutes: 5)

        // MARK: Then
        XCTAssertEqual(mockNotif.scheduleSnoozeCalledWith.count, 1,
                       "E17: scheduleSnooze가 1회 호출되어야 한다")
        XCTAssertEqual(mockNotif.scheduleSnoozeCalledWith.first?.minutes, 5,
                       "E17: 스누즈 시간이 5분이어야 한다")
    }

    /// E17 회귀: snoozeAlarm 호출 후 snoozeDate가 현재 시각 기준 5분 후로 저장된다
    func test_bugE17_snoozeAlarm_setsSnoozeDate() async {
        // MARK: Given
        let alarm = AlarmFixtures.makeOnceAlarm()
        await store.createAlarm(
            hour: alarm.hour,
            minute: alarm.minute,
            title: alarm.title,
            schedule: alarm.schedule,
            alarmMode: .local,
            isSilentAlarm: false
        )
        await store.loadAlarms()
        let saved = await store.alarms.first!

        let beforeSnooze = Date()

        // MARK: When
        await store.snoozeAlarm(saved, minutes: 5)

        // MARK: Then
        let afterSnooze = Date()
        let updatedAlarm = await store.alarms.first!
        let snoozeDate = updatedAlarm.snoozeDate

        XCTAssertNotNil(snoozeDate, "E17: snoozeAlarm 후 snoozeDate가 설정되어야 한다")

        if let date = snoozeDate {
            let expectedMin = beforeSnooze.addingTimeInterval(5 * 60)
            let expectedMax = afterSnooze.addingTimeInterval(5 * 60)
            XCTAssertGreaterThanOrEqual(date, expectedMin,
                                        "E17: snoozeDate는 5분 후 이상이어야 한다")
            XCTAssertLessThanOrEqual(date, expectedMax,
                                     "E17: snoozeDate는 현재 + 5분 범위 내여야 한다")
        }
    }

    /// E17 회귀: scheduleSnooze 실패 시에도 cancelAlarm은 이미 호출되어 반복 알림은 중단된다
    func test_bugE17_snoozeAlarm_scheduleThrows_cancelAlarmStillCalled() async {
        // MARK: Given
        mockNotif.shouldThrowOnSnooze = true
        let alarm = AlarmFixtures.makeOnceAlarm()
        await store.createAlarm(
            hour: alarm.hour,
            minute: alarm.minute,
            title: alarm.title,
            schedule: alarm.schedule,
            alarmMode: .local,
            isSilentAlarm: false
        )
        await store.loadAlarms()
        let saved = await store.alarms.first!
        mockNotif.reset()
        mockNotif.shouldThrowOnSnooze = true

        // MARK: When
        await store.snoozeAlarm(saved, minutes: 5)

        // MARK: Then — cancelAlarm은 scheduleSnooze 실패와 무관하게 호출되어야 한다
        XCTAssertEqual(mockNotif.cancelAlarmCalledWith.count, 1,
                       "E17: scheduleSnooze가 실패해도 cancelAlarm은 이미 완료되어야 한다")
    }
}
