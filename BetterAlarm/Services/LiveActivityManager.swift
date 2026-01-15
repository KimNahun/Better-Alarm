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
    
    // MARK: - End All Activities (중복 방지)
    
    // LiveActivityManager.swift - endAllActivities 메서드 전체 교체

    private func endAllActivities() async {
        // 현재 참조 먼저 nil로
        currentActivity = nil
        
        // 시스템의 모든 Live Activity 종료
        for activity in Activity<AlarmActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        
        // 종료 확인을 위한 짧은 대기
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05초
    }

    // startActivity 메서드 전체 교체
    func startActivity(with alarm: Alarm) {
        guard isLiveActivityEnabled else {
            print("[LiveActivity] Live Activity is disabled by user")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities are not enabled in system")
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
                    print("[LiveActivity] Activity already exists, updating instead")
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
                    print("[LiveActivity] Started activity for: \(alarm.displayTitle)")
                } catch {
                    print("[LiveActivity] Failed to start: \(error)")
                }
            }
        }
    }

    // startEmptyActivity 메서드 전체 교체
    func startEmptyActivity() {
        guard isLiveActivityEnabled else {
            print("[LiveActivity] Live Activity is disabled by user")
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("[LiveActivity] Live Activities are not enabled in system")
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
                    print("[LiveActivity] Activity already exists, updating instead")
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
                    print("[LiveActivity] Started empty activity")
                } catch {
                    print("[LiveActivity] Failed to start empty activity: \(error)")
                }
            }
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
        
        // Activity가 없으면 새로 시작
        guard let activity = currentActivity,
              Activity<AlarmActivityAttributes>.activities.contains(where: { $0.id == activity.id }) else {
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
        
        guard let activity = currentActivity,
              Activity<AlarmActivityAttributes>.activities.contains(where: { $0.id == activity.id }) else {
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
        Task {
            await endAllActivities()
            print("[LiveActivity] Ended all activities")
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

        return AlarmActivityAttributes.ContentState(
            nextAlarmTime: timeString,
            nextAlarmDate: dateString,
            alarmTitle: alarm.displayTitle,
            isSkipped: alarm.isSkippingNext,
            isEmpty: false
        )
    }
}
