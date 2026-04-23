import UIKit
import UserNotifications

// MARK: - Notification.Name

extension Notification.Name {
    /// 포그라운드에서 알람이 울려야 할 때 전송되는 알림.
    static let alarmShouldRing = Notification.Name("alarmShouldRing")
    /// 알람 울림 화면이 닫혔을 때 (정지/스누즈 후) 알람 목록 갱신 요청.
    static let alarmCompleted = Notification.Name("alarmCompleted")
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
        Task {
            guard let store = alarmStore,
                  let notificationService = localNotificationService else { return }

            // local 모드 활성화 알람이 있으면 즉시 리마인더 등록
            let hasLocal = await store.hasEnabledLocalAlarms
            guard hasLocal else {
                AppLogger.debug("No enabled local alarms — skipping background reminder", category: .lifecycle)
                return
            }

            // 가장 임박한 local 알람 찾기
            let alarms = await store.alarms
            let nextLocal = alarms
                .filter { $0.isEnabled && $0.alarmMode == .local }
                .compactMap { alarm -> (Alarm, Date)? in
                    guard let date = alarm.nextTriggerDate() else { return nil }
                    return (alarm, date)
                }
                .min { $0.1 < $1.1 }?
                .0

            if let alarm = nextLocal {
                AppLogger.info("Scheduling background reminder for: \(alarm.displayTitle)", category: .lifecycle)
                await notificationService.scheduleBackgroundReminder(for: alarm)
            }

            // 무음 루프 시작 (백그라운드 유지)
            await audioService?.startSilentLoop()
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AppLogger.info("App entering foreground", category: .lifecycle)
        Task {
            // 백그라운드 리마인더 취소
            await localNotificationService?.cancelBackgroundReminder()
            // 무음 루프 정지 (배터리 절약)
            await audioService?.stopSilentLoop()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        AppLogger.info("App will terminate — re-registering alarms", category: .lifecycle)
        // 앱 종료 시 활성화된 모든 local 알람의 UNCalendar 알림을 재등록하여
        // 앱이 꺼진 상태에서도 iOS가 알림을 발송할 수 있도록 보장한다.
        guard let store = alarmStore,
              let notificationService = localNotificationService else { return }

        let group = DispatchGroup()
        group.enter()
        Task {
            defer { group.leave() }
            // 무음 루프 정지
            await audioService?.stopSilentLoop()
            let alarms = await store.alarms
            let localAlarms = alarms.filter { $0.isEnabled && $0.alarmMode == .local }
            // 가장 임박한 알람 찾기 (반복 알림은 이 알람에만 등록)
            let nextAlarmID = localAlarms
                .compactMap { alarm -> (Alarm, Date)? in
                    guard let d = alarm.nextTriggerDate() else { return nil }
                    return (alarm, d)
                }
                .min(by: { $0.1 < $1.1 })?
                .0.id
            AppLogger.info("Re-registering \(localAlarms.count) local alarms on terminate", category: .lifecycle)
            for alarm in localAlarms {
                try? await notificationService.scheduleAlarm(for: alarm, withRepeatingAlerts: alarm.id == nextAlarmID)
            }
        }
        // 최대 2초 대기 후 종료 허용
        _ = group.wait(timeout: .now() + 2)
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
