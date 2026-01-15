import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        AppLogger.info("scene willConnectTo called", category: .lifecycle)

        guard let windowScene = (scene as? UIWindowScene) else {
            AppLogger.error("Failed to get windowScene", category: .lifecycle)
            return
        }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = MainTabBarController()
        window?.makeKeyAndVisible()
        AppLogger.info("Window created and made key", category: .lifecycle)

        // Load alarms and start Live Activity
        AppLogger.info("Loading alarms on launch", category: .store)
        AlarmStore.shared.loadAlarms()
        AlarmStore.shared.rescheduleAllAlarms()
        AlarmStore.shared.startLiveActivity()
        AppLogger.info("Initial setup completed", category: .lifecycle)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        AppLogger.info("sceneDidDisconnect", category: .lifecycle)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppLogger.info("sceneDidBecomeActive", category: .lifecycle)

        // Check if alarm was dismissed from lock screen while app was closed
        handleAlarmDismissedFromLockScreen()

        // Refresh alarms and clean up expired one-time alarms
        AppLogger.debug("Refreshing alarms on become active", category: .store)
        AlarmStore.shared.loadAlarms()
        AlarmStore.shared.cleanupExpiredOneTimeAlarms()

        // Reschedule next alarm (in case previous alarm was dismissed from lock screen)
        AlarmStore.shared.rescheduleAllAlarms()

        // Update Live Activity with next alarm
        AlarmStore.shared.updateLiveActivity()
        AppLogger.debug("Become active handling completed", category: .lifecycle)
    }

    private func handleAlarmDismissedFromLockScreen() {
        let wasDismissed = UserDefaults.standard.bool(forKey: "alarmDismissedFromLockScreen")
        AppLogger.debug("Checking lock screen dismissal: wasDismissed=\(wasDismissed)", category: .alarm)

        if wasDismissed {
            AppLogger.info("Alarm was dismissed from lock screen, cleaning up", category: .alarm)
            // Clear the flag
            UserDefaults.standard.set(false, forKey: "alarmDismissedFromLockScreen")

            // Clean up any one-time alarms that triggered while app was closed
            AlarmStore.shared.cleanupExpiredOneTimeAlarms()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        AppLogger.info("sceneWillResignActive", category: .lifecycle)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        AppLogger.info("sceneWillEnterForeground", category: .lifecycle)
        // Refresh alarms
        AlarmStore.shared.loadAlarms()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AppLogger.info("sceneDidEnterBackground", category: .lifecycle)
    }
}
