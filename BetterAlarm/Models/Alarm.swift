import Foundation

// MARK: - Localized Date Formatting
// (旧 KoreanDateFormatters — 로케일 인지형으로 교체. 이름은 호환성 유지를 위해 typealias 제공.)

/// 로케일 인지형 날짜 포맷터. Locale.current를 자동 반영.
enum LocalizedDateFormatters {
    /// "오전 7:00" (ko) / "7:00 AM" (en) — Date.formatted 사용으로 로케일 자동 반영
    static func timeDisplayString(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    /// 날짜를 항상 절대 형식("M월 d일" / "May 1")으로 변환.
    /// "오늘" / "내일" 같은 상대 표현은 사용하지 않는다 — 위젯/Live Activity 사용자 피드백 반영.
    /// `setLocalizedDateFormatFromTemplate("Md")`로 로케일별 자연스러운 표현(ko: "5월 1일", en: "May 1")을 얻는다.
    static func relativeDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter.string(from: date)
    }
}

/// 하위 호환성 typealias — 기존 호출부 변경 최소화
typealias KoreanDateFormatters = LocalizedDateFormatters

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
    var snoozeDate: Date?

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
        isSilentAlarm: Bool = false,
        snoozeDate: Date? = nil
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
        self.snoozeDate = snoozeDate
    }

    // MARK: - Computed Properties

    /// 다음 알람 예정일에 건너뛰기 상태인지 여부
    var isSkippingNext: Bool {
        guard let skippedDate else { return false }
        return skippedDate > Date()
    }

    /// 스누즈 상태인지 여부
    var isSnoozed: Bool {
        guard let snoozeDate else { return false }
        return snoozeDate > Date()
    }

    /// 주간 반복 알람인지 여부
    var isWeeklyAlarm: Bool {
        if case .weekly = schedule { return true }
        return false
    }

    /// "오전 8:00" 형식의 시간 문자열
    var timeString: String {
        KoreanDateFormatters.timeDisplayString(hour: hour, minute: minute)
    }

    /// 제목이 없으면 로케일 인지형 "Alarm"/"알람"으로 대체
    var displayTitle: String {
        title.isEmpty ? String(localized: "common_alarm_default_title") : title
    }

    /// 건너뛰기 상태 표시 없이 반복 설명 문자열 반환 (로케일 인지형)
    var repeatDescriptionWithoutSkip: String {
        switch schedule {
        case .once:
            return String(localized: "repeat_once")
        case .weekly(let days):
            if days.count == 7 {
                return String(localized: "repeat_every_day")
            } else if days == Set([Weekday.saturday, .sunday]) {
                return String(localized: "repeat_weekend")
            } else if days == Set([Weekday.monday, .tuesday, .wednesday, .thursday, .friday]) {
                return String(localized: "repeat_weekdays")
            } else {
                let sorted = days.sorted { $0.rawValue < $1.rawValue }
                return sorted.map { $0.shortName }.joined(separator: ", ")
            }
        case .specificDate(let date):
            return date.formatted(.dateTime.month().day())
        }
    }

    // MARK: - Next Trigger Date

    /// 현재 시각(date) 기준으로 다음 알람 발생 시각을 계산한다.
    /// - Parameter date: 기준 시각 (기본값: 현재)
    /// - Returns: 다음 발생 Date. 해당 없으면 nil.
    func nextTriggerDate(from date: Date = Date()) -> Date? {
        guard isEnabled else { return nil }
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
