// ============================================================
// AlarmScheduleCodableTests.swift
// BetterAlarmTests · Models · Unit
//
// 테스트 대상  : AlarmSchedule Codable, Weekday
// 테스트 범주  : Unit
// ============================================================

import XCTest
@testable import BetterAlarm

final class AlarmScheduleCodableTests: XCTestCase {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - .once 왕복

    func test_once_encodeDecodeRoundtrip() throws {
        // MARK: Given
        let schedule = AlarmSchedule.once

        // MARK: When
        let data = try encoder.encode(schedule)
        let decoded = try decoder.decode(AlarmSchedule.self, from: data)

        // MARK: Then
        if case .once = decoded {
            // 통과
        } else {
            XCTFail(".once 인코딩/디코딩 후 동일 케이스여야 한다")
        }
    }

    // MARK: - .weekly 왕복

    func test_weekly_singleDay_encodeDecodeRoundtrip() throws {
        // MARK: Given
        let schedule = AlarmSchedule.weekly([.monday])

        // MARK: When
        let data = try encoder.encode(schedule)
        let decoded = try decoder.decode(AlarmSchedule.self, from: data)

        // MARK: Then
        if case .weekly(let days) = decoded {
            XCTAssertEqual(days, [.monday], "월요일만 포함되어야 한다")
        } else {
            XCTFail(".weekly 인코딩/디코딩 후 동일 케이스여야 한다")
        }
    }

    func test_weekly_multipleDays_encodeDecodeRoundtrip() throws {
        // MARK: Given
        let original: Set<Weekday> = [.monday, .wednesday, .friday, .saturday]
        let schedule = AlarmSchedule.weekly(original)

        // MARK: When
        let data = try encoder.encode(schedule)
        let decoded = try decoder.decode(AlarmSchedule.self, from: data)

        // MARK: Then
        if case .weekly(let days) = decoded {
            XCTAssertEqual(days, original, "인코딩/디코딩 후 요일 Set이 동일해야 한다")
        } else {
            XCTFail(".weekly 케이스여야 한다")
        }
    }

    func test_weekly_allDays_encodeDecodeRoundtrip() throws {
        // MARK: Given
        let all = Set(Weekday.allCases)
        let schedule = AlarmSchedule.weekly(all)

        // MARK: When
        let data = try encoder.encode(schedule)
        let decoded = try decoder.decode(AlarmSchedule.self, from: data)

        // MARK: Then
        if case .weekly(let days) = decoded {
            XCTAssertEqual(days, all, "7개 요일 전체가 동일해야 한다")
        } else {
            XCTFail(".weekly 케이스여야 한다")
        }
    }

    // MARK: - .specificDate 왕복

    func test_specificDate_encodeDecodeRoundtrip() throws {
        // MARK: Given
        let date = AlarmFixtures.fixedDate()
        let schedule = AlarmSchedule.specificDate(date)

        // MARK: When
        let data = try encoder.encode(schedule)
        let decoded = try decoder.decode(AlarmSchedule.self, from: data)

        // MARK: Then
        if case .specificDate(let d) = decoded {
            XCTAssertEqual(d.timeIntervalSince1970, date.timeIntervalSince1970,
                           accuracy: 1.0, "특정일 날짜가 동일해야 한다")
        } else {
            XCTFail(".specificDate 케이스여야 한다")
        }
    }

    // MARK: - 손상 데이터

    func test_corruptJSON_throwsDecodingError() {
        // MARK: Given
        let corrupt = Data("{ \"type\": \"unknown_value\" }".utf8)

        // MARK: When / Then
        XCTAssertThrowsError(
            try decoder.decode(AlarmSchedule.self, from: corrupt),
            "알 수 없는 type 값은 DecodingError를 throw해야 한다"
        )
    }

    func test_missingTypeField_throwsDecodingError() {
        // MARK: Given
        let missing = Data("{ \"days\": [] }".utf8)

        // MARK: When / Then
        XCTAssertThrowsError(
            try decoder.decode(AlarmSchedule.self, from: missing),
            "type 필드 없으면 DecodingError를 throw해야 한다"
        )
    }

    // MARK: - 전체 Alarm 모델 왕복

    func test_alarm_encodeDecodeRoundtrip() throws {
        // MARK: Given
        let alarm = AlarmFixtures.makeWeeklyAlarm(
            weekdays: [.tuesday, .thursday],
            hour: 7,
            minute: 30
        )

        // MARK: When
        let data = try encoder.encode(alarm)
        let decoded = try decoder.decode(Alarm.self, from: data)

        // MARK: Then
        XCTAssertEqual(decoded.id, alarm.id)
        XCTAssertEqual(decoded.hour, 7)
        XCTAssertEqual(decoded.minute, 30)
        if case .weekly(let days) = decoded.schedule {
            XCTAssertEqual(days, [.tuesday, .thursday])
        } else {
            XCTFail("주간 알람이어야 한다")
        }
    }
}

// MARK: - WeekdayTests

final class WeekdayTests: XCTestCase {

    func test_weekday_rawValues_1through7() {
        // Calendar.weekday 값과 일치 (일=1, 월=2, ..., 토=7)
        XCTAssertEqual(Weekday.sunday.rawValue, 1)
        XCTAssertEqual(Weekday.monday.rawValue, 2)
        XCTAssertEqual(Weekday.tuesday.rawValue, 3)
        XCTAssertEqual(Weekday.wednesday.rawValue, 4)
        XCTAssertEqual(Weekday.thursday.rawValue, 5)
        XCTAssertEqual(Weekday.friday.rawValue, 6)
        XCTAssertEqual(Weekday.saturday.rawValue, 7)
    }

    func test_weekday_allCases_count7() {
        XCTAssertEqual(Weekday.allCases.count, 7)
    }

    func test_weekday_shortNames_notEmpty() {
        for day in Weekday.allCases {
            XCTAssertFalse(day.shortName.isEmpty, "\(day) shortName이 비어있으면 안 된다")
        }
    }

    func test_weekday_initFromRawValue_success() {
        for rawValue in 1...7 {
            XCTAssertNotNil(Weekday(rawValue: rawValue), "rawValue \(rawValue)로 Weekday 생성 가능해야 한다")
        }
    }

    func test_weekday_initFromInvalidRawValue_returnsNil() {
        XCTAssertNil(Weekday(rawValue: 0))
        XCTAssertNil(Weekday(rawValue: 8))
    }
}
