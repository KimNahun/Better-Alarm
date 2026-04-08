import AppIntents
#if os(iOS)
import AlarmKit
#endif

// MARK: - SnoozeAlarmIntent (iOS 26+)

/// 잠금화면 Live Activity 버튼에서 알람을 스누즈(5분 후 재알람)하는 AppIntent.
@available(iOS 26.0, *)
struct SnoozeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "스누즈"
    static var description = IntentDescription("알람을 스누즈합니다")
    static var openAppWhenRun = false

    @Parameter(title: "알람 ID")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        // 현재 알람 중지
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }

        // 5분 후 스누즈 알람 등록
        let service = AlarmKitService()
        await service.snoozeAlarm(id: alarmID)

        UserDefaults.standard.set(true, forKey: "alarmSnoozedFromIntent")
        UserDefaults.standard.synchronize()

        return .result()
    }
}
