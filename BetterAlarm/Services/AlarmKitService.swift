import Foundation
import AlarmKit
import AppIntents

// MARK: - AlarmMetadata (필수)

nonisolated struct BetterAlarmMetadata: AlarmMetadata {}

// MARK: - Keys for Intent Communication

enum AlarmIntentKeys {
    static let alarmDismissedKey = "alarmDismissedFromIntent"
    static let alarmDismissedTimeKey = "alarmDismissedTime"
    static let alarmSnoozedKey = "alarmSnoozedFromIntent"
}

// MARK: - App Intents (Live Activity 버튼용)

struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "알람 정지"
    static var description = IntentDescription("알람을 정지합니다")

    @Parameter(title: "알람 ID")
    var alarmID: String

    init() {
        self.alarmID = ""
    }

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    func perform() async throws -> some IntentResult {
        AppLogger.info("StopAlarmIntent perform called, alarmID: \(alarmID)", category: .alarmKit)

        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
            AppLogger.info("Alarm stopped via intent: \(id)", category: .alarmKit)
        }

        // UserDefaults에 알람 해제 정보 저장 (앱이 foreground로 올 때 처리)
        let userDefaults = UserDefaults.standard
        userDefaults.set(true, forKey: AlarmIntentKeys.alarmDismissedKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: AlarmIntentKeys.alarmDismissedTimeKey)
        userDefaults.synchronize()

        AppLogger.debug("Alarm dismissed flag saved to UserDefaults", category: .alarmKit)

        return .result()
    }
}

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
        AppLogger.info("SnoozeAlarmIntent perform called, alarmID: \(alarmID)", category: .alarmKit)

        await AlarmKitService.shared.snoozeFromIntent(alarmID: alarmID)

        // 스누즈 정보 저장
        let userDefaults = UserDefaults.standard
        userDefaults.set(true, forKey: AlarmIntentKeys.alarmSnoozedKey)
        userDefaults.synchronize()

        AppLogger.debug("Snooze flag saved to UserDefaults", category: .alarmKit)

        return .result()
    }
}

// MARK: - AlarmKit Service

@MainActor
final class AlarmKitService {
    static let shared = AlarmKitService()

    private let manager = AlarmManager.shared

    // 스케줄된 알람 ID 추적
    private var currentAlarmId: UUID?

    // 현재 스케줄된 앱 알람 (Alarm 모델)
    private var currentScheduledAlarm: Alarm?

    // 알람 모니터링 Task
    private var monitorTask: Task<Void, Never>?

    // 알람이 울릴 때 콜백
    private var onAlerting: ((UUID) -> Void)?

    // 알람이 완료될 때 콜백
    private var onAlarmCompleted: ((Alarm) -> Void)?

    // 스누즈 시간 (5분)
    static let snoozeInterval: TimeInterval = 5 * 60

    private init() {
        AppLogger.info("AlarmKitService initializing", category: .alarmKit)
        startMonitoring()
        AppLogger.info("AlarmKitService initialized", category: .alarmKit)
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        AppLogger.info("Requesting AlarmKit permission", category: .permission)
        do {
            let status = try await manager.requestAuthorization()
            let authorized = status == .authorized
            AppLogger.info("AlarmKit permission result: \(authorized)", category: .permission)
            return authorized
        } catch {
            AppLogger.error("Failed to request AlarmKit permission: \(error)", category: .permission)
            return false
        }
    }

    func checkAuthorizationStatus() -> Bool {
        let status = manager.authorizationState
        let authorized = status == .authorized
        AppLogger.debug("AlarmKit authorization status: \(authorized)", category: .permission)
        return authorized
    }

    // MARK: - Monitoring

    func observeAlertingAlarms(_ handler: @escaping (UUID) -> Void) {
        AppLogger.debug("Registering alerting alarms observer", category: .alarmKit)
        self.onAlerting = handler
    }

    func observeAlarmCompleted(_ handler: @escaping (Alarm) -> Void) {
        AppLogger.debug("Registering alarm completed observer", category: .alarmKit)
        self.onAlarmCompleted = handler
    }

    func stopMonitoring() {
        AppLogger.info("Stopping alarm monitoring", category: .alarmKit)
        monitorTask?.cancel()
        monitorTask = nil
    }

