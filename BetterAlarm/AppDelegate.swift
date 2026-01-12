import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Setup notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permission
        Task {
            _ = await AlarmKitService.shared.requestPermission()
        }

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    // MARK: - Helper

    private func getSceneDelegate() -> SceneDelegate? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate else {
            return nil
        }
        return sceneDelegate
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])

        // If this is an alarm notification, show the alarm ringing screen
        if notification.request.content.categoryIdentifier == "ALARM_CATEGORY" {
            let alarmId = notification.request.identifier

            DispatchQueue.main.async { [weak self] in
                let alarm = AlarmManager.shared.alarms.first { $0.id.uuidString == alarmId }
                self?.getSceneDelegate()?.showAlarmRingingScreen(with: alarm)
            }
        }
    }

    // Handle notification actions
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let alarmId = response.notification.request.identifier

        switch actionIdentifier {
        case "SNOOZE_ACTION":
            // Find the alarm and snooze it
            if let alarm = AlarmManager.shared.alarms.first(where: { $0.id.uuidString == alarmId }) {
                AlarmPlayer.shared.snoozeAlarm(alarm, minutes: 5)
            }

        case "DISMISS_ACTION", UNNotificationDismissActionIdentifier:
            // Stop the alarm
            AlarmPlayer.shared.stopAlarm()

            // Handle one-time alarm cleanup
            if let alarm = AlarmManager.shared.alarms.first(where: { $0.id.uuidString == alarmId }) {
                AlarmManager.shared.handleAlarmCompleted(alarm)
            }

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification itself
            if response.notification.request.content.categoryIdentifier == "ALARM_CATEGORY" {
                // Show alarm ringing screen
                DispatchQueue.main.async { [weak self] in
                    let alarm = AlarmManager.shared.alarms.first { $0.id.uuidString == alarmId }
                    self?.getSceneDelegate()?.showAlarmRingingScreen(with: alarm)
                }
            }

        default:
            break
        }

        completionHandler()
    }
}
