import Foundation

// MARK: - Weekday

/// 요일을 나타내는 enum. Calendar의 weekday component와 동일한 rawValue(1=일~7=토).
enum Weekday: Int, Codable, CaseIterable, Hashable, Sendable {
    case sunday    = 1
    case monday    = 2
    case tuesday   = 3
    case wednesday = 4
    case thursday  = 5
    case friday    = 6
    case saturday  = 7

    var shortName: String {
        switch self {
        case .sunday:    return "일"
        case .monday:    return "월"
        case .tuesday:   return "화"
        case .wednesday: return "수"
        case .thursday:  return "목"
        case .friday:    return "금"
        case .saturday:  return "토"
        }
    }

    /// AlarmKit이 사용하는 Locale.Weekday로 변환
    var localeWeekday: Locale.Weekday {
        switch self {
        case .sunday:    return .sunday
        case .monday:    return .monday
        case .tuesday:   return .tuesday
        case .wednesday: return .wednesday
        case .thursday:  return .thursday
        case .friday:    return .friday
        case .saturday:  return .saturday
        }
    }
}

// MARK: - AlarmSchedule

/// 알람 반복 스케줄을 정의하는 enum.
enum AlarmSchedule: Codable, Equatable, Sendable {
    /// 1회성 알람 (다음 가능한 시각에 1회 울림)
    case once
    /// 주간 반복 알람 (선택한 요일마다 반복)
    case weekly(Set<Weekday>)
    /// 특정 날짜에 1회 울리는 알람
    case specificDate(Date)

    // MARK: Codable 수동 구현 (enum with associated values)

    private enum CodingKeys: String, CodingKey {
        case type, weekdays, date
    }

    private enum TypeKey: String, Codable {
        case once, weekly, specificDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .once:
            try container.encode(TypeKey.once, forKey: .type)
        case .weekly(let days):
            try container.encode(TypeKey.weekly, forKey: .type)
            try container.encode(days, forKey: .weekdays)
        case .specificDate(let date):
            try container.encode(TypeKey.specificDate, forKey: .type)
            try container.encode(date, forKey: .date)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(TypeKey.self, forKey: .type)
        switch type {
        case .once:
            self = .once
        case .weekly:
            let days = try container.decode(Set<Weekday>.self, forKey: .weekdays)
            self = .weekly(days)
        case .specificDate:
            let date = try container.decode(Date.self, forKey: .date)
            self = .specificDate(date)
        }
    }
}
