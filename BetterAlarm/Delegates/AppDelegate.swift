import UIKit
import UserNotifications

// MARK: - Notification.Name

extension Notification.Name {
    /// 포그라운드에서 알람이 울려야 할 때 전송되는 알림.
    static let alarmShouldRing = Notification.Name("alarmShouldRing")
    /// 알람 울림 화면이 닫혔을 때 (정지/스누즈 후) 알람 목록 갱신 요청.
    static let alarmCompleted = Notification.Name("alarmCompleted")
}

// MARK: - BackgroundTaskManager

/// 앱이 백그라운드로 전환되거나 종료될 때 모든 활성 알람을 OS에 재등록하는 싱글톤.
/// PitcrewAssignment 프로젝트의 검증된 패턴을 이식 — UIBackgroundTask로 작업 시간을 확보하여
/// iOS가 앱 프로세스를 종료하기 직전에 UNNotification 등록이 완료되도록 보장한다.
@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    /// 중복 예약 방지 플래그. 포그라운드 복귀 시 reset()으로 초기화.
    private var isScheduled = false

    private init() {}

    func reset() {
        isScheduled = false
    }

    /// 모든 활성 local 알람을 재등록하고 사용자에게 안내 알림을 발송한다.
    /// - Parameter isTerminating: true이면 swipe-up 종료 → "앱이 종료되면 알람이 울리지 않을 수 있습니다"
    ///   경고를 발송한다 (활성 local 알람이 1개 이상일 때만). false면 정상 백그라운드 진입 안내 발송.
    /// - Note: `beginBackgroundTask`로 작업 시간을 확보 → 앱이 swipe-up kill 되거나 백그라운드에서 OS에 의해
    ///   종료되어도 등록된 UNNotification은 시스템이 그대로 발송한다.
    func scheduleExitAlarms(
        store: AlarmStore?,
        notificationService: LocalNotificationService?,
        audioService: AudioService?,
        isTerminating: Bool = false
    ) {
        if isScheduled { return }
        guard let store = store, let notificationService = notificationService else { return }

        isScheduled = true

        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        Task {
            defer {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }

            await audioService?.stopSilentLoop()

            let alarms = await store.alarms
            let localAlarms = alarms.filter { $0.isEnabled && $0.alarmMode == .local }
            let nextLocalAlarmID = localAlarms
                .compactMap { alarm -> (Alarm, Date)? in
                    guard let d = alarm.nextTriggerDate() else { return nil }
                    return (alarm, d)
                }
                .min(by: { $0.1 < $1.1 })?
                .0.id

            AppLogger.info("BackgroundTaskManager re-registering \(localAlarms.count) local alarms (terminating=\(isTerminating))", category: .lifecycle)
            for alarm in localAlarms {
                try? await notificationService.scheduleAlarm(for: alarm, withRepeatingAlerts: alarm.id == nextLocalAlarmID)
            }

            // 알림 발송 분기:
            // - 종료 시(isTerminating=true) + 활성 local 알람 1개 이상 → 경고 메시지
            //   AlarmKit은 OS 시스템 레벨에서 동작하므로 alarmKit 모드 알람만 있으면 경고 불필요.
            // - 백그라운드 진입(isTerminating=false) → 정상 안내 메시지
            if isTerminating {
                if let nextLocalAlarmID,
                   let nextAlarm = localAlarms.first(where: { $0.id == nextLocalAlarmID }) {
                    await notificationService.scheduleTerminationWarning(for: nextAlarm)
                }
            } else {
                // 백그라운드 진입 시엔 다음 알람이 local이든 alarmKit이든 안내한다 (사용자 확인용)
                let allAlarms = alarms.filter { $0.isEnabled && !$0.isSkippingNext }
                let nextOverall = allAlarms
                    .compactMap { alarm -> (Alarm, Date)? in
                        guard let d = alarm.effectiveNextTriggerDate() else { return nil }
                        return (alarm, d)
                    }
                    .min(by: { $0.1 < $1.1 })?
                    .0
                if let nextAlarm = nextOverall {
                    await notificationService.scheduleBackgroundReminder(for: nextAlarm)
                }
            }
        }
    }
}

// MARK: - AppDelegate

