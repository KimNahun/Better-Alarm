import Foundation
import AlarmKit
import AppIntents

// MARK: - AlarmMetadata (필수)

nonisolated struct BetterAlarmMetadata: AlarmMetadata {}

// MARK: - Keys for Intent Communication

enum AlarmIntentKeys {
    static let alarmDismissedKey = "alarmDismissedFromIntent"
    static let alarmDismissedTimeKey = "alarmDismissedTime"
    static let alarmDismissedAlarmIdsKey = "alarmDismissedAlarmIds"
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

        let userDefaults = UserDefaults.standard
        userDefaults.set(true, forKey: AlarmIntentKeys.alarmDismissedKey)
        userDefaults.set(Date().timeIntervalSince1970, forKey: AlarmIntentKeys.alarmDismissedTimeKey)
        
        let mapping = userDefaults.dictionary(forKey: "alarmKitToAppAlarmIdMapping") as? [String: String] ?? [:]
        if let appAlarmId = mapping[alarmID] {
            var dismissedIds = userDefaults.stringArray(forKey: AlarmIntentKeys.alarmDismissedAlarmIdsKey) ?? []
            if !dismissedIds.contains(appAlarmId) {
                dismissedIds.append(appAlarmId)
                userDefaults.set(dismissedIds, forKey: AlarmIntentKeys.alarmDismissedAlarmIdsKey)
                AppLogger.debug("Added app alarm ID to dismissed list: \(appAlarmId), total: \(dismissedIds.count)", category: .alarmKit)
            }
        }
        
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

        let userDefaults = UserDefaults.standard
        userDefaults.set(true, forKey: AlarmIntentKeys.alarmSnoozedKey)
        userDefaults.synchronize()

        AppLogger.debug("Snooze flag saved to UserDefaults", category: .alarmKit)

        return .result()
    }
}

// MARK: - Type Aliases for AlarmKit (이름 충돌 방지)

typealias AKAlarm = AlarmKit.Alarm
typealias AKSchedule = AlarmKit.Alarm.Schedule

// MARK: - AlarmKit Service

@MainActor
final class AlarmKitService {
    static let shared = AlarmKitService()

    private let manager = AlarmManager.shared

    // 스케줄된 알람 ID 추적 (AlarmKit ID)
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

    // 스케줄링 중 플래그
    private var isScheduling = false
    
