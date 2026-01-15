import Foundation
import ActivityKit

// MARK: - Alarm Activity Attributes

struct AlarmActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var nextAlarmTime: String
        var nextAlarmDate: String
        var alarmTitle: String
        var isSkipped: Bool
        var isEmpty: Bool

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
            AppLogger.info("Live Activity enabled set to: \(newValue)", category: .liveActivity)
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
        AppLogger.info("LiveActivityManager initializing", category: .liveActivity)
        syncWithExistingActivity()
        AppLogger.info("LiveActivityManager initialized, hasActiveActivity: \(hasActiveActivity)", category: .liveActivity)
    }

    // MARK: - Sync with System

    private func syncWithExistingActivity() {
        AppLogger.debug("Syncing with existing activities", category: .liveActivity)
        if let existingActivity = Activity<AlarmActivityAttributes>.activities.first {
            currentActivity = existingActivity
            AppLogger.debug("Found existing activity: \(existingActivity.id)", category: .liveActivity)
        } else {
            AppLogger.debug("No existing activities found", category: .liveActivity)
        }
    }

    // MARK: - End All Activities (중복 방지)

    private func endAllActivities() async {
        AppLogger.debug("Ending all activities", category: .liveActivity)
        // 현재 참조 먼저 nil로
        currentActivity = nil

        // 시스템의 모든 Live Activity 종료
        let activities = Activity<AlarmActivityAttributes>.activities
        AppLogger.debug("Found \(activities.count) activities to end", category: .liveActivity)

        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        // 종료 확인을 위한 짧은 대기
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05초
        AppLogger.debug("All activities ended", category: .liveActivity)
    }

    // startActivity 메서드 전체 교체
    func startActivity(with alarm: Alarm) {
        AppLogger.info("Starting activity with alarm: \(alarm.displayTitle)", category: .liveActivity)

        guard isLiveActivityEnabled else {
            AppLogger.info("Live Activity is disabled by user", category: .liveActivity)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.warning("Live Activities are not enabled in system", category: .liveActivity)
            return
        }

        Task {
            // 기존 Activity 모두 종료하고 대기
            await endAllActivities()

            // 충분한 딜레이
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2초

            // 다시 한번 확인하고 종료
            for activity in Activity<AlarmActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초

            await MainActor.run {
                // 이미 Activity가 있으면 생성하지 않음
                guard Activity<AlarmActivityAttributes>.activities.isEmpty else {
                    AppLogger.debug("Activity already exists, updating instead", category: .liveActivity)
                    if let existing = Activity<AlarmActivityAttributes>.activities.first {
                        currentActivity = existing
                        let contentState = createContentState(for: alarm)
                        Task {
                            await existing.update(ActivityContent(state: contentState, staleDate: nil))
                        }
                    }
                    return
                }

                let attributes = AlarmActivityAttributes(alarmId: alarm.id.uuidString)
                let contentState = createContentState(for: alarm)

                do {
                    let activity = try Activity.request(
                        attributes: attributes,
                        content: .init(state: contentState, staleDate: nil),
                        pushType: nil
                    )
                    currentActivity = activity
                    AppLogger.info("Started activity for: \(alarm.displayTitle), id: \(activity.id)", category: .liveActivity)
                } catch {
                    AppLogger.error("Failed to start activity: \(error)", category: .liveActivity)
                }
            }
        }
    }

    // startEmptyActivity 메서드 전체 교체
    func startEmptyActivity() {
        AppLogger.info("Starting empty activity", category: .liveActivity)

        guard isLiveActivityEnabled else {
            AppLogger.info("Live Activity is disabled by user", category: .liveActivity)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.warning("Live Activities are not enabled in system", category: .liveActivity)
            return
        }

        Task {
            await endAllActivities()

            try? await Task.sleep(nanoseconds: 200_000_000)

            for activity in Activity<AlarmActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }

            try? await Task.sleep(nanoseconds: 100_000_000)

            await MainActor.run {
                guard Activity<AlarmActivityAttributes>.activities.isEmpty else {
                    AppLogger.debug("Activity already exists, updating to empty state", category: .liveActivity)
                    if let existing = Activity<AlarmActivityAttributes>.activities.first {
                        currentActivity = existing
                        let contentState = createEmptyContentState()
                        Task {
                            await existing.update(ActivityContent(state: contentState, staleDate: nil))
                        }
                    }
                    return
                }

                let attributes = AlarmActivityAttributes(alarmId: "empty")
                let contentState = createEmptyContentState()

                do {
                    let activity = try Activity.request(
                        attributes: attributes,
                        content: .init(state: contentState, staleDate: nil),
                        pushType: nil
                    )
                    currentActivity = activity
                    AppLogger.info("Started empty activity, id: \(activity.id)", category: .liveActivity)
                } catch {
                    AppLogger.error("Failed to start empty activity: \(error)", category: .liveActivity)
                }
            }
        }
    }

    // MARK: - Restart Activity

    func restartActivityIfNeeded(with alarm: Alarm?) {
        AppLogger.debug("Checking if activity restart needed", category: .liveActivity)

        guard isLiveActivityEnabled else {
            AppLogger.debug("Live Activity disabled, skipping restart", category: .liveActivity)
            return
        }

        if !hasActiveActivity {
            AppLogger.info("No active activity found, restarting", category: .liveActivity)
            if let alarm = alarm {
                startActivity(with: alarm)
            } else {
                startEmptyActivity()
            }
        } else {
            AppLogger.debug("Active activity exists, no restart needed", category: .liveActivity)
        }
    }

    // MARK: - Toggle Activity

    func setEnabled(_ enabled: Bool, with alarm: Alarm?) {
        AppLogger.info("Setting Live Activity enabled: \(enabled)", category: .liveActivity)
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
        AppLogger.debug("Updating activity with: \(alarm.displayTitle)", category: .liveActivity)

        guard isLiveActivityEnabled else {
            AppLogger.debug("Live Activity disabled, skipping update", category: .liveActivity)
            return
        }

        // Activity가 없으면 새로 시작
        guard let activity = currentActivity,
              Activity<AlarmActivityAttributes>.activities.contains(where: { $0.id == activity.id }) else {
            AppLogger.debug("No current activity, starting new one", category: .liveActivity)
            startActivity(with: alarm)
            return
        }

        let contentState = createContentState(for: alarm)

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
            AppLogger.info("Updated activity for: \(alarm.displayTitle)", category: .liveActivity)
        }
    }

    // MARK: - Update Empty State

    func updateEmptyState() {
        AppLogger.debug("Updating to empty state", category: .liveActivity)

        guard isLiveActivityEnabled else {
            AppLogger.debug("Live Activity disabled, skipping update", category: .liveActivity)
            return
        }

        guard let activity = currentActivity,
              Activity<AlarmActivityAttributes>.activities.contains(where: { $0.id == activity.id }) else {
            AppLogger.debug("No current activity, starting empty one", category: .liveActivity)
            startEmptyActivity()
            return
        }

        let contentState = createEmptyContentState()

        Task {
            await activity.update(ActivityContent(state: contentState, staleDate: nil))
            AppLogger.info("Updated to empty state", category: .liveActivity)
        }
    }

    // MARK: - End Activity

    func endActivity() {
        AppLogger.info("Ending activity", category: .liveActivity)
        Task {
            await endAllActivities()
            AppLogger.info("All activities ended", category: .liveActivity)
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
            AppLogger.debug("No next trigger date, returning empty state", category: .liveActivity)
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

        AppLogger.debug("Created content state: \(timeString) \(dateString)", category: .liveActivity)

        return AlarmActivityAttributes.ContentState(
            nextAlarmTime: timeString,
            nextAlarmDate: dateString,
            alarmTitle: alarm.displayTitle,
            isSkipped: alarm.isSkippingNext,
            isEmpty: false
        )
    }
}
