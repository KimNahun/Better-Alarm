import Foundation
import ActivityKit

// MARK: - Alarm Activity Attributes
// This definition must exist in both main app and widget targets
// as they are separate compilation units

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

    // UserDefaults key for Live Activity enabled state
    private let liveActivityEnabledKey = "liveActivityEnabled"

    var isLiveActivityEnabled: Bool {
        get {
            // Default to true if not set
            if UserDefaults.standard.object(forKey: liveActivityEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: liveActivityEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liveActivityEnabledKey)
        }
    }

    // Check if Live Activities are supported and authorized
    var areActivitiesAvailable: Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // Check if there's currently an active Live Activity
    var hasActiveActivity: Bool {
        // Check both our reference and the system's active activities
        if let activity = currentActivity {
            // Verify the activity is still active in the system
            return Activity<AlarmActivityAttributes>.activities.contains { $0.id == activity.id }
        }
        return !Activity<AlarmActivityAttributes>.activities.isEmpty
    }

    private init() {
        // Sync with any existing activity on init
        syncWithExistingActivity()
    }

    // MARK: - Sync with System

    private func syncWithExistingActivity() {
        // If there's an existing activity in the system, sync our reference
        if let existingActivity = Activity<AlarmActivityAttributes>.activities.first {
            currentActivity = existingActivity
        }
    }

    // MARK: - Start Activity

    func startActivity(with alarm: Alarm) {
        guard isLiveActivityEnabled else {
            print("[LiveActivity] Live Activity is disabled by user")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities are not enabled in system")
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

    // MARK: - Restart Activity (if dismissed by user)

    func restartActivityIfNeeded(with alarm: Alarm?) {
        guard isLiveActivityEnabled else { return }
        guard let alarm = alarm else {
            endActivity()
            return
        }

        // If user has enabled Live Activity but there's no active one, restart it
        if !hasActiveActivity {
            print("[LiveActivity] No active activity found, restarting...")
            startActivity(with: alarm)
        }
    }

    // MARK: - Toggle Activity

    func setEnabled(_ enabled: Bool, with alarm: Alarm?) {
        isLiveActivityEnabled = enabled

        if enabled {
            if let alarm = alarm {
                startActivity(with: alarm)
            }
        } else {
            endActivity()
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
