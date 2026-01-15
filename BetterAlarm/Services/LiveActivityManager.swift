import Foundation
import ActivityKit

// MARK: - Alarm Activity Attributes

struct AlarmActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var nextAlarmTime: String
        var nextAlarmDate: String
        var alarmTitle: String
        var isSkipped: Bool
        var isEmpty: Bool  // 알람 없음 상태
        
        init(nextAlarmTime: String, nextAlarmDate: String, alarmTitle: String, isSkipped: Bool, isEmpty: Bool = false) {
            self.nextAlarmTime = nextAlarmTime
            self.nextAlarmDate = nextAlarmDate
            self.alarmTitle = alarmTitle
            self.isSkipped = isSkipped
            self.isEmpty = isEmpty
        }
    }

    var alarmId: String
}

// MARK: - Live Activity Manager

@MainActor
class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<AlarmActivityAttributes>?

    private let liveActivityEnabledKey = "liveActivityEnabled"

    var isLiveActivityEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: liveActivityEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: liveActivityEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: liveActivityEnabledKey)
        }
    }

    var areActivitiesAvailable: Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    var hasActiveActivity: Bool {
        if let activity = currentActivity {
            return Activity<AlarmActivityAttributes>.activities.contains { $0.id == activity.id }
        }
        return !Activity<AlarmActivityAttributes>.activities.isEmpty
    }

    private init() {
        syncWithExistingActivity()
    }

    // MARK: - Sync with System

    private func syncWithExistingActivity() {
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
    
    // MARK: - Start Empty Activity (알람 없음 상태)
    
    func startEmptyActivity() {
        guard isLiveActivityEnabled else {
            print("[LiveActivity] Live Activity is disabled by user")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities are not enabled in system")
            return
        }

        endActivity()

        let attributes = AlarmActivityAttributes(alarmId: "empty")
        let contentState = createEmptyContentState()

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("[LiveActivity] Started empty activity")
        } catch {
            print("[LiveActivity] Failed to start empty activity: \(error)")
        }
    }

    // MARK: - Restart Activity

    func restartActivityIfNeeded(with alarm: Alarm?) {
        guard isLiveActivityEnabled else { return }
        
        if !hasActiveActivity {
            print("[LiveActivity] No active activity found, restarting...")
            if let alarm = alarm {
                startActivity(with: alarm)
            } else {
                startEmptyActivity()
            }
        }
    }

    // MARK: - Toggle Activity

    func setEnabled(_ enabled: Bool, with alarm: Alarm?) {
        isLiveActivityEnabled = enabled

        if enabled {
            if let alarm = alarm {
                startActivity(with: alarm)
            } else {
                startEmptyActivity()
            }
        } else {
            endActivity()
        }
    }

    // MARK: - Update Activity

    func updateActivity(with alarm: Alarm) {
        guard isLiveActivityEnabled else { return }
        
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
    
    // MARK: - Update Empty State
    
    func updateEmptyState() {
        guard isLiveActivityEnabled else { return }
        
        guard let activity = currentActivity else {
            startEmptyActivity()
            return
        }

        let contentState = createEmptyContentState()

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
            print("[LiveActivity] Updated to empty state")
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
    
    private func createEmptyContentState() -> AlarmActivityAttributes.ContentState {
        return AlarmActivityAttributes.ContentState(
            nextAlarmTime: "--:--",
            nextAlarmDate: "설정된 알람 없음",
            alarmTitle: "알람을 추가해주세요",
            isSkipped: false,
            isEmpty: true
        )
    }

    private func createContentState(for alarm: Alarm) -> AlarmActivityAttributes.ContentState {
        guard let nextDate = alarm.nextTriggerDate() else {
            return createEmptyContentState()
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
        
        // 스킵 상태면 표시
        var title = alarm.displayTitle
        if alarm.isSkippingNext {
            title = "⏭️ " + title + " (스킵됨)"
        }

        return AlarmActivityAttributes.ContentState(
            nextAlarmTime: timeString,
            nextAlarmDate: dateString,
            alarmTitle: title,
            isSkipped: alarm.isSkippingNext,
            isEmpty: false
        )
    }
}
