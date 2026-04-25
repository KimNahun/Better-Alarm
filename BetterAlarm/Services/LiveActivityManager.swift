import Foundation

// MARK: - AlarmActivityAttributes

/// Live Activity에 표시할 알람 정보를 정의하는 ActivityAttributes.
/// 위젯 타겟에도 동일 구조가 존재한다 (별도 타겟이므로 중복 정의 필수).
#if os(iOS)
import ActivityKit

struct AlarmActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var nextAlarmTime: String   // "오전 7:00"
        var nextAlarmDate: String   // "오늘" | "내일" | "M월 d일"
        var alarmTitle: String
        var isSkipped: Bool
        var isEmpty: Bool
        var themeName: String       // PTheme.rawValue — 위젯 테마 색상 동기화

        init(
            nextAlarmTime: String,
            nextAlarmDate: String,
            alarmTitle: String,
            isSkipped: Bool,
            isEmpty: Bool = false,
            themeName: String = "winter"
        ) {
            self.nextAlarmTime = nextAlarmTime
            self.nextAlarmDate = nextAlarmDate
            self.alarmTitle = alarmTitle
            self.isSkipped = isSkipped
            self.isEmpty = isEmpty
            self.themeName = themeName
        }
    }

    var alarmId: String
}

// MARK: - LiveActivityManager

/// ActivityKit Live Activity를 관리하는 actor.
/// 잠금화면/Dynamic Island에 다음 알람 정보를 실시간 표시한다.
/// Swift 6: actor로 구현하여 스레드 안전성 보장.
@available(iOS 17.0, *)
actor LiveActivityManager {
    private var currentActivity: Activity<AlarmActivityAttributes>?

    private let liveActivityEnabledKey = "liveActivityEnabled"

    // MARK: - Settings

    /// 사용자가 Live Activity를 활성화/비활성화하는 설정값.
    /// UserDefaults에 저장되며 기본값은 true.
    var isLiveActivityEnabled: Bool {
        if UserDefaults.standard.object(forKey: liveActivityEnabledKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: liveActivityEnabledKey)
    }

    func setLiveActivityEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: liveActivityEnabledKey)
        AppLogger.info("Live Activity enabled set to: \(value)", category: .liveActivity)
    }

    /// 시스템에서 Live Activity가 허용되어 있는지 여부
    var areActivitiesAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    // MARK: - Start Activity

    /// 특정 알람에 대한 Live Activity를 시작한다.
    /// 이미 활성화된 Activity가 있으면 종료 후 새로 시작한다.
    func startActivity(for alarm: Alarm) async {
        AppLogger.info("Starting activity for alarm: \(alarm.displayTitle)", category: .liveActivity)

        guard isLiveActivityEnabled else {
            AppLogger.info("Live Activity is disabled by user", category: .liveActivity)
            return
        }

        guard areActivitiesAvailable else {
            AppLogger.warning("Live Activities are not enabled in system", category: .liveActivity)
            return
        }

        // 기존 Activity 모두 종료
        await endAllActivities()

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

    // MARK: - Update Activity

    /// 다음 알람 정보로 Live Activity를 업데이트한다.
    /// nextAlarm이 nil이면 Activity를 종료한다.
    func updateActivity(nextAlarm: Alarm?) async {
        guard isLiveActivityEnabled else {
            AppLogger.debug("Live Activity disabled, skipping update", category: .liveActivity)
            return
        }

        guard let alarm = nextAlarm else {
            AppLogger.info("No next alarm, ending activity", category: .liveActivity)
            await endActivity()
            return
        }

        // Activity가 없으면 새로 시작
        guard let activity = currentActivity,
              Activity<AlarmActivityAttributes>.activities.contains(where: { $0.id == activity.id }) else {
            AppLogger.debug("No current activity found, starting new one", category: .liveActivity)
            await startActivity(for: alarm)
            return
        }

        let contentState = createContentState(for: alarm)
        await activity.update(ActivityContent(state: contentState, staleDate: nil))

        // E9 수정: update() 호출 후 activity가 이미 종료된 경우 currentActivity 참조 해제.
        // activities.contains 확인 → update 사이 TOCTOU로 activity가 끝났을 때 stale 참조 방지.
        if Activity<AlarmActivityAttributes>.activities.contains(where: { $0.id == activity.id }) {
            AppLogger.info("Updated activity for: \(alarm.displayTitle)", category: .liveActivity)
        } else {
            currentActivity = nil
            AppLogger.info("Activity ended during update, reference cleared: \(alarm.displayTitle)", category: .liveActivity)
        }
    }

    // MARK: - End Activity

    /// 현재 활성화된 모든 Live Activity를 종료한다.
    func endActivity() async {
        AppLogger.info("Ending all activities", category: .liveActivity)
        await endAllActivities()
    }

    // MARK: - Private Helpers

    /// 시스템에 등록된 모든 AlarmActivityAttributes Activity를 종료한다.
    private func endAllActivities() async {
        currentActivity = nil

        let activities = Activity<AlarmActivityAttributes>.activities
        AppLogger.debug("Found \(activities.count) activities to end", category: .liveActivity)

        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// 알람 데이터에서 Live Activity ContentState를 생성한다.
    private func createContentState(for alarm: Alarm) -> AlarmActivityAttributes.ContentState {
        let themeName = UserDefaults.standard.string(forKey: "selectedTheme") ?? "winter"

        guard let nextDate = alarm.nextTriggerDate() else {
            AppLogger.debug("No next trigger date, returning empty state", category: .liveActivity)
            return AlarmActivityAttributes.ContentState(
                nextAlarmTime: "--:--",
                nextAlarmDate: String(localized: "live_activity_no_alarm_date"),
                alarmTitle: String(localized: "live_activity_no_alarm_title"),
                isSkipped: false,
                isEmpty: true,
                themeName: themeName
            )
        }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: nextDate)
        let minute = calendar.component(.minute, from: nextDate)
        let timeString = LocalizedDateFormatters.timeDisplayString(hour: hour, minute: minute)
        let dateString = LocalizedDateFormatters.relativeDateString(for: nextDate)

        AppLogger.debug("Created content state: \(timeString) \(dateString) theme=\(themeName)", category: .liveActivity)

        return AlarmActivityAttributes.ContentState(
            nextAlarmTime: timeString,
            nextAlarmDate: dateString,
            alarmTitle: alarm.displayTitle,
            isSkipped: alarm.isSkippingNext,
            isEmpty: false,
            themeName: themeName
        )
    }
}
#endif // os(iOS)
