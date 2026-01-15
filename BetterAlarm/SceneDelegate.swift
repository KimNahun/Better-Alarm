import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = MainTabBarController()
        window?.makeKeyAndVisible()

        // Load alarms and start Live Activity
        AlarmStore.shared.loadAlarms()
        AlarmStore.shared.rescheduleAllAlarms()
        AlarmStore.shared.startLiveActivity()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Check if alarm was dismissed from lock screen while app was closed
        handleAlarmDismissedFromLockScreen()

        // Refresh alarms and clean up expired one-time alarms
        AlarmStore.shared.loadAlarms()
        AlarmStore.shared.cleanupExpiredOneTimeAlarms()

        // Reschedule next alarm (in case previous alarm was dismissed from lock screen)
        AlarmStore.shared.rescheduleAllAlarms()

        // Update Live Activity with next alarm
        AlarmStore.shared.updateLiveActivity()
    }

    private func handleAlarmDismissedFromLockScreen() {
        let wasDismissed = UserDefaults.standard.bool(forKey: "alarmDismissedFromLockScreen")

        if wasDismissed {
            // Clear the flag
            UserDefaults.standard.set(false, forKey: "alarmDismissedFromLockScreen")

            // Clean up any one-time alarms that triggered while app was closed
            AlarmStore.shared.cleanupExpiredOneTimeAlarms()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Refresh alarms
        AlarmStore.shared.loadAlarms()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