    func resumeMonitoring() {
        if monitorTask == nil {
            AppLogger.info("Resuming alarm monitoring", category: .alarmKit)
            startMonitoring()
        }
    }

    private func startMonitoring() {
        AppLogger.debug("Starting alarm monitoring task", category: .alarmKit)
        monitorTask?.cancel()

        monitorTask = Task {
            for await alarms in manager.alarmUpdates {
                if Task.isCancelled { break }

                AppLogger.debug("Alarm updates received, count: \(alarms.count)", category: .alarmKit)

                if alarms.isEmpty {
                    // 알람이 없어졌다면 (정지됨) - 완료 콜백 호출
                    if let completedAlarm = self.currentScheduledAlarm {
                        AppLogger.info("Alarm completed detected: \(completedAlarm.displayTitle)", category: .alarmKit)
                        self.onAlarmCompleted?(completedAlarm)
                    }
                    self.currentAlarmId = nil
                    self.currentScheduledAlarm = nil
                }

                for alarm in alarms where alarm.state == .alerting {
                    AppLogger.info("Alarm alerting: \(alarm.id)", category: .alarmKit)
                    self.onAlerting?(alarm.id)
                }
            }
        }
    }

    // MARK: - Check for Intent Actions (앱이 foreground로 올 때 호출)

    func checkForPendingIntentActions() {
        AppLogger.debug("Checking for pending intent actions", category: .alarmKit)
        let userDefaults = UserDefaults.standard

        // 알람 해제 확인
        if userDefaults.bool(forKey: AlarmIntentKeys.alarmDismissedKey) {
            AppLogger.info("Found pending alarm dismissal from intent", category: .alarmKit)
            userDefaults.set(false, forKey: AlarmIntentKeys.alarmDismissedKey)

            // 완료된 알람 처리
            if let alarm = currentScheduledAlarm {
                AppLogger.info("Processing completed alarm: \(alarm.displayTitle)", category: .alarmKit)
                onAlarmCompleted?(alarm)
            }

            currentAlarmId = nil
            currentScheduledAlarm = nil

            AppLogger.info("Processed alarm dismissal from intent", category: .alarmKit)
        }

        // 스누즈 확인
        if userDefaults.bool(forKey: AlarmIntentKeys.alarmSnoozedKey) {
            userDefaults.set(false, forKey: AlarmIntentKeys.alarmSnoozedKey)
            AppLogger.info("Processed snooze from intent", category: .alarmKit)
        }

        userDefaults.synchronize()
    }

    // MARK: - Schedule Alarm

    func scheduleAlarm(for alarm: Alarm) async {
        AppLogger.info("Scheduling alarm: \(alarm.displayTitle)", category: .alarmKit)

        guard alarm.isEnabled else {
            AppLogger.debug("Alarm is disabled, skipping schedule", category: .alarmKit)
            return
        }

        // 권한 확인
        guard await requestPermission() else {
            AppLogger.warning("AlarmKit not authorized, cannot schedule", category: .alarmKit)
            return
        }

        // 기존 알람 모두 중지
        await stopAllAlarms()

        do {
            let id = UUID()
            currentAlarmId = id
            currentScheduledAlarm = alarm

            // 다음 알람까지의 시간 계산
            guard let triggerDate = alarm.nextTriggerDate() else {
                AppLogger.warning("No trigger date for alarm", category: .alarmKit)
                return
            }
            let duration = triggerDate.timeIntervalSinceNow

            guard duration > 0 else {
                AppLogger.warning("Trigger date is in the past: \(triggerDate)", category: .alarmKit)
                return
            }

            AppLogger.debug("Alarm will trigger in \(Int(duration)) seconds at \(triggerDate)", category: .alarmKit)

            // AlarmAttributes 생성
            let attributes = createAlarmAttributes(
                title: alarm.displayTitle,
                message: "알람이 울립니다"
            )

            typealias Config = AlarmManager.AlarmConfiguration<BetterAlarmMetadata>
            let config = Config.timer(
                duration: duration,
                attributes: attributes,
                stopIntent: StopAlarmIntent(alarmID: id.uuidString),
                secondaryIntent: SnoozeAlarmIntent(alarmID: id.uuidString)
            )

            _ = try await manager.schedule(id: id, configuration: config)

            AppLogger.alarmScheduled("\(alarm.displayTitle) id=\(id.uuidString.prefix(8))", triggerDate: triggerDate)

        } catch {
            AppLogger.error("Failed to schedule alarm: \(error)", category: .alarmKit)
        }
    }

