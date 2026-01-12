import WidgetKit
import SwiftUI

// MARK: - Widget Timeline Provider

struct AlarmTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlarmEntry {
        AlarmEntry(
            date: Date(),
            nextAlarmTime: "오전 7:00",
            nextAlarmDate: "내일",
            alarmTitle: "기상"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (AlarmEntry) -> Void) {
        let entry = loadAlarmEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmEntry>) -> Void) {
        let entry = loadAlarmEntry()

        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

        completion(timeline)
    }

    private func loadAlarmEntry() -> AlarmEntry {
        // Load alarms from shared UserDefaults (App Group required)
        let userDefaults = UserDefaults(suiteName: "group.com.betteralarm.shared") ?? UserDefaults.standard

        guard let data = userDefaults.data(forKey: "savedAlarms"),
              let alarms = try? JSONDecoder().decode([AlarmData].self, from: data),
              let nextAlarm = findNextAlarm(from: alarms) else {
            return AlarmEntry(
                date: Date(),
                nextAlarmTime: "알람 없음",
                nextAlarmDate: "",
                alarmTitle: ""
            )
        }

        return AlarmEntry(
            date: Date(),
            nextAlarmTime: nextAlarm.timeString,
            nextAlarmDate: nextAlarm.dateString,
            alarmTitle: nextAlarm.title
        )
    }

    private func findNextAlarm(from alarms: [AlarmData]) -> NextAlarmInfo? {
        let calendar = Calendar.current
        let now = Date()

        for alarm in alarms where alarm.isEnabled {
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = alarm.hour
            components.minute = alarm.minute

            guard let alarmDate = calendar.date(from: components) else { continue }

            let targetDate: Date
            if alarmDate > now {
                targetDate = alarmDate
            } else {
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: alarmDate) else { continue }
                targetDate = tomorrow
            }

            let hour = alarm.hour
            let period = hour < 12 ? "오전" : "오후"
            let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
            let timeString = String(format: "%@ %d:%02d", period, displayHour, alarm.minute)

            let dateString: String
            if calendar.isDateInToday(targetDate) {
                dateString = "오늘"
            } else if calendar.isDateInTomorrow(targetDate) {
                dateString = "내일"
            } else {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "ko_KR")
                formatter.dateFormat = "M월 d일 (E)"
                dateString = formatter.string(from: targetDate)
            }

            return NextAlarmInfo(
                timeString: timeString,
                dateString: dateString,
                title: alarm.title.isEmpty ? "알람" : alarm.title
            )
        }

        return nil
    }
}

// MARK: - Supporting Types

struct AlarmData: Codable {
    let id: String
    let title: String
    let hour: Int
    let minute: Int
    let isEnabled: Bool
}

struct NextAlarmInfo {
    let timeString: String
    let dateString: String
    let title: String
}

// MARK: - Timeline Entry

struct AlarmEntry: TimelineEntry {
    let date: Date
    let nextAlarmTime: String
    let nextAlarmDate: String
    let alarmTitle: String
}

// MARK: - Widget View

struct BetterAlarmWidgetEntryView: View {
    var entry: AlarmEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: AlarmEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.3),
                    Color(red: 0.2, green: 0.1, blue: 0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(.cyan)
                    Text("다음 알람")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Text(entry.nextAlarmTime)
                    .font(.system(size: 24, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)

                if !entry.nextAlarmDate.isEmpty {
                    Text(entry.nextAlarmDate)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                if !entry.alarmTitle.isEmpty {
                    Text(entry.alarmTitle)
                        .font(.caption2)
                        .foregroundColor(.cyan.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding()
        }
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: AlarmEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.1, blue: 0.3),
                    Color(red: 0.2, green: 0.1, blue: 0.4),
                    Color(red: 0.1, green: 0.2, blue: 0.5)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "alarm.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.cyan)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("다음 알람")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))

                    Text(entry.nextAlarmTime)
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    HStack {
                        if !entry.nextAlarmDate.isEmpty {
                            Text(entry.nextAlarmDate)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        if !entry.alarmTitle.isEmpty {
                            Text("• \(entry.alarmTitle)")
                                .font(.subheadline)
                                .foregroundColor(.cyan.opacity(0.8))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}

// MARK: - Widget Definition

struct BetterAlarmWidget: Widget {
    let kind: String = "BetterAlarmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlarmTimelineProvider()) { entry in
            BetterAlarmWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("다음 알람")
        .description("다음 알람 시간을 표시합니다.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    BetterAlarmWidget()
} timeline: {
    AlarmEntry(
        date: Date(),
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "내일",
        alarmTitle: "기상"
    )
}

#Preview(as: .systemMedium) {
    BetterAlarmWidget()
} timeline: {
    AlarmEntry(
        date: Date(),
        nextAlarmTime: "오전 7:30",
        nextAlarmDate: "내일",
        alarmTitle: "기상 알람"
    )
}
