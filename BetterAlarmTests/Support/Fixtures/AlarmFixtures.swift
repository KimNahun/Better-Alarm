// ============================================================
// AlarmFixtures.swift
// BetterAlarmTests · Support/Fixtures
//
// 테스트용 Alarm 객체 팩토리.
// 모든 테스트에서 공통으로 사용하는 픽스처를 이곳에서 생성한다.
// ============================================================

import Foundation
@testable import BetterAlarm

enum AlarmFixtures {

    // MARK: - 기본 알람 팩토리

    static func makeOnceAlarm(
        id: UUID = UUID(),
        hour: Int = 8,
        minute: Int = 0,
        title: String = "테스트 알람",
        isEnabled: Bool = true,
        mode: AlarmMode = .local,
        isSilentAlarm: Bool = false
    ) -> Alarm {
        Alarm(
            id: id,
            title: title,
            hour: hour,
            minute: minute,
            schedule: .once,
            isEnabled: isEnabled,
            soundName: "default",
            alarmMode: mode,
            isSilentAlarm: isSilentAlarm
        )
    }

    static func makeWeeklyAlarm(
        id: UUID = UUID(),
        weekdays: Set<Weekday> = [.monday, .wednesday, .friday],
        hour: Int = 7,
        minute: Int = 30,
        isEnabled: Bool = true
    ) -> Alarm {
        Alarm(
            id: id,
            title: "주간 알람",
            hour: hour,
            minute: minute,
            schedule: .weekly(weekdays),
            isEnabled: isEnabled,
            soundName: "default",
            alarmMode: .local,
            isSilentAlarm: false
        )
    }

    static func makeSpecificDateAlarm(
        id: UUID = UUID(),
        date: Date,
        isEnabled: Bool = true
    ) -> Alarm {
        let cal = Calendar.current
        return Alarm(
            id: id,
            title: "특정일 알람",
            hour: cal.component(.hour, from: date),
            minute: cal.component(.minute, from: date),
            schedule: .specificDate(date),
            isEnabled: isEnabled,
            soundName: "default",
            alarmMode: .local,
            isSilentAlarm: false
        )
    }

    static func makeSilentAlarm(id: UUID = UUID()) -> Alarm {
        Alarm(
            id: id,
            title: "무음 알람",
            hour: 6,
            minute: 0,
            schedule: .once,
            isEnabled: true,
            soundName: "default",
            alarmMode: .local,
            isSilentAlarm: true
        )
    }

    static func makeAlarmKitAlarm(
        id: UUID = UUID(),
        hour: Int = 9,
        minute: Int = 0
    ) -> Alarm {
        Alarm(
            id: id,
            title: "AlarmKit 알람",
            hour: hour,
            minute: minute,
            schedule: .once,
            isEnabled: true,
            soundName: "default",
            alarmMode: .alarmKit,
            isSilentAlarm: false
        )
    }

    // MARK: - 날짜 헬퍼

    /// 고정 날짜 생성 (결정론적 테스트용)
    static func fixedDate(
        year: Int = 2026,
        month: Int = 1,
        day: Int = 5,   // 월요일
        hour: Int = 9,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute; c.second = second
        return Calendar.current.date(from: c)!
    }

    /// 현재 시각 기준 N분 후 Date
    static func minutesFromNow(_ minutes: Int) -> Date {
        Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    /// 현재 시각 기준 N분 전 Date
    static func minutesAgo(_ minutes: Int) -> Date {
        Date().addingTimeInterval(-TimeInterval(minutes * 60))
    }
}