    // MARK: - Cancel/Stop

    func cancelAlarm(for alarm: Alarm) {
        AppLogger.info("Cancelling alarm: \(alarm.displayTitle)", category: .alarmKit)

        guard let alarmId = currentAlarmId else {
            AppLogger.debug("No current alarm to cancel", category: .alarmKit)
            return
        }

        do {
            try manager.stop(id: alarmId)
            currentAlarmId = nil
            currentScheduledAlarm = nil
            AppLogger.info("Alarm cancelled successfully", category: .alarmKit)
        } catch {
            AppLogger.error("Failed to cancel alarm: \(error)", category: .alarmKit)
        }
    }

    func stopAllAlarms() async {
        AppLogger.debug("Stopping all alarms", category: .alarmKit)
        do {
            let existingAlarms = try manager.alarms
            AppLogger.debug("Found \(existingAlarms.count) existing alarms to stop", category: .alarmKit)
            for alarm in existingAlarms {
                try manager.stop(id: alarm.id)
            }
            currentAlarmId = nil
            currentScheduledAlarm = nil
            AppLogger.debug("All alarms stopped", category: .alarmKit)
        } catch {
            AppLogger.error("Failed to stop alarms: \(error)", category: .alarmKit)
        }
    }

    // MARK: - Snooze

    nonisolated func snoozeFromIntent(alarmID: String) async {
        AppLogger.info("Snoozing alarm from intent: \(alarmID)", category: .alarmKit)
        let manager = AlarmManager.shared

        // 현재 알람 중지
        if let id = UUID(uuidString: alarmID) {
            try? manager.stop(id: id)
            AppLogger.debug("Original alarm stopped for snooze", category: .alarmKit)
        }

        // 새 알람 예약 (5분 후)
        let newId = UUID()
        let snoozeTime = Date().addingTimeInterval(Self.snoozeInterval)
        AppLogger.debug("Snooze alarm will trigger at: \(snoozeTime)", category: .alarmKit)

        let attributes = await Self.createAlarmAttributesStatic(
            title: "스누즈 알람",
            message: "다시 알람이 울립니다"
        )

        typealias Config = AlarmManager.AlarmConfiguration<BetterAlarmMetadata>
        let config = await Config.timer(
            duration: Self.snoozeInterval,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: newId.uuidString),
            secondaryIntent: SnoozeAlarmIntent(alarmID: newId.uuidString)
        )

        _ = try? await manager.schedule(id: newId, configuration: config)

        AppLogger.info("Snooze alarm scheduled, id=\(newId.uuidString.prefix(8))", category: .alarmKit)
    }

    // MARK: - Alarm Attributes Helper

    private func createAlarmAttributes(
        title: String,
        message: String? = nil
    ) -> AlarmAttributes<BetterAlarmMetadata> {
        Self.createAlarmAttributesStatic(title: title, message: message)
    }

    private static func createAlarmAttributesStatic(
        title: String,
        message: String? = nil
    ) -> AlarmAttributes<BetterAlarmMetadata> {
        let fullTitle: String
        if let message = message {
            fullTitle = "\(title)\n\(message)"
        } else {
            fullTitle = title
        }

        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: fullTitle),
            stopButton: AlarmButton(
                text: "정지",
                textColor: .white,
                systemImageName: "stop.fill"
            ),
            secondaryButton: AlarmButton(
                text: "스누즈",
                textColor: .white,
                systemImageName: "moon.zzz.fill"
            ),
            secondaryButtonBehavior: .custom
        )

        return AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            tintColor: .blue
        )
    }

    // MARK: - Getters

    func getCurrentAlarmId() -> UUID? {
        return currentAlarmId
    }

    func getCurrentScheduledAlarm() -> Alarm? {
        return currentScheduledAlarm
    }
}
