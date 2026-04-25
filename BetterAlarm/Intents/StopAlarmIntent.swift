import AppIntents
#if os(iOS)
import AlarmKit
#endif

// MARK: - StopAlarmIntent (iOS 26+)

/// 잠금화면 Live Activity 버튼에서 알람을 정지하는 AppIntent.
@available(iOS 26.0, *)
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "intent_stop_title"
    static var description = IntentDescription("intent_stop_description")

    @Parameter(title: "intent_alarmid_param")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        AppLogger.info("StopAlarmIntent performed for id=\(alarmID)", category: .alarm)
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }

        // UserDefaults를 통해 앱에 알람 정지 이벤트 전달
        UserDefaults.standard.set(true, forKey: "alarmDismissedFromIntent")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "alarmDismissedTime")
        UserDefaults.standard.set([alarmID], forKey: "alarmDismissedIDs")
        UserDefaults.standard.synchronize()

        return .result()
    }
}
