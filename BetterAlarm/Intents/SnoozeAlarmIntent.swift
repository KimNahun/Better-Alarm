import AppIntents
#if os(iOS)
import AlarmKit
#endif

// MARK: - SnoozeAlarmIntent (iOS 26+)

/// 잠금화면 Live Activity 버튼에서 알람을 스누즈(5분 후 재알람)하는 AppIntent.
@available(iOS 26.0, *)
struct SnoozeAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "intent_snooze_title"
    static var description = IntentDescription("intent_snooze_description")
    static var openAppWhenRun = false

    @Parameter(title: "intent_alarmid_param")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        AppLogger.info("SnoozeAlarmIntent performed for id=\(alarmID)", category: .alarm)
        // E8 수정: AlarmKitService() 직접 인스턴스화 제거.
        // App Extension은 별도 프로세스 → 앱의 AlarmKitService actor와 메모리 공간이 다름.
        // AlarmManager.shared는 시스템 공유 인스턴스이므로 직접 사용이 올바른 방식.

        // 현재 알람 중지
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }

        // 5분 후 스누즈 알람을 AlarmManager.shared로 직접 등록
        let newID = UUID()
        let snoozeDate = Date().addingTimeInterval(5 * 60)

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource("alarmkit_alert_snooze_title"),
            stopButton: AlarmButton(
                text: LocalizedStringResource("alarmkit_button_stop"),
                textColor: .white,
                systemImageName: "stop.fill"
            ),
            secondaryButton: AlarmButton(
                text: LocalizedStringResource("alarmkit_button_snooze"),
                textColor: .white,
                systemImageName: "moon.zzz.fill"
            ),
            secondaryButtonBehavior: .custom
        )
        let presentation = AlarmPresentation(alert: alert)
        let attributes = AlarmAttributes<BetterAlarmMetadata>(
            presentation: presentation,
            tintColor: .purple
        )

        typealias Config = AlarmManager.AlarmConfiguration<BetterAlarmMetadata>
        let config = Config(
            schedule: .fixed(snoozeDate),
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: newID.uuidString),
            secondaryIntent: SnoozeAlarmIntent(alarmID: newID.uuidString)
        )
        _ = try? await AlarmManager.shared.schedule(id: newID, configuration: config)

        // Intent는 별도 프로세스 → AlarmStore에 직접 접근 불가
        // UserDefaults를 브릿지로 사용하여 앱 복귀 시 snoozeDate 동기화
        UserDefaults.standard.set(true, forKey: "alarmSnoozedFromIntent")
        UserDefaults.standard.set(alarmID, forKey: "alarmSnoozedAlarmID")
        UserDefaults.standard.set(snoozeDate.timeIntervalSince1970, forKey: "alarmSnoozeDateTimestamp")

        return .result()
    }
}