/// 앱 생명주기 이벤트를 처리하는 AppDelegate.
/// - 백그라운드 진입 시: local 모드 활성화 알람이 있으면 즉시 로컬 알림 1건 등록
/// - 포그라운드 복귀 시: 백그라운드 리마인더 알림 취소
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    // AlarmStore, LocalNotificationService, AudioService를 BetterAlarmApp에서 주입받는다.
    private(set) var alarmStore: AlarmStore?
    private(set) var localNotificationService: LocalNotificationService?
    private(set) var audioService: AudioService?

    /// Cold launch 시 notification tap으로 들어온 알람 ID를 임시 저장.
    /// SwiftUI .task 리스너가 아직 attach 안 됐을 때 유실 방지.
    private var pendingAlarmID: UUID?

    /// 저장된 pending 알람 ID를 소비(반환 후 nil 처리)한다.
    func consumePendingAlarmID() -> UUID? {
        let id = pendingAlarmID
        pendingAlarmID = nil
        return id
    }

    /// BetterAlarmApp에서 의존성을 주입한다.
    func configure(alarmStore: AlarmStore, localNotificationService: LocalNotificationService, audioService: AudioService) {
        self.alarmStore = alarmStore
        self.localNotificationService = localNotificationService
        self.audioService = audioService
    }

    // MARK: - Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AppLogger.info("didFinishLaunching", category: .lifecycle)
        return true
    }

    // MARK: - Background / Foreground

    func applicationDidEnterBackground(_ application: UIApplication) {
        AppLogger.info("App entered background", category: .lifecycle)
        // 무음 루프 시작 (백그라운드 유지)
        Task { await audioService?.startSilentLoop() }
        // PitcrewAssignment 패턴: BackgroundTaskManager로 모든 알람 재등록 + 리마인더 발송
        BackgroundTaskManager.shared.scheduleExitAlarms(
            store: alarmStore,
            notificationService: localNotificationService,
            audioService: audioService
        )
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AppLogger.info("App entering foreground", category: .lifecycle)
        // BackgroundTaskManager 중복 예약 플래그 초기화
        BackgroundTaskManager.shared.reset()
        Task {
            // 백그라운드 리마인더 취소
            await localNotificationService?.cancelBackgroundReminder()
            // 무음 루프 정지 (배터리 절약)
            await audioService?.stopSilentLoop()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AppLogger.info("App will terminate — re-registering alarms", category: .lifecycle)
        // PitcrewAssignment 패턴: BackgroundTaskManager가 UIBackgroundTask로 작업 시간을 확보.
        // isTerminating=true → 활성 local 알람이 1개 이상이면 "앱 종료 시 알람 안 울릴 수 있음" 경고 발송.
        BackgroundTaskManager.shared.scheduleExitAlarms(
            store: alarmStore,
            notificationService: localNotificationService,
            audioService: audioService,
            isTerminating: true
        )
        // RunLoop을 2초 spin하여 위 Task가 UNNotification 등록을 마치도록 보장.
        // DispatchGroup.wait는 MainActor 컨텍스트에서 데드락 위험이 있어 RunLoop 패턴을 사용한다.
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// 앱이 포그라운드 상태에서 알림이 도착하면 울림 화면을 표시한다.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        if let alarmIDString = userInfo["alarmID"] as? String,
           let alarmID = UUID(uuidString: alarmIDString) {
            if let store = alarmStore {
                let alarms = await store.alarms
                if let alarm = alarms.first(where: { $0.id == alarmID }) {
                    AppLogger.info("Foreground notification → ringing screen: \(alarm.displayTitle)", category: .alarm)

                    // 즉시 오디오 재생 (UI 렌더링 대기 없이 소리부터)
                    if let audioService {
                        await audioService.stopSilentLoop()
                        let isPlaying = await audioService.isAlarmPlaying
                        if !isPlaying {
                            try? await audioService.playAlarmSound(
                                soundName: alarm.soundName,
                                isSilent: alarm.isSilentAlarm,
                                loop: true
                            )
                        }
                    }

                    NotificationCenter.default.post(
                        name: .alarmShouldRing,
                        object: nil,
                        userInfo: ["alarmID": alarmIDString]
                    )
                    return []
                }
            }
        }
        AppLogger.debug("Foreground notification presented as banner (non-alarm or unknown)", category: .alarm)
        return [.banner, .sound, .badge]
    }

    /// 사용자가 알림을 탭하거나 알림 액션(정지/스누즈)을 수행했을 때 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        guard let alarmIDString = userInfo["alarmID"] as? String,
              let alarmID = UUID(uuidString: alarmIDString) else { return }

        // cold launch: store 주입 전이면 pending에 저장 (기본 탭 액션만)
        guard let store = alarmStore else {
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                pendingAlarmID = alarmID
                AppLogger.info("Store not ready — saved pending alarm: \(alarmIDString)", category: .navigation)
            }
            return
        }

        let alarms = await store.alarms
        guard let alarm = alarms.first(where: { $0.id == alarmID }) else {
            AppLogger.warning("Tapped notification but alarm not found: \(alarmIDString)", category: .navigation)
            return
        }

        switch response.actionIdentifier {
        case "STOP_ACTION", UNNotificationDismissActionIdentifier:
            // 알림에서 "정지" 또는 스와이프 dismiss → 알람 완료 처리
            AppLogger.info("Alarm stopped via notification action: \(alarmIDString)", category: .alarm)
            await audioService?.stopAlarmSound()
            await store.handleAlarmCompleted(alarm)
            await localNotificationService?.cancelAlarm(for: alarm)

        case "SNOOZE_ACTION":
            // 알림에서 "스누즈" → 5분 후 재알림
            AppLogger.info("Alarm snoozed via notification action: \(alarmIDString)", category: .alarm)
            await audioService?.stopAlarmSound()
            await store.snoozeAlarm(alarm, minutes: 5)
            await localNotificationService?.cancelAlarm(for: alarm)

        default:
            // 알림 탭 → 앱 열고 울림 화면 표시
            AppLogger.info("User tapped notification → deeplink to ringing screen: \(alarmIDString)", category: .navigation)

            // 즉시 오디오 재생 시작 (UI 렌더링 전에 소리부터 나도록)
            if let audioService {
                await audioService.stopSilentLoop()
                let isPlaying = await audioService.isAlarmPlaying
                if !isPlaying {
                    try? await audioService.playAlarmSound(
                        soundName: alarm.soundName,
                        isSilent: alarm.isSilentAlarm,
                        loop: true
                    )
                }
            }

            pendingAlarmID = alarmID
            NotificationCenter.default.post(
                name: .alarmShouldRing,
                object: nil,
                userInfo: ["alarmID": alarmIDString]
            )
        }
    }
}