    // AlarmKit ID -> Alarm 모델 ID 매핑 저장 키
    private let alarmIdMappingKey = "alarmKitToAppAlarmIdMapping"

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
                    if self.isScheduling {
                        AppLogger.debug("Ignoring empty alarms during scheduling", category: .alarmKit)
                    } else if let completedAlarm = self.currentScheduledAlarm {
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

    // MARK: - Check for Intent Actions

    func checkForPendingIntentActions() -> [UUID] {
        AppLogger.debug("Checking for pending intent actions", category: .alarmKit)
        let userDefaults = UserDefaults.standard
        var completedAlarmIds: [UUID] = []

        if userDefaults.bool(forKey: AlarmIntentKeys.alarmDismissedKey) {
            AppLogger.info("Found pending alarm dismissal from intent", category: .alarmKit)
            userDefaults.set(false, forKey: AlarmIntentKeys.alarmDismissedKey)

            if let dismissedIdStrings = userDefaults.stringArray(forKey: AlarmIntentKeys.alarmDismissedAlarmIdsKey) {
                AppLogger.info("Found \(dismissedIdStrings.count) completed alarm IDs", category: .alarmKit)
                for idString in dismissedIdStrings {
                    if let alarmId = UUID(uuidString: idString) {
                        completedAlarmIds.append(alarmId)
                    }
                }
                userDefaults.removeObject(forKey: AlarmIntentKeys.alarmDismissedAlarmIdsKey)
            } else if let alarm = currentScheduledAlarm {
                AppLogger.info("Using current scheduled alarm as fallback: \(alarm.displayTitle)", category: .alarmKit)
                completedAlarmIds.append(alarm.id)
            }

            currentAlarmId = nil
            currentScheduledAlarm = nil

            AppLogger.info("Processed alarm dismissal from intent, count: \(completedAlarmIds.count)", category: .alarmKit)
        }

        if userDefaults.bool(forKey: AlarmIntentKeys.alarmSnoozedKey) {
            userDefaults.set(false, forKey: AlarmIntentKeys.alarmSnoozedKey)
            AppLogger.info("Processed snooze from intent", category: .alarmKit)
        }

        userDefaults.synchronize()
        
        return completedAlarmIds
    }
    
    // MARK: - Alarm ID Mapping
    
    private func saveAlarmIdMapping(alarmKitId: UUID, appAlarmId: UUID) {
        var mapping = UserDefaults.standard.dictionary(forKey: alarmIdMappingKey) as? [String: String] ?? [:]
        mapping[alarmKitId.uuidString] = appAlarmId.uuidString
        UserDefaults.standard.set(mapping, forKey: alarmIdMappingKey)
        UserDefaults.standard.synchronize()
        AppLogger.debug("Saved alarm ID mapping: \(alarmKitId.uuidString.prefix(8)) -> \(appAlarmId.uuidString.prefix(8))", category: .alarmKit)
    }

    // MARK: - Weekday 변환 (앱 Weekday → AlarmKit Weekday)
    
    private func convertToAlarmKitWeekday(_ weekday: Weekday) -> Locale.Weekday {
        return weekday.localeWeekday
    }

    // MARK: - Schedule Alarm (⭐ Fixed/Relative 기반으로 변경)

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

        // 스케줄링 시작 표시
        isScheduling = true

        // 기존 알람 모두 중지
        await stopAllAlarms()

        do {
            let id = UUID()
            currentAlarmId = id
            currentScheduledAlarm = alarm
            
            // AlarmKit ID -> App Alarm ID 매핑 저장
            saveAlarmIdMapping(alarmKitId: id, appAlarmId: alarm.id)

            // AlarmAttributes 생성
            let attributes = createAlarmAttributes(
                title: alarm.displayTitle,
                message: "알람이 울립니다"
            )

            typealias Config = AlarmManager.AlarmConfiguration<BetterAlarmMetadata>
            let config: Config
            
            switch alarm.schedule {
            case .once:
                // ⭐ 1회성 알람: Fixed Schedule 사용
                guard let triggerDate = alarm.nextTriggerDate() else {
                    AppLogger.warning("No trigger date for once alarm", category: .alarmKit)
                    isScheduling = false
                    return
                }
                
                guard triggerDate.timeIntervalSinceNow > 0 else {
                    AppLogger.warning("Trigger date is in the past: \(triggerDate)", category: .alarmKit)
                    isScheduling = false
                    return
                }
                
                let schedule = AKSchedule.fixed(triggerDate)
                config = Config(
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: StopAlarmIntent(alarmID: id.uuidString),
                    secondaryIntent: SnoozeAlarmIntent(alarmID: id.uuidString)
                )
                
                AppLogger.info("Scheduled ONCE alarm with fixed date: \(triggerDate)", category: .alarmKit)
                
            case .weekly(let weekdays):
                // ⭐ 주간 반복 알람: Relative Schedule 사용
                let time = AKSchedule.Relative.Time(hour: alarm.hour, minute: alarm.minute)
                let alarmKitWeekdays = weekdays.map { convertToAlarmKitWeekday($0) }
                let recurrence = AKSchedule.Relative.Recurrence.weekly(alarmKitWeekdays)
                let relativeSchedule = AKSchedule.Relative(time: time, repeats: recurrence)
                let schedule = AKSchedule.relative(relativeSchedule)
                
                config = Config(
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: StopAlarmIntent(alarmID: id.uuidString),
                    secondaryIntent: SnoozeAlarmIntent(alarmID: id.uuidString)
                )
                
                let weekdayNames = weekdays.map { $0.shortName }.joined(separator: ", ")
                AppLogger.info("Scheduled WEEKLY alarm: \(alarm.hour):\(alarm.minute) on \(weekdayNames)", category: .alarmKit)
                
            case .specificDate(let date):
                // ⭐ 특정 날짜 알람: Fixed Schedule 사용
                var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
                components.hour = alarm.hour
                components.minute = alarm.minute
                components.second = 0
                
                guard let triggerDate = Calendar.current.date(from: components) else {
                    AppLogger.warning("Failed to create trigger date from components", category: .alarmKit)
                    isScheduling = false
                    return
                }
                
                guard triggerDate.timeIntervalSinceNow > 0 else {
                    AppLogger.warning("Specific date is in the past: \(triggerDate)", category: .alarmKit)
                    isScheduling = false
                    return
                }
                
                let schedule = AKSchedule.fixed(triggerDate)
                config = Config(
                    schedule: schedule,
                    attributes: attributes,
                    stopIntent: StopAlarmIntent(alarmID: id.uuidString),
                    secondaryIntent: SnoozeAlarmIntent(alarmID: id.uuidString)
                )
                
                AppLogger.info("Scheduled SPECIFIC DATE alarm: \(triggerDate)", category: .alarmKit)
            }

            _ = try await manager.schedule(id: id, configuration: config)

            if let nextDate = alarm.nextTriggerDate() {
                AppLogger.alarmScheduled("\(alarm.displayTitle) id=\(id.uuidString.prefix(8))", triggerDate: nextDate)
            }

        } catch {
            AppLogger.error("Failed to schedule alarm: \(error)", category: .alarmKit)
        }

        // 스케줄링 완료 표시
        isScheduling = false
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

    // MARK: - Snooze (Fixed Schedule 사용)

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
        let snoozeTime = await Date().addingTimeInterval(Self.snoozeInterval)
        AppLogger.debug("Snooze alarm will trigger at: \(snoozeTime)", category: .alarmKit)

        let attributes = await Self.createAlarmAttributesStatic(
            title: "스누즈 알람",
            message: "다시 알람이 울립니다"
        )

        typealias Config = AlarmManager.AlarmConfiguration<BetterAlarmMetadata>
        
        // 스누즈도 fixed schedule 사용
        let schedule = AKSchedule.fixed(snoozeTime)
        let config = Config(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: newId.uuidString),
            secondaryIntent: SnoozeAlarmIntent(alarmID: newId.uuidString)
        )

        _ = try? await manager.schedule(id: newId, configuration: config)

        AppLogger.info("Snooze alarm scheduled with fixed date, id=\(newId.uuidString.prefix(8))", category: .alarmKit)
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
