import Foundation
import AlarmKit
import AppIntents

// MARK: - AlarmMetadata (필수)

nonisolated struct BetterAlarmMetadata: AlarmMetadata {}

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
        if let id = UUID(uuidString: alarmID) {
            try? AlarmManager.shared.stop(id: id)
        }

        // Mark that alarm was dismissed from lock screen (for cleanup when app opens)
        UserDefaults.standard.set(true, forKey: "alarmDismissedFromLockScreen")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "alarmDismissedTime")

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
        // 스누즈 로직 - 5분 후 다시 알람
        await AlarmKitService.shared.snoozeFromIntent(alarmID: alarmID)
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
    
    // 알람 모니터링 Task
    private var monitorTask: Task<Void, Never>?
    
    // 알람이 울릴 때 콜백
    private var onAlerting: ((UUID) -> Void)?
    
    // 스누즈 시간 (5분)
    static let snoozeInterval: TimeInterval = 5 * 60
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let status = try await manager.requestAuthorization()
            return status == .authorized
        } catch {
            print("[AlarmKit] Failed to request permission: \(error)")
            return false
        }
    }

    func checkAuthorizationStatus() async -> Bool {
        do {
            let status = manager.authorizationState
            return status == .authorized
        }
    }
    
    // MARK: - Monitoring
    
    /// 알람이 울릴 때 호출될 핸들러 등록
    func observeAlertingAlarms(_ handler: @escaping (UUID) -> Void) {
        self.onAlerting = handler
    }
    
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }
    
    func resumeMonitoring() {
        if monitorTask == nil {
            startMonitoring()
        }
    }
    
    private func startMonitoring() {
        monitorTask?.cancel()
        
        monitorTask = Task {
            for await alarms in manager.alarmUpdates {
                if Task.isCancelled { break }
                
                // 알람이 없으면 currentAlarmId 초기화
                if alarms.isEmpty {
                    self.currentAlarmId = nil
                }
                
                // 울리는 중인 알람 처리
                for alarm in alarms where alarm.state == .alerting {
                    self.onAlerting?(alarm.id)
                }
            }
        }
    }
    
    // MARK: - Schedule Alarm
    
    /// 앱의 Alarm 모델을 받아서 AlarmKit 타이머로 스케줄
    func scheduleAlarm(for alarm: Alarm) async {
        guard alarm.isEnabled else { return }
        
        // 권한 확인
        guard await requestPermission() else {
            print("[AlarmKit] Not authorized")
            return
        }
        
        // 기존 알람 모두 중지
        await stopAllAlarms()
        
        do {
            let id = UUID()
            currentAlarmId = id
            
            // 다음 알람까지의 시간 계산
            guard let triggerDate = alarm.nextTriggerDate() else { return }
            let duration = triggerDate.timeIntervalSinceNow
            
            // duration이 0보다 작으면 스케줄 불가
            guard duration > 0 else {
                print("[AlarmKit] Trigger date is in the past")
                return
            }
            
            // AlarmAttributes 생성
            let attributes = createAlarmAttributes(
                title: alarm.displayTitle,
                message: "알람이 울립니다"
            )
            
            // Configuration 생성 (타이머 형식)
            typealias Config = AlarmManager.AlarmConfiguration<BetterAlarmMetadata>
            let config = Config.timer(
                duration: duration,
                attributes: attributes,
                stopIntent: StopAlarmIntent(alarmID: id.uuidString),
                secondaryIntent: SnoozeAlarmIntent(alarmID: id.uuidString)
            )
            
            // 알람 스케줄
            _ = try await manager.schedule(id: id, configuration: config)
            
            print("[AlarmKit] Scheduled alarm: \(alarm.displayTitle) in \(duration) seconds")
            
        } catch {
            print("[AlarmKit] Failed to schedule alarm: \(error)")
        }
    }
    
    // MARK: - Cancel/Stop
    
    func cancelAlarm(for alarm: Alarm) {
        guard let alarmId = currentAlarmId else { return }
        
        do {
            try manager.stop(id: alarmId)
            currentAlarmId = nil
            print("[AlarmKit] Cancelled alarm")
        } catch {
            print("[AlarmKit] Failed to cancel alarm: \(error)")
        }
    }
    
    func stopAllAlarms() async {
        do {
            let existingAlarms = try manager.alarms
            for alarm in existingAlarms {
                try manager.stop(id: alarm.id)
            }
            currentAlarmId = nil
        } catch {
            print("[AlarmKit] Failed to stop alarms: \(error)")
        }
    }
    
    // MARK: - Snooze
    
    /// Intent에서 호출되는 스누즈 함수
    nonisolated func snoozeFromIntent(alarmID: String) async {
        let manager = AlarmManager.shared
        
        // 현재 알람 중지
        if let id = UUID(uuidString: alarmID) {
            try? manager.stop(id: id)
        }
        
        // 새 알람 예약 (5분 후)
        let newId = UUID()
        
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
    }
    
    // MARK: - Helper
    
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
}
