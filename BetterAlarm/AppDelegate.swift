import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppLogger.info("Application didFinishLaunchingWithOptions", category: .lifecycle)

        // Request AlarmKit permission
        Task {
            AppLogger.info("Requesting AlarmKit permission", category: .permission)
            let granted = await AlarmKitService.shared.requestPermission()
            AppLogger.info("AlarmKit permission result: \(granted)", category: .permission)
        }

        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        AppLogger.debug("Configuring scene session", category: .lifecycle)
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        AppLogger.debug("Did discard scene sessions: \(sceneSessions.count)", category: .lifecycle)
    }

    // MARK: - Orientation Lock
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
