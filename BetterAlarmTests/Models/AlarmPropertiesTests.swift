// ============================================================
// AlarmPropertiesTests.swift
// BetterAlarmTests · Models · Unit
//
// 테스트 대상  : Alarm computed properties
// ============================================================

import XCTest
@testable import BetterAlarm

final class AlarmPropertiesTests: XCTestCase {

    // MARK: - isSkippingNext

    func test_isSkippingNext_noSkippedDate_returnsFalse() {
        let alarm = AlarmFixtures.makeOnceAlarm()
        XCTAssertFalse(alarm.isSkippingNext)
    }

    func test_isSkippingNext_futureskippedDate_returnsTrue() {
        var alarm = AlarmFixtures.makeOnceAlarm()
        alarm.skippedDate = AlarmFixtures.minutesFromNow(60)
        XCTAssertTrue(alarm.isSkippingNext)
    }

    func test_isSkippingNext_pastSkippedDate_returnsFalse() {
        var alarm = AlarmFixtures.makeOnceAlarm()
        alarm.skippedDate = AlarmFixtures.minutesAgo(60)
        XCTAssertFalse(alarm.isSkippingNext)
    }

    // MARK: - isSnoozed

    func test_isSnoozed_noSnoozeDate_returnsFalse() {
        let alarm = AlarmFixtures.makeOnceAlarm()
        XCTAssertFalse(alarm.isSnoozed)
    }

    func test_isSnoozed_futureSnoozeDate_returnsTrue() {
        var alarm = AlarmFixtures.makeOnceAlarm()
        alarm.snoozeDate = AlarmFixtures.minutesFromNow(5)
        XCTAssertTrue(alarm.isSnoozed)
    }

    func test_isSnoozed_pastSnoozeDate_returnsFalse() {
        var alarm = AlarmFixtures.makeOnceAlarm()
        alarm.snoozeDate = AlarmFixtures.minutesAgo(5)
        XCTAssertFalse(alarm.isSnoozed)
    }

    // MARK: - isWeeklyAlarm

    func test_isWeeklyAlarm_once_returnsFalse() {
        let alarm = AlarmFixtures.makeOnceAlarm()
        XCTAssertFalse(alarm.isWeeklyAlarm)
    }

    func test_isWeeklyAlarm_weekly_returnsTrue() {
        let alarm = AlarmFixtures.makeWeeklyAlarm()
        XCTAssertTrue(alarm.isWeeklyAlarm)
    }

    func test_isWeeklyAlarm_specificDate_returnsFalse() {
        let alarm = AlarmFixtures.makeSpecificDateAlarm(date: AlarmFixtures.minutesFromNow(60))
        XCTAssertFalse(alarm.isWeeklyAlarm)
    }

    // MARK: - displayTitle

    func test_displayTitle_emptyTitle_returnsDefault() {
        let alarm = AlarmFixtures.makeOnceAlarm(title: "")
        XCTAssertEqual(alarm.displayTitle, "알람", "빈 제목은 '알람' 기본값을 반환해야 한다")
    }

    func test_displayTitle_whitespaceOnly_returnsWhitespace() {
        // title 트리밍 없음 — 현재 동작 문서화 테스트
        let alarm = AlarmFixtures.makeOnceAlarm(title: "   ")
        XCTAssertEqual(alarm.displayTitle, "   ", "공백 제목은 그대로 반환 (트리밍 없음 — 현재 동작)")
    }

    func test_displayTitle_nonEmpty_returnsTitle() {
        let alarm = AlarmFixtures.makeOnceAlarm(title: "기상 알람")
        XCTAssertEqual(alarm.displayTitle, "기상 알람")
    }

    // MARK: - timeString

    func test_timeString_noon_returnsKoreanFormat() {
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 12, minute: 0)
        XCTAssertEqual(alarm.timeString, "오후 12:00")
    }

    func test_timeString_midnight_returnsKoreanFormat() {
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 0, minute: 0)
        XCTAssertEqual(alarm.timeString, "오전 12:00")
    }

    func test_timeString_7_30am_returnsCorrectFormat() {
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 7, minute: 30)
        XCTAssertEqual(alarm.timeString, "오전 7:30")
    }

    func test_timeString_13pm_returnsCorrectFormat() {
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 13, minute: 5)
        XCTAssertEqual(alarm.timeString, "오후 1:05")
    }
}
