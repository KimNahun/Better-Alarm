import Foundation

// MARK: - Alarm Model

/// 알람 데이터 모델.
/// Swift 6 동시성: struct + Sendable 준수.
struct Alarm: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var title: String
    var hour: Int
    var minute: Int
    var schedule: AlarmSchedule
    var isEnabled: Bool
    var soundName: String
    var createdAt: Date
    var skippedDate: Date?
    var alarmMode: AlarmMode
    var isSilentAlarm: Bool

    init(
        id: UUID = UUID(),
        title: String = "",
        hour: Int = 8,
        minute: Int = 0,
        schedule: AlarmSchedule = .once,
        isEnabled: Bool = true,
        soundName: String = "default",
        createdAt: Date = Date(),
        skippedDate: Date? = nil,
        alarmMode: AlarmMode = .local,
        isSilentAlarm: Bool = false
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
        self.alarmMode = alarmMode
        self.isSilentAlarm = isSilentAlarm
    }

    // MARK: - Computed Properties

    /// 다음 알람 예정일에 건너뛰기 상태인지 여부
    var isSkippingNext: Bool {
        guard let skippedDate else { return false }
        return skippedDate > Date()
    }

    /// 주간 반복 알람인지 여부
    var isWeeklyAlarm: Bool {
        if case .weekly = schedule { return true }
        return false
    }

    /// "오전 8:00" 형식의 시간 문자열
    var timeString: String {
        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%@ %d:%02d", period, displayHour, minute)
    }

    /// 제목이 없으면 "알람"으로 대체
    var displayTitle: String {
        title.isEmpty ? "알람" : title
    }

    /// 건너뛰기 상태 표시 없이 반복 설명 문자열 반환
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

    // MARK: - Next Trigger Date

    /// 현재 시각(date) 기준으로 다음 알람 발생 시각을 계산한다.
    /// - Parameter date: 기준 시각 (기본값: 현재)
    /// - Returns: 다음 발생 Date. 해당 없으면 nil.
    func nextTriggerDate(from date: Date = Date()) -> Date? {
        let calendar = Calendar.current

        func shouldSkip(_ alarmDate: Date) -> Bool {
            guard let skippedDate else { return false }
            return calendar.isDate(alarmDate, inSameDayAs: skippedDate)
        }

        switch schedule {
        case .once:
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute
            components.second = 0

            guard let alarmDate = calendar.date(from: components) else { return nil }

            let resultDate: Date?
            if alarmDate > date {
                resultDate = alarmDate
            } else {
                resultDate = calendar.date(byAdding: .day, value: 1, to: alarmDate)
            }

            if let result = resultDate, shouldSkip(result) {
                return calendar.date(byAdding: .day, value: 1, to: result)
            }
            return resultDate

        case .weekly(let days):
            guard !days.isEmpty else { return nil }

            let currentWeekday = calendar.component(.weekday, from: date)

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

            if shouldSkip(alarmDate) { return nil }
            return alarmDate > date ? alarmDate : nil
        }
    }
}
