import Foundation
import ActivityKit

// MARK: - Alarm Activity Attributes (Must match Widget definition)

struct AlarmActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var nextAlarmTime: String
        var nextAlarmDate: String
        var alarmTitle: String
        var isSkipped: Bool
    }

    var alarmId: String
}

// MARK: - Live Activity Manager

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<AlarmActivityAttributes>?

    private init() {}

    // MARK: - Start Activity

    func startActivity(with alarm: Alarm) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled")
            return
        }

        endActivity()

        let attributes = AlarmActivityAttributes(alarmId: alarm.id.uuidString)
        let contentState = createContentState(for: alarm)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started activity for: \(alarm.displayTitle)")
        } catch {
            print("[LiveActivity] Failed to start: \(error)")
        }
    }

    // MARK: - Update Activity

    func updateActivity(with alarm: Alarm) {
        guard let activity = currentActivity else {
            startActivity(with: alarm)
            return
        }

        let contentState = createContentState(for: alarm)

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
            print("[LiveActivity] Updated activity for: \(alarm.displayTitle)")
        }
    }

    // MARK: - End Activity

    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
            print("[LiveActivity] Ended activity")
        }
    }

    // MARK: - Helper

    private func createContentState(for alarm: Alarm) -> AlarmActivityAttributes.ContentState {
        guard let nextDate = alarm.nextTriggerDate() else {
            return AlarmActivityAttributes.ContentState(
                nextAlarmTime: "--:--",
                nextAlarmDate: "알람 없음",
                alarmTitle: "",
                isSkipped: false
            )
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: nextDate)
        let minute = calendar.component(.minute, from: nextDate)
        let period = hour < 12 ? "오전" : "오후"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let timeString = String(format: "%@ %d:%02d", period, displayHour, minute)

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")

        let dateString: String
        if calendar.isDateInToday(nextDate) {
            dateString = "오늘"
        } else if calendar.isDateInTomorrow(nextDate) {
            dateString = "내일"
        } else {
            dateFormatter.dateFormat = "M월 d일 (E)"
            dateString = dateFormatter.string(from: nextDate)
        }

        return AlarmActivityAttributes.ContentState(
            nextAlarmTime: timeString,
            nextAlarmDate: dateString,
            alarmTitle: alarm.displayTitle,
            isSkipped: alarm.isSkippingNext
        )
    }
}
