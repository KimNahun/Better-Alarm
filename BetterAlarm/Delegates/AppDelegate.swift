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
    // AlarmStore와 LocalNotificationService를 BetterAlarmApp에서 주입받는다.
    private(set) var alarmStore: AlarmStore?
    private(set) var localNotificationService: LocalNotificationService?

    /// BetterAlarmApp에서 의존성을 주입한다.
    func configure(alarmStore: AlarmStore, localNotificationService: LocalNotificationService) {
        self.alarmStore = alarmStore
        self.localNotificationService = localNotificationService
    }

    // MARK: - Launch

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: - Background / Foreground

    func applicationDidEnterBackground(_ application: UIApplication) {
        Task {
            guard let store = alarmStore,
                  let notificationService = localNotificationService else { return }

            // local 모드 활성화 알람이 있으면 즉시 리마인더 등록
            let hasLocal = await store.hasEnabledLocalAlarms
            guard hasLocal else { return }

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
                await notificationService.scheduleBackgroundReminder(for: alarm)
            }
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Task {
            // 백그라운드 리마인더 취소
            await localNotificationService?.cancelBackgroundReminder()
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // 앱 종료 시 활성화된 모든 local 알람의 UNCalendar 알림을 재등록하여
        // 앱이 꺼진 상태에서도 iOS가 알림을 발송할 수 있도록 보장한다.
        guard let store = alarmStore,
              let notificationService = localNotificationService else { return }

        let group = DispatchGroup()
        group.enter()
        Task {
            defer { group.leave() }
            let alarms = await store.alarms
            for alarm in alarms where alarm.isEnabled && alarm.alarmMode == .local {
                try? await notificationService.scheduleAlarm(for: alarm)
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
                    NotificationCenter.default.post(
                        name: .alarmShouldRing,
                        object: nil,
                        userInfo: ["alarmID": alarmIDString]
                    )
                    return []
                }
            }
        }
        return [.banner, .sound, .badge]
    }

    /// 사용자가 알림을 탭했을 때 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        if let alarmIDString = userInfo["alarmID"] as? String,
           let alarmID = UUID(uuidString: alarmIDString) {
            guard let store = alarmStore else { return }
            let alarms = await store.alarms
            if alarms.first(where: { $0.id == alarmID }) != nil {
                // 알람 울리는 화면으로 딥링크
                NotificationCenter.default.post(
                    name: .alarmShouldRing,
                    object: nil,
                    userInfo: ["alarmID": alarmIDString]
                )
            }
        }
    }
}
