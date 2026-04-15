// ============================================================
// AlarmNextTriggerDateTests.swift
// BetterAlarmTests · Models · Unit
//
// 테스트 대상  : Alarm.nextTriggerDate(from:)
// 테스트 범주  : Unit
// ============================================================

import XCTest
@testable import BetterAlarm

final class AlarmNextTriggerDateTests: XCTestCase {

    // MARK: - .once ─ 미래 시각

    func test_onceAlarm_futureTime_returnsToday() {
        // MARK: Given — 현재 09:00, 알람 10:00
        let now = AlarmFixtures.fixedDate(hour: 9, minute: 0)
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 10, minute: 0)

        // MARK: When
        let result = alarm.nextTriggerDate(from: now)

        // MARK: Then
        let expected = AlarmFixtures.fixedDate(hour: 10, minute: 0)
        XCTAssertEqual(result, expected, "오늘 미래 시각이면 오늘 해당 시각을 반환해야 한다")
    }

    func test_onceAlarm_pastTime_returnsTomorrow() {
        // MARK: Given — 현재 10:00, 알람 08:00 (과거)
        let now = AlarmFixtures.fixedDate(hour: 10, minute: 0)
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 8, minute: 0)

        // MARK: When
        let result = alarm.nextTriggerDate(from: now)

        // MARK: Then
        let tomorrowAt8 = Calendar.current.date(
            byAdding: .day, value: 1,
            to: AlarmFixtures.fixedDate(hour: 8, minute: 0)
        )!
        XCTAssertEqual(result, tomorrowAt8, "오늘 과거 시각이면 내일 해당 시각을 반환해야 한다")
    }

    func test_onceAlarm_exactlyNow_returnsTomorrow() {
        // MARK: Given — 현재와 알람 시각이 동일 (경계값)
        let now = AlarmFixtures.fixedDate(hour: 8, minute: 0)
        let alarm = AlarmFixtures.makeOnceAlarm(hour: 8, minute: 0)

        // MARK: When
        let result = alarm.nextTriggerDate(from: now)

        // MARK: Then — alarmDate > date 조건에서 같으면 false이므로 내일
        let tomorrowAt8 = Calendar.current.date(
            byAdding: .day, value: 1,
            to: AlarmFixtures.fixedDate(hour: 8, minute: 0)
        )!
        XCTAssertEqual(result, tomorrowAt8, "현재 시각과 동일하면 내일을 반환해야 한다")
    }

    func test_onceAlarm_disabled_returnsNil() {
        // MARK: Given
        let alarm = AlarmFixtures.makeOnceAlarm(isEnabled: false)

        // MARK: When
        let result = alarm.nextTriggerDate(from: Date())

        // MARK: Then
        XCTAssertNil(result, "비활성 알람은 nil을 반환해야 한다")
    }

    func test_onceAlarm_withSkippedDateMatchingResult_skipsByOneDay() {
        // MARK: Given — 알람 08:00, 오늘이 skippedDate
        let now = AlarmFixtures.fixedDate(hour: 7, minute: 0)
        let tomorrowAt8 = AlarmFixtures.fixedDate(day: 6, hour: 8, minute: 0)  // 내일 08:00
        var alarm = AlarmFixtures.makeOnceAlarm(hour: 8, minute: 0)
        // skippedDate를 오늘 08:00로 설정
        alarm.skippedDate = AlarmFixtures.fixedDate(hour: 8, minute: 0)

        // MARK: When
        let result = alarm.nextTriggerDate(from: now)

        // MARK: Then — 오늘 08:00가 스킵이므로 내일 08:00 반환
        // NOTE: isDateInTomorrow는 실제 현재 날짜 기준이므로 사용 불가. 픽스처 날짜 기준으로 비교.
        XCTAssertNotNil(result, "스킵 후 다음 날짜가 있어야 한다")
        XCTAssertEqual(result, tomorrowAt8, "오늘이 스킵이면 tomorrowAt8(Jan6@08:00)를 반환해야 한다")
    }

    // MARK: - .weekly ─ 기본 케이스

    func test_weeklyAlarm_todayIsMatchingDay_futureTime_returnsToday() {
        // MARK: Given — 2026-01-05 (월요일) 09:00, 알람: 월요일 10:00
        let monday9am = AlarmFixtures.fixedDate(hour: 9, minute: 0)  // 2026-01-05 월요일
        let alarm = AlarmFixtures.makeWeeklyAlarm(weekdays: [.monday], hour: 10, minute: 0)

        // MARK: When
        let result = alarm.nextTriggerDate(from: monday9am)

        // MARK: Then
        let expected = AlarmFixtures.fixedDate(hour: 10, minute: 0)
        XCTAssertEqual(result, expected, "오늘이 해당 요일이고 미래이면 오늘을 반환해야 한다")
    }

    func test_weeklyAlarm_todayIsMatchingDay_pastTime_returnsNextWeek() {
        // MARK: Given — 2026-01-05 (월요일) 10:00, 알람: 월요일 08:00 (과거)
        let monday10am = AlarmFixtures.fixedDate(hour: 10, minute: 0)
        let alarm = AlarmFixtures.makeWeeklyAlarm(weekdays: [.monday], hour: 8, minute: 0)

        // MARK: When
        let result = alarm.nextTriggerDate(from: monday10am)

        // MARK: Then — 다음 주 월요일
        let nextMonday = Calendar.current.date(
            byAdding: .day, value: 7,
            to: AlarmFixtures.fixedDate(hour: 8, minute: 0)
        )!
        XCTAssertEqual(result, nextMonday, "오늘 해당 요일 과거이면 다음 주 같은 요일을 반환해야 한다")
    }

    func test_weeklyAlarm_multipleWeekdays_returnsNearestFuture() {
        // MARK: Given — 2026-01-06 (화요일) 09:00, 알람: 월·수·금
        var c = DateComponents(); c.year=2026; c.month=1; c.day=6; c.hour=9
        let tuesday9am = Calendar.current.date(from: c)!
        let alarm = AlarmFixtures.makeWeeklyAlarm(
            weekdays: [.monday, .wednesday, .friday], hour: 8, minute: 0
        )

        // MARK: When
        let result = alarm.nextTriggerDate(from: tuesday9am)

        // MARK: Then — 가장 가까운 수요일 08:00
        var wc = DateComponents(); wc.year=2026; wc.month=1; wc.day=7; wc.hour=8; wc.minute=0; wc.second=0
        let wednesday8am = Calendar.current.date(from: wc)!
        XCTAssertEqual(result, wednesday8am, "화요일에서 월·수·금 알람이면 수요일을 반환해야 한다")
    }

    func test_weeklyAlarm_saturdayApproaching_friday2359_returnsSaturday() {
        // MARK: Given — 2026-01-09 (금요일) 23:59
        var c = DateComponents(); c.year=2026; c.month=1; c.day=9; c.hour=23; c.minute=59
        let fri2359 = Calendar.current.date(from: c)!
        let alarm = AlarmFixtures.makeWeeklyAlarm(
            weekdays: [.saturday, .sunday], hour: 0, minute: 30
        )

        // MARK: When
        let result = alarm.nextTriggerDate(from: fri2359)

        // MARK: Then — 토요일 00:30
        var wc = DateComponents(); wc.year=2026; wc.month=1; wc.day=10; wc.hour=0; wc.minute=30; wc.second=0
        let sat0030 = Calendar.current.date(from: wc)!
        XCTAssertEqual(result, sat0030, "금요일 23:59에서 토·일 알람이면 다음날 토요일을 반환해야 한다")
    }

    func test_weeklyAlarm_emptyWeekdays_returnsNil() {
        // MARK: Given
        let alarm = AlarmFixtures.makeWeeklyAlarm(weekdays: [])

        // MARK: When
        let result = alarm.nextTriggerDate(from: Date())

        // MARK: Then
        XCTAssertNil(result, "요일 미선택 주간 알람은 nil을 반환해야 한다")
    }

    func test_weeklyAlarm_allDays_returnsToday() {
        // MARK: Given — 모든 요일, 오늘 미래 시각
        let now = AlarmFixtures.fixedDate(hour: 9, minute: 0)
        let alarm = AlarmFixtures.makeWeeklyAlarm(
            weekdays: Set(Weekday.allCases), hour: 10, minute: 0
        )

        // MARK: When
        let result = alarm.nextTriggerDate(from: now)

        // MARK: Then
        XCTAssertNotNil(result, "매일 알람이면 nil이 아니어야 한다")
        XCTAssertTrue(Calendar.current.isDate(result!, inSameDayAs: now),
                      "매일 알람에서 미래 시각이면 오늘을 반환해야 한다")
    }

    func test_weeklyAlarm_withSkippedDate_skipsAndReturnsNextOccurrence() {
        // MARK: Given — 2026-01-05 (월요일) 06:00, 알람: 월요일 08:00
        //               skippedDate = 2026-01-05 08:00 (오늘 08:00)
        let now = AlarmFixtures.fixedDate(hour: 6, minute: 0)
        var alarm = AlarmFixtures.makeWeeklyAlarm(weekdays: [.monday], hour: 8, minute: 0)
        alarm.skippedDate = AlarmFixtures.fixedDate(hour: 8, minute: 0)  // 오늘 08:00

        // MARK: When
        let result = alarm.nextTriggerDate(from: now)

        // MARK: Then — 다음 주 월요일 08:00
        var wc = DateComponents(); wc.year=2026; wc.month=1; wc.day=12; wc.hour=8; wc.minute=0; wc.second=0
        let nextMonday = Calendar.current.date(from: wc)!
        XCTAssertEqual(result, nextMonday, "스킵된 날짜와 같은 날이면 그 다음 같은 요일을 반환해야 한다")
    }

    // MARK: - .specificDate

    func test_specificDateAlarm_futureDate_returnsThatDate() {
        // MARK: Given
        let futureDate = Date().addingTimeInterval(3600)  // 1시간 후
        let alarm = AlarmFixtures.makeSpecificDateAlarm(date: futureDate)

        // MARK: When
        let result = alarm.nextTriggerDate(from: Date())

        // MARK: Then
        XCTAssertNotNil(result, "미래 특정일 알람은 nil이 아니어야 한다")
    }

    func test_specificDateAlarm_pastDate_returnsNil() {
        // MARK: Given
        let pastDate = Date().addingTimeInterval(-3600)  // 1시간 전
        let alarm = AlarmFixtures.makeSpecificDateAlarm(date: pastDate)

        // MARK: When
        let result = alarm.nextTriggerDate(from: Date())

        // MARK: Then
        XCTAssertNil(result, "과거 특정일 알람은 nil을 반환해야 한다")
    }
}
