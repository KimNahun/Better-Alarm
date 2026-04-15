// ============================================================
// BugE10_WeeklySnoozeStateTests.swift
// BetterAlarmTests · EdgeCases_Supplement · BugRegression
//
// 연계: BUG_ANALYSIS_SUPPLEMENT.md E10
// 수정: AlarmStore.handleAlarmCompleted + .weekly → snoozeDate 초기화 추가
// ============================================================

import XCTest
@testable import BetterAlarm

final class BugE10_WeeklySnoozeStateTests: XCTestCase {

    private var sut: AlarmStore!
    private var mockNotif: MockLocalNotificationService!

    override func setUp() async throws {
        try await super.setUp()
        mockNotif = MockLocalNotificationService()
        sut = AlarmStore(localNotificationService: mockNotif)
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "savedAlarms_v2")
        sut = nil
        mockNotif = nil
        try await super.tearDown()
    }

    /// E10 핵심 회귀: 주간 알람 완료 후 snoozeDate가 nil이 되어야 한다
    func test_bugE10_weeklyAlarmCompletion_clearsSnoozeDate() async {
        // MARK: Given — 매일 반복 주간 알람 스누즈
        await sut.createAlarm(
            hour: 8, minute: 0, title: "매일 주간",
            schedule: .weekly(Set(Weekday.allCases)),
            alarmMode: .local, isSilentAlarm: false
        )
        let alarm = await sut.alarms[0]

        // 스누즈 설정
        await sut.snoozeAlarm(alarm, minutes: 5)
        let snoozed = await sut.alarms.first { $0.id == alarm.id }!
        XCTAssertNotNil(snoozed.snoozeDate, "전제: snoozeDate가 설정되어야 한다")
        XCTAssertTrue(snoozed.isSnoozed, "전제: isSnoozed가 true여야 한다")

        // MARK: When — 알람 완료 처리
        await sut.handleAlarmCompleted(snoozed)

        // MARK: Then — snoozeDate 초기화
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNil(completed?.snoozeDate,
                     "E10: 주간 알람 완료 후 snoozeDate가 nil이어야 한다")
        XCTAssertFalse(completed?.isSnoozed ?? true,
                       "E10: 완료 후 isSnoozed가 false여야 한다")
    }

    /// E10: 주간 알람 완료 후에도 isEnabled는 true여야 한다
    func test_bugE10_weeklyAlarmCompletion_remainsEnabled() async {
        // MARK: Given
        await sut.createAlarm(
            hour: 8, minute: 0, title: "주간",
            schedule: .weekly(Set(Weekday.allCases)),
            alarmMode: .local, isSilentAlarm: false
        )
        let alarm = await sut.alarms[0]
        await sut.snoozeAlarm(alarm, minutes: 5)
        let snoozed = await sut.alarms.first { $0.id == alarm.id }!

        // MARK: When
        await sut.handleAlarmCompleted(snoozed)

        // MARK: Then
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertEqual(completed?.isEnabled, true,
                       "주간 알람 완료 후 isEnabled는 true로 유지되어야 한다")
    }

    /// E10: 스누즈 없는 주간 알람 완료는 snoozeDate에 영향 없음
    func test_bugE10_weeklyAlarmCompletion_withoutSnooze_snoozeDateRemainsNil() async {
        // MARK: Given — 스누즈 없는 주간 알람
        await sut.createAlarm(
            hour: 8, minute: 0, title: "주간",
            schedule: .weekly(Set(Weekday.allCases)),
            alarmMode: .local, isSilentAlarm: false
        )
        let alarm = await sut.alarms[0]
        XCTAssertNil(alarm.snoozeDate)

        // MARK: When
        await sut.handleAlarmCompleted(alarm)

        // MARK: Then
        let completed = await sut.alarms.first { $0.id == alarm.id }
        XCTAssertNil(completed?.snoozeDate, "스누즈 없이 완료된 경우 snoozeDate는 nil 유지")
    }
}
