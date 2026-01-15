import Foundation

// MARK: - Weekday

enum Weekday: Int, Codable, CaseIterable, Hashable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var shortName: String {
        switch self {
        case .sunday: return "일"
        case .monday: return "월"
        case .tuesday: return "화"
        case .wednesday: return "수"
        case .thursday: return "목"
        case .friday: return "금"
        case .saturday: return "토"
        }
    }

    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday: return .sunday
        case .monday: return .monday
        case .tuesday: return .tuesday
        case .wednesday: return .wednesday
        case .thursday: return .thursday
        case .friday: return .friday
        case .saturday: return .saturday
        }
    }

    init?(from localeWeekday: Locale.Weekday) {
        switch localeWeekday {
        case .sunday: self = .sunday
        case .monday: self = .monday
        case .tuesday: self = .tuesday
        case .wednesday: self = .wednesday
        case .thursday: self = .thursday
        case .friday: self = .friday
        case .saturday: self = .saturday
        @unknown default: return nil
        }
    }
    
}

// MARK: - Alarm Schedule

enum AlarmSchedule: Codable, Equatable {
    case once
    case weekly(Set<Weekday>)
    case specificDate(Date)
}

// MARK: - Alarm Model

struct Alarm: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var schedule: AlarmSchedule
    var isEnabled: Bool
    var soundName: String
    var createdAt: Date
    var skippedDate: Date?  // Date to skip (for "1번만 끄기" feature)

    init(
        id: UUID = UUID(),
        title: String = "",
        hour: Int = 8,
        minute: Int = 0,
        schedule: AlarmSchedule = .once,
        isEnabled: Bool = true,
        soundName: String = "default",
        createdAt: Date = Date(),
        skippedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.hour = hour
        self.minute = minute
        self.schedule = schedule
        self.isEnabled = isEnabled
        self.soundName = soundName
        self.createdAt = createdAt
        self.skippedDate = skippedDate
    }

    var isSkippingNext: Bool {
        guard let skippedDate = skippedDate else { return false }
        return skippedDate > Date()
    }

    var timeString: String {
        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%@ %d:%02d", period, displayHour, minute)
    }

    var displayTitle: String {
        return title.isEmpty ? "알람" : title
    }

    // Alarm.swift - repeatDescriptionWithoutSkip 프로퍼티 추가 (repeatDescription 아래에)

    var repeatDescriptionWithoutSkip: String {
        switch schedule {
        case .once:
            return "1회"
        case .weekly(let days):
            if days.count == 7 {
                return "매일"
            } else if days == Set([Weekday.saturday, .sunday]) {
                return "주말"
            } else if days == Set([Weekday.monday, .tuesday, .wednesday, .thursday, .friday]) {
                return "주중"
            } else {
                let sorted = days.sorted { $0.rawValue < $1.rawValue }
                return sorted.map { $0.shortName }.joined(separator: ", ")
            }
        case .specificDate(let date):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ko_KR")
            formatter.dateFormat = "M월 d일"
            return formatter.string(from: date)
        }
    }

    var isWeeklyAlarm: Bool {
        if case .weekly = schedule {
            return true
        }
        return false
    }

    func nextTriggerDate(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current

        // Helper function to check if a date should be skipped
        func shouldSkip(_ alarmDate: Date) -> Bool {
            guard let skippedDate = skippedDate else { return false }
            return calendar.isDate(alarmDate, inSameDayAs: skippedDate)
        }

        switch schedule {
        case .once:
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let alarmDate = calendar.date(from: components) else { return nil }

            var resultDate: Date?
            if alarmDate > date {
                resultDate = alarmDate
            } else {
                resultDate = calendar.date(byAdding: .day, value: 1, to: alarmDate)
            }

            // If this date should be skipped, find the next day
            if let result = resultDate, shouldSkip(result) {
                return calendar.date(byAdding: .day, value: 1, to: result)
            }
            return resultDate

        case .weekly(let days):
            guard !days.isEmpty else { return nil }

            let currentWeekday = calendar.component(.weekday, from: date)

            // Search up to 14 days to handle skip case
            for i in 0..<14 {
                let targetDay = (currentWeekday + i - 1) % 7 + 1
                if let weekday = Weekday(rawValue: targetDay), days.contains(weekday) {
                    guard let candidateDate = calendar.date(byAdding: .day, value: i, to: date) else { continue }

                    var components = calendar.dateComponents([.year, .month, .day], from: candidateDate)
                    components.hour = hour
                    components.minute = minute
                    components.second = 0

                    guard let alarmDate = calendar.date(from: components) else { continue }

                    if alarmDate > date && !shouldSkip(alarmDate) {
                        return alarmDate
                    }
                }
            }
            return nil

        case .specificDate(let specificDate):
            var components = calendar.dateComponents([.year, .month, .day], from: specificDate)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let alarmDate = calendar.date(from: components) else { return nil }

            // If skipped, no next occurrence for specific date
            if shouldSkip(alarmDate) {
                return nil
            }
            return alarmDate > date ? alarmDate : nil
        }
    }
}
